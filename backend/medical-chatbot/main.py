from fastapi import FastAPI, HTTPException, BackgroundTasks
from pydantic import BaseModel
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import requests
import os
import time
from dotenv import load_dotenv
from embeddings import EmbeddingManager
from pdf_processor import PDFProcessor
import asyncio
import logging
import json
from datetime import datetime
import re
from typing import List, Dict

# إعداد التسجيل
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

load_dotenv()

app = FastAPI(
    title="AFYA CARE - Medical RAG Chatbot",
    description="مساعد طبي ذكي يعتمد على الموسوعة الطبية باستخدام تقنية RAG",
    version="2.0.0"
)

# إعداد CORS للسماح بطلبات من أي مصدر
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

embedding_manager = EmbeddingManager()

class ChatRequest(BaseModel):
    question: str
    user_type: str = "general"  # treatment, prevention, general
    questionnaire_data: dict = None

class ChatResponse(BaseModel):
    answer: str
    sources: list
    processing_time: float
    user_type: str

class QuestionnaireRequest(BaseModel):
    user_type: str
    answers: dict

class DailyReportRequest(BaseModel):
    user_type: str = "treatment"
    medications: list
    questionnaire_answers: dict
    user_name: str = "المستخدم"

class DailyReportResponse(BaseModel):
    analysis: str
    recommendations: str
    health_score: int
    warning_level: str  # low, medium, high
    processing_time: float

class SourceItem(BaseModel):
    text: str
    relevance_score: float
    confidence: float
    page_number: int = None

class MedicationScheduleRequest(BaseModel):
    medications: List[str]
    sleep_time: str
    wake_up_time: str
    user_preferences: Dict[str, str] = None

class MedicationScheduleResponse(BaseModel):
    suggested_schedule: str
    explanation: str
    processing_time: float


# متغير عام لتخزين حالة التهيئة
initialization_status = {
    "is_initialized": False,
    "message": "جاري التهيئة...",
    "error": None
}

def validate_environment():
    """التحقق من إعدادات البيئة"""
    required_vars = ['OPENROUTER_API_KEY']
    missing_vars = [var for var in required_vars if not os.getenv(var)]
    
    if missing_vars:
        return False, f"مفاتيح API مفقودة: {', '.join(missing_vars)}"
    
    return True, "جميع الإعدادات صحيحة"

@app.on_event("startup")
async def startup_event():
    """تهيئة التطبيق عند البدء"""
    global initialization_status
    
    # التحقق من إعدادات البيئة
    env_valid, env_message = validate_environment()
    if not env_valid:
        initialization_status["error"] = env_message
        logger.error(f"خطأ في إعدادات البيئة: {env_message}")
        return
    
    pdf_path = "medical_book.pdf"
    db_filename = "medical_db"
    
    try:
        start_time = time.time()
        
        # التحقق من وجود قاعدة بيانات محفوظة مسبقاً
        if os.path.exists(f"{db_filename}.index") and os.path.exists(f"{db_filename}_docs.pkl"):
            logger.info("جاري تحميل قاعدة البيانات المحفوظة...")
            embedding_manager.load(db_filename)
            initialization_status.update({
                "is_initialized": True,
                "message": "تم التهيئة بنجاح من البيانات المحفوظة",
                "load_time": f"{time.time() - start_time:.2f} ثانية"
            })
            logger.info(f"✅ تم تحميل {len(embedding_manager.documents)} مستند في {time.time() - start_time:.2f} ثانية")
            return
        
        # معالجة ملف PDF
        if not os.path.exists(pdf_path):
            initialization_status.update({
                "message": f"لم يتم العثور على {pdf_path}",
                "error": "ملف PDF غير موجود"
            })
            logger.error(f"ملف PDF غير موجود: {pdf_path}")
            return
        
        logger.info(f"جاري معالجة {pdf_path}...")
        processor = PDFProcessor(pdf_path, chunk_size=500)
        chunks = processor.process()
        
        if not chunks:
            initialization_status.update({
                "message": "لم يتم استخراج أي محتوى من PDF",
                "error": "PDF فارغ أو غير قابل للقراءة"
            })
            logger.error("لم يتم استخراج أي محتوى من PDF")
            return
        
        # حفظ الأجزاء للمراجعة
        processor.save_chunks("chunks_output.txt")
        
        # إنشاء embeddings
        logger.info("جاري إنشاء embeddings وحفظ قاعدة البيانات...")
        embedding_manager.add_documents(chunks)
        embedding_manager.save(db_filename)
        
        initialization_status.update({
            "is_initialized": True,
            "message": "تم التهيئة بنجاح من ملف PDF",
            "load_time": f"{time.time() - start_time:.2f} ثانية",
            "total_chunks": len(chunks)
        })
        
        logger.info(f"✅ تمت التهيئة بنجاح! {len(chunks)} جزء في {time.time() - start_time:.2f} ثانية")
        
    except Exception as e:
        error_msg = f"خطأ في التهيئة: {str(e)}"
        initialization_status.update({
            "message": error_msg,
            "error": str(e)
        })
        logger.error(f"❌ خطأ في التهيئة: {e}")

@app.get("/")
async def root():
    """الصفحة الرئيسية"""
    return {
        "message": "مرحباً في AFYA CARE - المساعد الطبي الذكي",
        "version": "2.0.0",
        "docs": "/docs",
        "status": "/status"
    }

@app.get("/status")
async def status():
    """معلومات الحالة المفصلة"""
    env_valid, env_message = validate_environment()
    
    status_info = {
        "initialized": initialization_status["is_initialized"],
        "message": initialization_status["message"],
        "environment_ok": env_valid,
        "environment_message": env_message,
        "total_documents": len(embedding_manager.documents) if embedding_manager.documents else 0,
        "model": embedding_manager.model.get_sentence_embedding_dimension() if hasattr(embedding_manager.model, 'get_sentence_embedding_dimension') else "Unknown"
    }
    
    if "error" in initialization_status and initialization_status["error"]:
        status_info["error"] = initialization_status["error"]
    
    if "load_time" in initialization_status:
        status_info["load_time"] = initialization_status["load_time"]
    
    if "total_chunks" in initialization_status:
        status_info["total_chunks"] = initialization_status["total_chunks"]
    
    return status_info

@app.post("/analyze_daily_report", response_model=DailyReportResponse)
async def analyze_daily_report(request: DailyReportRequest):
    """تحليل تقرير نهاية اليوم باستخدام الذكاء الاصطناعي"""
    start_time = time.time()
    
    if not initialization_status["is_initialized"]:
        raise HTTPException(
            status_code=503, 
            detail=initialization_status.get("message", "التطبيق قيد الإعداد. حاول لاحقاً")
        )
    
    if not os.getenv('OPENROUTER_API_KEY'):
        raise HTTPException(
            status_code=500, 
            detail="مفتاح OpenRouter API غير موجود. تأكد من إعداد ملف .env"
        )
    
    try:
        # بناء تقرير مفصل عن الأدوية والإجابات
        medications_summary = _build_medications_summary(request.medications)
        questionnaire_summary = _build_questionnaire_summary(request.questionnaire_answers)
        
        # البحث عن معلومات طبية ذات صلة
        medical_context = _get_medical_context(request.medications, request.questionnaire_answers)
        
        # إعداد رسالة الذكاء الاصطناعي
        messages = [
            {
                "role": "system",
                "content": f"""أنت مساعد طبي ذكي متخصص في تحليل التقارير الصحية اليومية.

🎯 **المهمة**: تحليل تقرير المستخدم الصحي اليومي وإعطاء تحليل مفيد وتوصيات عملية.

👤 **المستخدم**: {request.user_name}
📅 **تاريخ التقرير**: {datetime.now().strftime('%Y-%m-%d %H:%M')}

📊 **معلومات التقرير**:
{medications_summary}
{questionnaire_summary}

🎯 **تعليمات التحليل**:
1. حلل حالة الالتزام بالأدوية
2. تقييم الأعراض الجانبية المبلغ عنها
3. تقييم الحالة العامة للمستخدم
4. أعط توصيات عملية ومحددة
5. حدد مستوى الإنذار (منخفض، متوسط، عالي)

📐 **معايير الدرجة الصحية** (مهم جداً):
- 90-100: ممتاز - التزام كامل بالأدوية + لا أعراض جانبية + شعور ممتاز
- 80-89: جيد جداً - التزام جيد + أعراض خفيفة أو معدومة + شعور جيد
- 70-79: جيد - التزام متوسط + أعراض خفيفة + شعور متوسط إلى جيد
- 60-69: مقبول - التزام ضعيف أو أعراض متوسطة + شعور متوسط
- 50-59: يحتاج تحسين - التزام ضعيف + أعراض متوسطة + شعور سيء
- 0-49: يحتاج عناية فورية - عدم التزام + أعراض شديدة + شعور سيء جداً

⚠️ **تحذيرات هامة**:
- أنت نظام ذكي وليس بديلاً عن الطبيب
- لا تقدم تشخيصات طبية
- ركز على التوعية والنصائح العامة
- في الحالات الخطيرة، نصح بالتوجه للطوارئ

📝 **تنسيق الإجابة المطلوب (مهم جداً)**: 
يجب أن تكون الإجابة بهذا الشكل بالضبط:

**التحليل:**
[اكتب التحليل المفصل هنا]

**التوصيات:**
[اكتب التوصيات هنا]

**الدرجة الصحية:** [رقم من 0 إلى 100]

**مستوى الإنذار:** [منخفض أو متوسط أو عالي]"""
            },
            {
                "role": "user",
                "content": f"""**السياق الطبي ذو الصلة:**
{medical_context}

**طلب التحليل:**
قم بتحليل التقرير الصحي اليومي للمستخدم وأعطني التحليل بالتنسيق المطلوب بالضبط:

1. التحليل المفصل للحالة
2. التوصيات العملية
3. الدرجة الصحية (رقم واضح من 0-100)
4. مستوى الإنذار (منخفض/متوسط/عالي)

تذكر: يجب أن تكون الدرجة الصحية متناسبة مع الحالة الفعلية للمريض!"""
            }
        ]
        
        # استدعاء OpenRouter API
        api_start = time.time()
        try:
            response = requests.post(
                "https://openrouter.ai/api/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {os.getenv('OPENROUTER_API_KEY')}",
                    "HTTP-Referer": "http://localhost:8000",
                    "X-Title": "AFYA CARE - Medical RAG Chatbot",
                },
                json={
                    "model": "gpt-3.5-turbo",
                    "messages": messages,
                    "temperature": 0.3,
                    "max_tokens": 1500,
                    "top_p": 0.9,
                },
                timeout=60
            )
            
            api_time = time.time() - api_start
            logger.info(f"📄 استجابة API لتقرير اليوم في {api_time:.2f} ثانية - الحالة: {response.status_code}")
            
            if response.status_code != 200:
                error_detail = "خطأ غير معروف"
                if response.text:
                    try:
                        error_data = response.json()
                        error_detail = error_data.get('error', {}).get('message', response.text[:200])
                    except:
                        error_detail = response.text[:200]
                
                logger.error(f"❌ خطأ من OpenRouter API: {error_detail}")
                raise HTTPException(
                    status_code=500, 
                    detail=f"خطأ في خدمة الذكاء الاصطناعي: {error_detail}"
                )
            
            response_data = response.json()
            
            if not response_data.get("choices") or not response_data["choices"]:
                raise HTTPException(status_code=500, detail="استجابة فارغة من خدمة الذكاء الاصطناعي")
            
            ai_response = response_data["choices"][0]["message"]["content"]
            
        except requests.exceptions.Timeout:
            logger.error("⏰ انتهت مهلة الاتصال بـ OpenRouter API")
            raise HTTPException(status_code=504, detail="انتهت مهلة الاتصال بخدمة الذكاء الاصطناعي")
        except requests.exceptions.ConnectionError:
            logger.error("🔌 خطأ في الاتصال بـ OpenRouter API")
            raise HTTPException(status_code=503, detail="تعذر الاتصال بخدمة الذكاء الاصطناعي")
        
        # معالجة استجابة الذكاء الاصطناعي
        analysis, recommendations, health_score, warning_level = _parse_ai_response(ai_response)
        
        total_time = time.time() - start_time
        
        logger.info(f"✅ تم تحليل تقرير اليوم في {total_time:.2f} ثانية - الدرجة: {health_score} - الإنذار: {warning_level}")
        
        return DailyReportResponse(
            analysis=analysis,
            recommendations=recommendations,
            health_score=health_score,
            warning_level=warning_level,
            processing_time=total_time
        )
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"💥 خطأ غير متوقع في تحليل تقرير اليوم: {str(e)}")
        raise HTTPException(
            status_code=500, 
            detail=f"خطأ داخلي في المعالجة: {str(e)}"
        )

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
    
    # تعيين أسماء واضحة للمفاتيح
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
    
    # البحث عن معلومات حول الأدوية
    for med in medications:
        med_name = med.get('name', '')
        if med_name:
            relevant_docs = embedding_manager.search(med_name, k=2)
            for doc in relevant_docs[:1]:  # أفضل نتيجة لكل دواء
                if doc['score'] < 1.8:
                    context_parts.append(f"معلومات عن {med_name}: {doc['text'][:300]}...")
    
    # البحث عن معلومات حول الأعراض
    side_effects = answers.get('side_effects', '')
    if side_effects and 'لا توجد أعراض' not in side_effects:
        relevant_docs = embedding_manager.search(side_effects, k=2)
        for doc in relevant_docs[:1]:
            if doc['score'] < 1.8:
                context_parts.append(f"معلومات عن {side_effects}: {doc['text'][:300]}...")
    
    # البحث عن معلومات عامة
    general_feeling = answers.get('general_feeling', '')
    if general_feeling and 'جيد' not in general_feeling:
        relevant_docs = embedding_manager.search("تحسين الصحة العامة", k=1)
        for doc in relevant_docs:
            if doc['score'] < 2.0:
                context_parts.append(f"نصائح للصحة العامة: {doc['text'][:300]}...")
    
    return "\n\n".join(context_parts) if context_parts else "لا توجد معلومات طبية إضافية متاحة"

def _parse_ai_response(ai_response: str) -> tuple:
    """تحليل استجابة الذكاء الاصطناعي لاستخراج المكونات"""
    
    # القيم الافتراضية
    analysis = ""
    recommendations = ""
    health_score = 70
    warning_level = "medium"
    
    try:
        # تنظيف النص
        response_text = ai_response.strip()
        
        # =============== استخراج التحليل ===============
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
        
        # إذا لم يتم العثور على تحليل منفصل، استخدم الجزء الأول
        if not analysis:
            parts = response_text.split("التوصيات")
            analysis = parts[0].strip()
        
        # =============== استخراج التوصيات ===============
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
        
        # إذا لم يتم العثور على توصيات
        if not recommendations:
            recommendations = "التزم بالأدوية في مواعيدها، وتابع مع طبيبك المعالج بانتظام."
        
        # =============== استخراج الدرجة الصحية ===============
        # نمط 1: الدرجة الصحية: 85
        score_pattern1 = r'(?:الدرجة الصحية|الدرجة)[:\s]+(\d{1,3})'
        match = re.search(score_pattern1, response_text)
        if match:
            score = int(match.group(1))
            if 0 <= score <= 100:
                health_score = score
                logger.info(f"✅ تم استخراج الدرجة: {health_score}")
        
        # نمط 2: رقم مع علامة %
        if health_score == 70:  # لم نجد درجة بعد
            score_pattern2 = r'(\d{1,3})\s*%'
            matches = re.findall(score_pattern2, response_text)
            for match in matches:
                score = int(match)
                if 0 <= score <= 100:
                    health_score = score
                    logger.info(f"✅ تم استخراج الدرجة من %: {health_score}")
                    break
        
        # نمط 3: البحث في السطور عن أي رقم بين 0-100
        if health_score == 70:
            lines = response_text.split('\n')
            for line in lines:
                if any(word in line for word in ['درجة', 'score', 'نقاط']):
                    numbers = re.findall(r'\b(\d{1,3})\b', line)
                    for num in numbers:
                        score = int(num)
                        if 0 <= score <= 100:
                            health_score = score
                            logger.info(f"✅ تم استخراج الدرجة من السطر: {health_score}")
                            break
                    if health_score != 70:
                        break
        
        # =============== استخراج مستوى الإنذار ===============
        response_lower = response_text.lower()
        
        # البحث عن "مستوى الإنذار: عالي"
        if "**مستوى الإنذار:**" in response_text or "مستوى الإنذار:" in response_text:
            warning_part = response_text.split("مستوى الإنذار:")[-1].strip().lower()
            if "عالي" in warning_part or "high" in warning_part:
                warning_level = "high"
            elif "منخفض" in warning_part or "low" in warning_part:
                warning_level = "low"
            elif "متوسط" in warning_part or "medium" in warning_part:
                warning_level = "medium"
        else:
            # التقدير بناءً على الكلمات المفتاحية
            if any(word in response_lower for word in ['خطير', 'طوارئ', 'فوري', 'emergency', 'عاجل', 'شديد جداً']):
                warning_level = "high"
            elif any(word in response_lower for word in ['ممتاز', 'excellent', 'جيد جداً', 'مستقر', 'طبيعي']):
                warning_level = "low"
            elif any(word in response_lower for word in ['متوسط', 'medium', 'مراقبة', 'انتباه']):
                warning_level = "medium"
        
        # التقدير بناءً على الدرجة إذا لم نجد تصنيف واضح
        if warning_level == "medium":  # القيمة الافتراضية
            if health_score >= 80:
                warning_level = "low"
            elif health_score >= 60:
                warning_level = "medium"
            else:
                warning_level = "high"
        
        logger.info(f"📊 النتائج المستخرجة - الدرجة: {health_score}, الإنذار: {warning_level}")
        
    except Exception as e:
        logger.error(f"⚠️ خطأ في تحليل استجابة الذكاء الاصطناعي: {e}")
        # استخدام الاستجابة كاملة كتحليل
        if not analysis:
            analysis = ai_response
        if not recommendations:
            recommendations = "يرجى مراجعة التحليل أعلاه واستشارة الطبيب للحصول على التوصيات المناسبة."
    
    # التأكد من عدم وجود قيم فارغة
    if not analysis or len(analysis) < 10:
        analysis = ai_response
    
    if not recommendations or len(recommendations) < 10:
        recommendations = "التزم بالأدوية في مواعيدها، واستشر طبيبك عند ظهور أي أعراض جديدة."
    
    return analysis, recommendations, health_score, warning_level

@app.post("/analyze_questionnaire")
async def analyze_questionnaire(request: QuestionnaireRequest):
    """تحليل إجابات الاستبيان وإرجاع تحليل مخصص"""
    try:
        analysis = generate_questionnaire_analysis(request.user_type, request.answers)
        
        return {
            "analysis": analysis,
            "personalized_advice": generate_personalized_advice(request.user_type, request.answers),
            "welcome_message": generate_welcome_message(request.user_type)
        }
    
    except Exception as e:
        logger.error(f"خطأ في تحليل الاستبيان: {str(e)}")
        raise HTTPException(status_code=500, detail=f"خطأ في تحليل الاستبيان: {str(e)}")

def generate_questionnaire_analysis(user_type: str, answers: dict):
    """إنشاء تحليل مخصص بناءً على إجابات الاستبيان"""
    
    if user_type == "treatment":
        return _analyze_treatment_questionnaire(answers)
    else:
        return _analyze_prevention_questionnaire(answers)

def _analyze_treatment_questionnaire(answers: dict):
    """تحليل استبيان العلاج"""
    analysis = "تحليل حالتك العلاجية:\n\n"
    
    # تحليل الالتزام بالعلاج
    adherence = answers.get('adherence', '')
    if 'جميع الأدوية' in adherence:
        analysis += "• التزامك بالعلاج ممتاز، استمر على هذا النحو\n"
    elif 'معظم الأدوية' in adherence:
        analysis += "• مستوى الالتزام جيد ولكن يمكن تحسينه\n"
    else:
        analysis += "• تحتاج لتحسين الالتزام بالعلاج للوصول للنتائج المثلى\n"
    
    # تحليل الأعراض الجانبية
    side_effects = answers.get('side_effects', '')
    if 'لا توجد أعراض' not in side_effects:
        analysis += "• هناك أعراض جانبية تحتاج للمتابعة\n"
    
    # تحليل الحالة العامة
    general_feeling = answers.get('general_feeling', '')
    if 'سيء' in general_feeling:
        analysis += "• حالتك العامة تحتاج للمراجعة مع الطبيب\n"
    
    return analysis

def _analyze_prevention_questionnaire(answers: dict):
    """تحليل استبيان الوقاية"""
    analysis = "تحليل صحتك العامة:\n\n"
    
    # تحليل النشاط البدني
    exercise = answers.get('exercise', '')
    if 'لا أمارس' in exercise:
        analysis += "• تحتاج لزيادة النشاط البدني\n"
    elif '3-4 مرات' in exercise or 'يومياً' in exercise:
        analysis += "• مستوى النشاط البدني ممتاز\n"
    
    # تحليل النظام الغذائي
    diet = answers.get('diet', '')
    if 'غير صحي' in diet:
        analysis += "• النظام الغذائي يحتاج للتحسين\n"
    elif 'صحي جداً' in diet:
        analysis += "• النظام الغذائي ممتاز\n"
    
    # تحليل التوتر
    stress = answers.get('stress', '')
    if 'مرتفع' in stress:
        analysis += "• إدارة التوتر مهمة لصحتك\n"
    
    return analysis

def generate_personalized_advice(user_type: str, answers: dict):
    """إنشاء نصائح مخصصة بناءً على الإجابات"""
    
    if user_type == "treatment":
        return """نصائح علاجية مخصصة:
• التزم بمواعيد الأدوية بدقة
• سجل أي أعراض جانبية تواجهها
• حافظ على مواعيد المتابعة مع الطبيب
• اشرب كمية كافية من الماء
• احصل على قسط كاف من الراحة"""
    else:
        return """نصائح وقائية مخصصة:
• مارس الرياضة 30 دقيقة يومياً
• تناول 5 حصص من الخضار والفواكه
• اشرب 8 أكواب ماء يومياً
• نم 7-8 ساعات ليلاً
• أجري فحوصات دورية سنوياً"""

def generate_welcome_message(user_type: str):
    """إنشاء رسالة ترحيب مخصصة"""
    if user_type == "treatment":
        return "مرحباً! أنا مساعدك الصحي. كيف يمكنني مساعدتك في متابعة علاجك اليوم? 💊"
    else:
        return "مرحباً! أنا مساعدك الصحي. كيف يمكنني مساعدتك في الحفاظ على صحتك؟ 🌿"

@app.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    """الإجابة على الأسئلة الطبية"""
    start_time = time.time()
    
    if not initialization_status["is_initialized"]:
        raise HTTPException(
            status_code=503, 
            detail=initialization_status.get("message", "التطبيق قيد الإعداد. حاول لاحقاً")
        )
    
    # التحقق من وجود مفتاح API
    if not os.getenv('OPENROUTER_API_KEY'):
        raise HTTPException(
            status_code=500, 
            detail="مفتاح OpenRouter API غير موجود. تأكد من إعداد ملف .env"
        )
    
    try:
        # تسجيل السؤال
        logger.info(f"🔍 معالجة سؤال: {request.question} - نوع المستخدم: {request.user_type}")
        
        # البحث عن النصوص ذات الصلة
        relevant_docs = embedding_manager.search(request.question, k=5)
        
        # تصفية النتائج ذات الجودة المنخفضة
        filtered_docs = [doc for doc in relevant_docs if doc['score'] < 1.8]
        
        if not filtered_docs:
            filtered_docs = relevant_docs[:2]
            logger.warning("⚠️ لم توجد نتائج عالية الجودة، استخدام أفضل النتائج المتاحة")
        
        search_time = time.time() - start_time
        logger.info(f"🔎 تم العثور على {len(filtered_docs)} وثيقة ذات صلة في {search_time:.2f} ثانية")
        
        # بناء السياق مع معلومات المستخدم
        context = "\n\n".join([f"[مصدر {i+1} - درجة الثقة: {1/(1+doc['score']):.2f}]\n{doc['text']}" 
                              for i, doc in enumerate(filtered_docs)])
        
        # إعداد رسالة مخصصة بناءً على نوع المستخدم
        user_context = ""
        if request.user_type == "treatment":
            user_context = "المستخدم حالياً تحت العلاج الطبي ويحتاج لمعلومات دقيقة عن الأدوية والعلاجات."
        elif request.user_type == "prevention":
            user_context = "المستخدم يهتم بالوقاية الصحية والعادات السليمة."
        
        # إعداد الرسالة المحسنة
        messages = [
            {
                "role": "system",
                "content": f"""أنت مساعد طبي ذكي في تطبيق AFYA CARE. 
                
🎯 **المهمة**: تقديم معلومات طبية دقيقة بناءً على المصادر المقدمة فقط.

👤 **معلومات المستخدم**: {user_context}

⚠️ **تحذيرات هامة**:
- أنت نظام ذكي وليس بديلاً عن الطبيب البشري
- لا تقدم تشخيصات نهائية أو توصيات علاجية
- في الحالات الطارئة، يجب التوجه إلى أقرب مركز طبي فوراً
- المعلومات للأغراض التعليمية فقط

📝 **أسلوب الإجابة**:
1. ابدأ بتعريف الحالة الطبية بوضوح
2. اذكر الأعراض الرئيسية والثانوية
3. ناقش الأسباب المحتملة وعوامل الخطر
4. اذكر الإجراءات الأولية المقترحة
5. اختتم بتوصية مراجعة الطبيب للتشخيص الدقيق

❌ **تجنب تماماً**:
- وصف أدوية محددة أو جرعات
- تشخيص الحالات الشخصية
- إعطاء وعود شفاء
- التكهن بمضاعفات محددة"""
            },
            {
                "role": "user",
                "content": f"""**المعلومات الطبية المتاحة من الموسوعة الطبية:**

{context}

---

**سؤال المستخدم:** 
{request.question}

**تعليمات الإجابة**:
- أجب باللغة العربية الفصحى الواضحة
- استخدم المعلومات من المصادر أعلاه فقط
- لا تخترع معلومات غير موجودة في المصادر
- إذا كانت المعلومات غير كافية، اذكر ذلك بوضوح
- ركز على الدقة الطبية والوضوح"""
            }
        ]
        
        # استدعاء OpenRouter API
        api_start = time.time()
        try:
            response = requests.post(
                "https://openrouter.ai/api/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {os.getenv('OPENROUTER_API_KEY')}",
                    "HTTP-Referer": "http://localhost:8000",
                    "X-Title": "AFYA CARE - Medical RAG Chatbot",
                },
                json={
                    "model": "gpt-3.5-turbo",
                    "messages": messages,
                    "temperature": 0.3,
                    "max_tokens": 1000,
                    "top_p": 0.9,
                },
                timeout=45
            )
            
            api_time = time.time() - api_start
            logger.info(f"📄 استجابة API في {api_time:.2f} ثانية - الحالة: {response.status_code}")
            
            if response.status_code != 200:
                error_detail = "خطأ غير معروف"
                if response.text:
                    try:
                        error_data = response.json()
                        error_detail = error_data.get('error', {}).get('message', response.text[:200])
                    except:
                        error_detail = response.text[:200]
                
                logger.error(f"❌ خطأ من OpenRouter API: {error_detail}")
                raise HTTPException(
                    status_code=500, 
                    detail=f"خطأ في خدمة الذكاء الاصطناعي: {error_detail}"
                )
            
            response_data = response.json()
            
            if not response_data.get("choices") or not response_data["choices"]:
                raise HTTPException(status_code=500, detail="استجابة فارغة من خدمة الذكاء الاصطناعي")
            
            answer = response_data["choices"][0]["message"]["content"]
            
        except requests.exceptions.Timeout:
            logger.error("⏰ انتهت مهلة الاتصال بـ OpenRouter API")
            raise HTTPException(status_code=504, detail="انتهت مهلة الاتصال بخدمة الذكاء الاصطناعي")
        except requests.exceptions.ConnectionError:
            logger.error("🔌 خطأ في الاتصال بـ OpenRouter API")
            raise HTTPException(status_code=503, detail="تعذر الاتصال بخدمة الذكاء الاصطناعي")
        
        total_time = time.time() - start_time
        
        # إعداد المصادر للإرجاع
        sources_response = []
        for doc in filtered_docs:
            source_text = doc["text"]
            page_num = None
            if "صفحة" in source_text:
                page_match = re.search(r'صفحة\s+(\d+)', source_text)
                if page_match:
                    page_num = int(page_match.group(1))
            
            sources_response.append({
                "text": source_text[:250] + "..." if len(source_text) > 250 else source_text,
                "relevance_score": float(doc["score"]),
                "confidence": 1/(1+doc["score"]),
                "page_number": page_num
            })
        
        logger.info(f"✅ تمت معالجة السؤال في {total_time:.2f} ثانية")
        
        return ChatResponse(
            answer=answer,
            sources=sources_response,
            processing_time=total_time,
            user_type=request.user_type
        )
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"💥 خطأ غير متوقع في معالجة السؤال: {str(e)}")
        raise HTTPException(
            status_code=500, 
            detail=f"خطأ داخلي في المعالجة: {str(e)}"
        )

@app.post("/suggest_medication_schedule", response_model=MedicationScheduleResponse)
async def suggest_medication_schedule(request: MedicationScheduleRequest):
    """اقتراح جدول مواعيد الأدوية باستخدام الذكاء الاصطناعي"""
    start_time = time.time()
    
    if not initialization_status["is_initialized"]:
        raise HTTPException(
            status_code=503, 
            detail=initialization_status.get("message", "التطبيق قيد الإعداد. حاول لاحقاً")
        )
    
    if not os.getenv('OPENROUTER_API_KEY'):
        raise HTTPException(
            status_code=500, 
            detail="مفتاح OpenRouter API غير موجود. تأكد من إعداد ملف .env"
        )
    
    try:
        # بناء قائمة الأدوية
        medications_list = "\n".join([f"• {med}" for med in request.medications])
        
        # إعداد رسالة الذكاء الاصطناعي
        messages = [
            {
                "role": "system",
                "content": """أنت مساعد طبي ذكي متخصص في جدولة الأدوية.

🎯 **المهمة**: اقتراح جدول مثالي لمواعيد الأدوية بناءً على:
- أنواع الأدوية
- مواعيد النوم والاستيقاظ
- تفضيلات المستخدم

📝 **المبادئ التوجيهية**:
1. وزع الأدوية على مدار اليوم بشكل متوازن
2. احترم مواعيد نوم واستيقاظ المستخدم
3. راعي التفاعلات بين الأدوية (إن وجدت)
4. اقترح أوقات مناسبة مع الوجبات إذا لزم الأمر
5. اشرح السبب وراء كل توقيت مقترح

⚠️ **ملاحظات هامة**:
- أنت تقدم اقتراحات عامة فقط
- يجب على المستخدم استشارة الطبيب أو الصيدلي
- الاقتراحات للأغراض التوجيهية فقط"""
            },
            {
                "role": "user",
                "content": f"""**معلومات المستخدم:**

🕒 مواعيد النوم والاستيقاظ:
- وقت النوم: {request.sleep_time}
- وقت الاستيقاظ: {request.wake_up_time}

💊 الأدوية المطلوبة:
{medications_list}

{'**تفضيلات إضافية:** ' + request.user_preferences if request.user_preferences else 'لا توجد تفضيلات إضافية'}

**الطلب:**
اقترح جدولاً مثالياً لمواعيد تناول هذه الأدوية مع شرح موجز لكل توقيت."""
            }
        ]
        
        # استدعاء OpenRouter API
        api_start = time.time()
        try:
            response = requests.post(
                "https://openrouter.ai/api/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {os.getenv('OPENROUTER_API_KEY')}",
                    "HTTP-Referer": "http://localhost:8000",
                    "X-Title": "AFYA CARE - Medication Scheduler",
                },
                json={
                    "model": "gpt-3.5-turbo",
                    "messages": messages,
                    "temperature": 0.4,
                    "max_tokens": 1200,
                    "top_p": 0.9,
                },
                timeout=45
            )
            
            api_time = time.time() - api_start
            logger.info(f"⏰ استجابة API للجدولة في {api_time:.2f} ثانية - الحالة: {response.status_code}")
            
            if response.status_code != 200:
                error_detail = "خطأ غير معروف"
                if response.text:
                    try:
                        error_data = response.json()
                        error_detail = error_data.get('error', {}).get('message', response.text[:200])
                    except:
                        error_detail = response.text[:200]
                
                logger.error(f"❌ خطأ من OpenRouter API: {error_detail}")
                raise HTTPException(
                    status_code=500, 
                    detail=f"خطأ في خدمة الذكاء الاصطناعي: {error_detail}"
                )
            
            response_data = response.json()
            
            if not response_data.get("choices") or not response_data["choices"]:
                raise HTTPException(status_code=500, detail="استجابة فارغة من خدمة الذكاء الاصطناعي")
            
            ai_response = response_data["choices"][0]["message"]["content"]
            
        except requests.exceptions.Timeout:
            logger.error("⏰ انتهت مهلة الاتصال بـ OpenRouter API")
            raise HTTPException(status_code=504, detail="انتهت مهلة الاتصال بخدمة الذكاء الاصطناعي")
        except requests.exceptions.ConnectionError:
            logger.error("🔌 خطأ في الاتصال بـ OpenRouter API")
            raise HTTPException(status_code=503, detail="تعذر الاتصال بخدمة الذكاء الاصطناعي")
        
        total_time = time.time() - start_time
        
        logger.info(f"✅ تم إنشاء اقتراح الجدولة في {total_time:.2f} ثانية")
        
        return MedicationScheduleResponse(
            suggested_schedule=ai_response,
            explanation="تم إنشاء الاقتراح بناءً على معلوماتك والأسس الطبية العامة",
            processing_time=total_time
        )
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"💥 خطأ غير متوقع في إنشاء جدول الأدوية: {str(e)}")
        raise HTTPException(
            status_code=500, 
            detail=f"خطأ داخلي في المعالجة: {str(e)}"
        )


@app.get("/health")
async def health():
    """فحص صحة النظام"""
    health_status = {
        "status": "healthy",
        "timestamp": time.time(),
        "initialized": initialization_status["is_initialized"],
        "database_loaded": len(embedding_manager.documents) > 0 if embedding_manager.documents else False,
        "environment_ok": validate_environment()[0]
    }
    
    if initialization_status.get("error"):
        health_status.update({
            "status": "degraded",
            "error": initialization_status["error"]
        })
    
    return health_status

@app.post("/reload")
async def reload_database():
    """إعادة تحميل قاعدة البيانات (للاستخدام في التطوير)"""
    if not os.path.exists("medical_db.index"):
        raise HTTPException(status_code=404, detail="قاعدة البيانات غير موجودة")
    
    try:
        embedding_manager.load("medical_db")
        logger.info("🔄 تم إعادة تحميل قاعدة البيانات يدوياً")
        return {"message": "تم إعادة تحميل قاعدة البيانات بنجاح", "documents": len(embedding_manager.documents)}
    except Exception as e:
        logger.error(f"❌ فشل إعادة تحميل قاعدة البيانات: {e}")
        raise HTTPException(status_code=500, detail=f"فشل إعادة التحميل: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )