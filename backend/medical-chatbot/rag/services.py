import json
import re
import time
import os
import requests
import logging
from core.state import embedding_manager

logger = logging.getLogger(__name__)

def _build_medications_summary(medications: list) -> str:
    """بناء ملخص للأدوية"""
    if not medications:
        return "• لا توجد أدوية مسجلة"
    
    summary = "**الأدوية المستخدمة:**\n"
    taken_count = 0
    
    for med in medications:
        status = "✅ تم تناولها" if med.get('isTaken', False) else "❌ لم تؤخذ بعد"
        taken_count += 1 if med.get('isTaken', False) else 0
        summary += f"• {med.get('name', 'غير معروف')} - {med.get('time', 'غير محدد')} - {status}\n"
    
    compliance_rate = (taken_count / len(medications)) * 100 if medications else 0
    summary += f"\n**معدل الالتزام:** {compliance_rate:.1f}% ({taken_count}/{len(medications)})"
    
    return summary

def _build_questionnaire_summary(answers: dict) -> str:
    """بناء ملخص لإجابات الاستبيان"""
    if not answers:
        return "• لا توجد إجابات للاستبيان"
    
    summary = "**إجابات الاستبيان:**\n"
    
    key_names = {
        'adherence': 'الالتزام بالأدوية',
        'missed_meds': 'الأدوية المفقودة',
        'reason': 'سبب عدم الالتزام',
        'side_effects': 'الأعراض الجانبية',
        'symptom_severity': 'شدة الأعراض',
        'general_feeling': 'الحالة العامة',
        'notes': 'ملاحظات إضافية'
    }
    
    for key, value in answers.items():
        display_name = key_names.get(key, key)
        summary += f"• {display_name}: {value}\n"
    
    return summary

def _get_medical_context(medications: list, answers: dict) -> str:
    """الحصول على السياق الطبي ذو الصلة"""
    context_parts = []
    
    for med in medications:
        med_name = med.get('name', '')
        if med_name:
            relevant_docs = embedding_manager.search(med_name, k=2)
            for doc in relevant_docs[:1]:
                if doc['score'] < 1.8:
                    context_parts.append(f"معلومات عن {med_name}: {doc['text'][:300]}...")
    
    side_effects = answers.get('side_effects', '')
    if side_effects and 'لا توجد أعراض' not in side_effects:
        relevant_docs = embedding_manager.search(side_effects, k=2)
        for doc in relevant_docs[:1]:
            if doc['score'] < 1.8:
                context_parts.append(f"معلومات عن {side_effects}: {doc['text'][:300]}...")
    
    general_feeling = answers.get('general_feeling', '')
    if general_feeling and 'جيد' not in general_feeling:
        relevant_docs = embedding_manager.search("تحسين الصحة العامة", k=1)
        for doc in relevant_docs:
            if doc['score'] < 2.0:
                context_parts.append(f"نصائح للصحة العامة: {doc['text'][:300]}...")
    
    return "\n\n".join(context_parts) if context_parts else "لا توجد معلومات طبية إضافية متاحة"

def _parse_ai_response(ai_response: str) -> tuple:
    analysis = ""
    recommendations = ""
    health_score = 70
    warning_level = "medium"
    
    try:
        response_text = ai_response.strip()
        
        if "**التحليل:**" in response_text:
            parts = response_text.split("**التحليل:**")
            if len(parts) > 1:
                analysis_part = parts[1].split("**التوصيات:**")[0] if "**التوصيات:**" in parts[1] else parts[1].split("**الدرجة")[0]
                analysis = analysis_part.strip()
        elif "التحليل:" in response_text:
            parts = response_text.split("التحليل:")
            if len(parts) > 1:
                analysis_part = parts[1].split("التوصيات:")[0] if "التوصيات:" in parts[1] else parts[1].split("الدرجة")[0]
                analysis = analysis_part.strip()
        
        if not analysis:
            parts = response_text.split("التوصيات")
            analysis = parts[0].strip()
        
        if "**التوصيات:**" in response_text:
            parts = response_text.split("**التوصيات:**")
            if len(parts) > 1:
                rec_part = parts[1].split("**الدرجة")[0]
                recommendations = rec_part.strip()
        elif "التوصيات:" in response_text:
            parts = response_text.split("التوصيات:")
            if len(parts) > 1:
                rec_part = parts[1].split("الدرجة")[0]
                recommendations = rec_part.strip()
        
        if not recommendations:
            recommendations = "التزم بالأدوية في مواعيدها، وتابع مع طبيبك المعالج بانتظام."
        
        score_pattern1 = r'(?:الدرجة الصحية|الدرجة)[:\s]+(\d{1,3})'
        match = re.search(score_pattern1, response_text)
        if match:
            score = int(match.group(1))
            if 0 <= score <= 100:
                health_score = score
        
        if health_score == 70:
            score_pattern2 = r'(\d{1,3})\s*%'
            matches = re.findall(score_pattern2, response_text)
            for match in matches:
                score = int(match)
                if 0 <= score <= 100:
                    health_score = score
                    break
        
        if health_score == 70:
            lines = response_text.split('\n')
            for line in lines:
                if any(word in line for word in ['درجة', 'score', 'نقاط']):
                    numbers = re.findall(r'\b(\d{1,3})\b', line)
                    for num in numbers:
                        score = int(num)
                        if 0 <= score <= 100:
                            health_score = score
                            break
                    if health_score != 70:
                        break
        
        response_lower = response_text.lower()
        if "**مستوى الإنذار:**" in response_text or "مستوى الإنذار:" in response_text:
            warning_part = response_text.split("مستوى الإنذار:")[-1].strip().lower()
            if "عالي" in warning_part or "high" in warning_part:
                warning_level = "high"
            elif "منخفض" in warning_part or "low" in warning_part:
                warning_level = "low"
            elif "متوسط" in warning_part or "medium" in warning_part:
                warning_level = "medium"
        else:
            if any(word in response_lower for word in ['خطير', 'طوارئ', 'فوري', 'emergency', 'عاجل', 'شديد جداً']):
                warning_level = "high"
            elif any(word in response_lower for word in ['ممتاز', 'excellent', 'جيد جداً', 'مستقر', 'طبيعي']):
                warning_level = "low"
            elif any(word in response_lower for word in ['متوسط', 'medium', 'مراقبة', 'انتباه']):
                warning_level = "medium"
        
        if warning_level == "medium":
            if health_score >= 80:
                warning_level = "low"
            elif health_score >= 60:
                warning_level = "medium"
            else:
                warning_level = "high"
                
    except Exception as e:
        logger.error(f"⚠️ خطأ في تحليل استجابة الذكاء الاصطناعي: {e}")
        if not analysis:
            analysis = ai_response
        if not recommendations:
            recommendations = "يرجى مراجعة التحليل أعلاه واستشارة الطبيب للحصول على التوصيات المناسبة."
    
    if not analysis or len(analysis) < 10:
        analysis = ai_response
    
    if not recommendations or len(recommendations) < 10:
        recommendations = "التزم بالأدوية في مواعيدها، واستشر طبيبك عند ظهور أي أعراض جديدة."
    
    return analysis, recommendations, health_score, warning_level

def _build_treatment_analysis_prompt(answers: dict):
    questions_text = ""
    for key, answer in answers.items():
        question_text = ""
        if key == 'adherence':
            question_text = "هل تناولت جميع أدويتك اليوم حسب الجدول؟"
        elif key == 'reason':
            question_text = "هل كان سبب عدم تناول الدواء هو النسيان؟"
        elif key == 'side_effects':
            question_text = "هل واجهت أي أعراض جانبية اليوم؟"
        elif key == 'symptom_severity':
            question_text = "هل كانت الأعراض شديدة وتؤثر على نشاطك اليومي؟"
        elif key == 'general_feeling':
            question_text = "هل تشعر بتحسن عام في صحتك اليوم؟"
        else:
            question_text = key
        
        questions_text += f"• {question_text}: {answer}\n"
    
    return [
        {
            "role": "system",
            "content": "أنت مساعد طبي ذكي متخصص في تحليل تقارير المرضى اليومية.\n\n🎯 **المهمة**: تحليل إجابات المريض عن حالته العلاجية اليومية وإعطاء:\n1. تحليل مفصل للحالة\n2. نصائح مخصصة\n3. رسالة ترحيب ملهمة\n\n📝 **أسلوب التحليل**:\n1. حلل كل إجابة بشكل منفصل\n2. اربط الإجابات معاً للحصول على صورة شاملة\n3. قدم تحليلاً واقعياً وبنّاءً\n4. كن داعماً ومشجعاً\n5. ركز على التقدم والتحسين\n\n⚠️ **تحذيرات هامة**:\n- أنت نظام ذكي وليس بديلاً عن الطبيب\n- لا تقدم تشخيصات طبية\n- ركز على التوعية والنصائح العامة\n- كن حذراً عند الحديث عن الأدوية"
        },
        {
            "role": "user",
            "content": f"**إجابات المريض عن حالته العلاجية اليومية:**\n\n{questions_text}\n\n**الطلب:**\nقم بتحليل هذه الإجابات وأعطني:\n1. تحليل مفصل للحالة (ما يقارب 300 كلمة)\n2. نصائح مخصصة بناءً على الإجابات\n3. رسالة ترحيب ملهمة تبدأ بـ \"مرحباً! أنا مساعدك الصحي...\"\n\n**تأكد من:**\n- اللغة: العربية الفصحى الواضحة\n- الأسلوب: داعم، بنّاء، مشجع\n- التركيز: على التحسين والتقدم\n- عدم تقديم تشخيصات طبية"
        }
    ]

def _build_prevention_analysis_prompt(answers: dict):
    questions_text = ""
    for key, answer in answers.items():
        question_text = ""
        if key == 'sleep':
            question_text = "ما هو نمط نومك؟"
        elif key == 'exercise':
            question_text = "كم مرة تمارس الرياضة أسبوعياً؟"
        elif key == 'diet':
            question_text = "كيف تصف نظامك الغذائي؟"
        elif key == 'habits':
            question_text = "هل تدخن أو تتناول الكحول؟"
        elif key == 'family_history':
            question_text = "هل لديك تاريخ عائلي لأمراض مزمنة؟"
        else:
            question_text = key
        
        questions_text += f"• {question_text}: {answer}\n"
    
    return [
        {
            "role": "system",
            "content": "أنت خبير صحي متخصص في الوقاية والعناية الصحية.\n\n🎯 **المهمة**: تحليل العادات الصحية للمستخدم وإعطاء:\n1. تقييم للصحة العامة\n2. نصائح وقائية مخصصة\n3. رسالة ترحيب ملهمة\n\n🏆 **مبادئ التقييم**:\n- تقييم شامل للعادات الصحية\n- تقدير نقاط القوة والضعف\n- اقتراح تحسينات عملية\n- التركيز على الوقاية\n\n🌿 **مجالات التقييم**:\n1. النوم وجودته\n2. النشاط البدني\n3. النظام الغذائي\n4. العادات الصحية\n5. التاريخ العائلي\n\n⚠️ **تحذيرات هامة**:\n- أنت نظام توجيهي وليس تشخيصي\n- المعلومات لأغراض التوعية فقط\n- شجع على الفحوصات الدورية"
        },
        {
            "role": "user",
            "content": f"**عادات المستخدم الصحية:**\n\n{questions_text}\n\n**الطلب:**\nقم بتحليل هذه العادات الصحية وأعطني:\n1. تقييم شامل للصحة العامة (ما يقارب 300 كلمة)\n2. نصائح وقائية مخصصة بناءً على الإجابات\n3. رسالة ترحيب ملهمة تبدأ بـ \"مرحباً! أنا مساعدك الصحي...\"\n\n**تأكد من:**\n- اللغة: العربية الفصحى الواضحة\n- الأسلوب: إيجابي، مشجع، بنّاء\n- التركيز: على الوقاية والحياة الصحية\n- ربط العادات بالصحة العامة"
        }
    ]

def _generate_welcome_message(user_type: str, answers: dict = None):
    if user_type == "treatment":
        base_message = "مرحباً! أنا مساعدك الصحي. كيف يمكنني مساعدتك في متابعة علاجك اليوم؟ 💊"
    else:
        base_message = "مرحباً! أنا مساعدك الصحي. كيف يمكنني مساعدتك في الحفاظ على صحتك؟ 🌿"
    
    if answers:
        try:
            api_start = time.time()
            response = requests.post(
                "https://openrouter.ai/api/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {os.getenv('OPENROUTER_API_KEY')}",
                    "HTTP-Referer": "http://localhost:8000",
                    "X-Title": "AFYA CARE - Welcome Message",
                },
                json={
                    "model": "openai/gpt-oss-120b:free",
                    "messages": [
                        {
                            "role": "system",
                            "content": "أنت مساعد صحي ودود. اكتب رسالة ترحيب قصيرة ومشجعة للمريض بناءً على إجاباته."
                        },
                        {
                            "role": "user",
                            "content": f"اكتب رسالة ترحيب قصيرة (سطر أو سطرين) لمستخدم {'تحت العلاج' if user_type == 'treatment' else 'يهتم بالوقاية'}.\n\nرسالة البداية: {base_message}\nالمستخدم: {'تحت العلاج' if user_type == 'treatment' else 'مهتم بالصحة'}\n\nتأكد أن الرسالة:\n1. ودودة ومشجعة\n2. قصيرة (سطر أو سطرين)\n3. تحتوي على أيقونة مناسبة\n4. مكتوبة بالعربية"
                        }
                    ],
                    "temperature": 0.7,
                    "max_tokens": 100,
                    "top_p": 0.9,
                },
                timeout=15
            )
            
            if response.status_code == 200:
                response_data = response.json()
                if response_data.get("choices") and response_data["choices"]:
                    return response_data["choices"][0]["message"]["content"]
        except Exception as e:
            logger.warning(f"⚠️ لم يتم تخصيص رسالة الترحيب: {e}")
    
    return base_message

def _generate_personalized_advice(user_type: str, answers: dict):
    try:
        advice_type = "علاجية" if user_type == "treatment" else "وقائية"
        
        response = requests.post(
            "https://openrouter.ai/api/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {os.getenv('OPENROUTER_API_KEY')}",
                "HTTP-Referer": "http://localhost:8000",
                "X-Title": "AFYA CARE - Personalized Advice",
            },
            json={
                "model": "openai/gpt-oss-120b:free",
                "messages": [
                    {
                        "role": "system",
                        "content": f"أنت خبير صحي متخصص في تقديم نصائح {advice_type} مخصصة.\n\n🎯 **المهمة**: إنشاء قائمة نصائح مخصصة بناءً على إجابات المستخدم.\n\n📝 **تنسيق النصائح**:\n- ابدأ بعنوان \"نصائح {advice_type} مخصصة:\"\n- اكتب 3-5 نقاط رئيسية\n- كل نقطة تبدأ برمز من الرموز التالية: • 🔹 ⭐ 💡 ✅\n- ركز على النقاط العملية والقابلة للتطبيق\n- كن مباشراً وواضحاً\n\n⚠️ **تحذيرات**:\n- لا تقدم نصائح طبية محددة\n- لا توصي بأدوية معينة\n- ركز على العادات والتوجيهات العامة"
                    },
                    {
                        "role": "user",
                        "content": f"أنشئ قائمة نصائح {advice_type} مخصصة.\n\nنوع المستخدم: {'مريض تحت العلاج' if user_type == 'treatment' else 'شخص يهتم بالوقاية'}\n\nإجابات المستخدم:\n{json.dumps(answers, ensure_ascii=False, indent=2)}\n\nالمتطلبات:\n- اكتب باللغة العربية\n- 3-5 نقاط رئيسية فقط\n- كل نقطة في سطر منفصل\n- ركز على الإجراءات العملية\n- استخدم رموز مناسبة"
                    }
                ],
                "temperature": 0.4,
                "max_tokens": 300,
                "top_p": 0.9,
            },
            timeout=30
        )
        
        if response.status_code == 200:
            response_data = response.json()
            if response_data.get("choices") and response_data["choices"]:
                return response_data["choices"][0]["message"]["content"]
                    
    except Exception as e:
        logger.warning(f"⚠️ لم يتم إنشاء نصائح مخصصة: {e}")
    
    if user_type == "treatment":
        return "نصائح علاجية مخصصة:\n• 💊 التزم بمواعيد أدويتك بدقة\n• 📝 سجل أي أعراض جانبية تواجهها\n• 🩺 حافظ على مواعيد المتابعة مع طبيبك\n• 💧 اشرب 8 أكواب ماء يومياً\n• 😴 احصل على قسط كافٍ من النوم والراحة"
    else:
        return "نصائح وقائية مخصصة:\n• 🏃 مارس الرياضة 30 دقيقة يومياً\n• 🍎 تناول 5 حصص من الخضار والفواكه\n• 💧 اشرب 8 أكواب ماء يومياً\n• 😴 نم 7-8 ساعات ليلاً\n• 🩺 أجري فحوصات دورية سنوياً"
