from fastapi import APIRouter, HTTPException
import time
import os
import requests
import logging
import json
import re

from core.state import initialization_status, embedding_manager, validate_environment
from rag.models import (
    ChatRequest, ChatResponse, DailyReportRequest, DailyReportResponse,
    QuestionnaireRequest, MedicationScheduleRequest, MedicationScheduleResponse
)
from rag.services import (
    _build_medications_summary, _build_questionnaire_summary, _get_medical_context,
    _parse_ai_response, _build_treatment_analysis_prompt, _build_prevention_analysis_prompt,
    _generate_welcome_message, _generate_personalized_advice
)
from agent.core import run_agentic_chat

logger = logging.getLogger(__name__)

router = APIRouter()

@router.post("/analyze_daily_report", response_model=DailyReportResponse)
async def analyze_daily_report(request: DailyReportRequest):
    """تحليل تقرير نهاية اليوم باستخدام الذكاء الاصطناعي"""
    start_time = time.time()
    
    if not initialization_status["is_initialized"]:
        raise HTTPException(status_code=503, detail=initialization_status.get("message", "التطبيق قيد الإعداد. حاول لاحقاً"))
    
    if not os.getenv('OPENROUTER_API_KEY'):
        raise HTTPException(status_code=500, detail="مفتاح OpenRouter API غير موجود. تأكد من إعداد ملف .env")
    
    try:
        medications_summary = _build_medications_summary(request.medications)
        questionnaire_summary = _build_questionnaire_summary(request.questionnaire_answers)
        medical_context = _get_medical_context(request.medications, request.questionnaire_answers)
        
        messages = [
            {
                "role": "system",
                "content": f"أنت مساعد طبي ذكي متخصص في تحليل التقارير الصحية اليومية.\n\n🎯 **المهمة**: تحليل تقرير المستخدم الصحي اليومي وإعطاء تحليل مفيد وتوصيات عملية.\n\n👤 **المستخدم**: {request.user_name}\n\n📊 **معلومات التقرير**:\n{medications_summary}\n{questionnaire_summary}\n\n🎯 **تعليمات التحليل**:\n1. حلل حالة الالتزام بالأدوية\n2. تقييم الأعراض الجانبية المبلغ عنها\n3. تقييم الحالة العامة للمستخدم\n4. أعط توصيات عملية ومحددة\n5. حدد مستوى الإنذار (منخفض، متوسط، عالي)\n\n📐 **معايير الدرجة الصحية**:\n- 90-100: ممتاز\n- 80-89: جيد جداً\n- 70-79: جيد\n- 60-69: مقبول\n- 50-59: يحتاج تحسين\n- 0-49: يحتاج عناية فورية\n\n📝 **تنسيق الإجابة المطلوب**:\n\n**التحليل:**\n[اكتب التحليل المفصل هنا]\n\n**التوصيات:**\n[اكتب التوصيات هنا]\n\n**الدرجة الصحية:** [رقم من 0 إلى 100]\n\n**مستوى الإنذار:** [منخفض أو متوسط أو عالي]"
            },
            {
                "role": "user",
                "content": f"**السياق الطبي ذو الصلة:**\n{medical_context}\n\n**طلب التحليل:**\nقم بتحليل التقرير الصحي اليومي للمستخدم وأعطني التحليل بالتنسيق المطلوب بالضبط"
            }
        ]
        
        response = requests.post(
            "https://openrouter.ai/api/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {os.getenv('OPENROUTER_API_KEY')}",
                "HTTP-Referer": "http://localhost:8000",
                "X-Title": "AFYA CARE - Medical RAG Chatbot",
            },
            json={
                "model": "openai/gpt-oss-120b:free",
                "messages": messages,
                "temperature": 0.3,
                "max_tokens": 1500,
                "top_p": 0.9,
            },
            timeout=60
        )
        
        if response.status_code != 200:
            raise HTTPException(status_code=500, detail=response.text[:200])
        
        response_data = response.json()
        ai_response = response_data["choices"][0]["message"]["content"]
        
        analysis, recommendations, health_score, warning_level = _parse_ai_response(ai_response)
        total_time = time.time() - start_time
        
        return DailyReportResponse(
            analysis=analysis,
            recommendations=recommendations,
            health_score=health_score,
            warning_level=warning_level,
            processing_time=total_time
        )
    except Exception as e:
        logger.error(f"💥 خطأ غير متوقع في تحليل تقرير اليوم: {str(e)}")
        raise HTTPException(status_code=500, detail=f"خطأ داخلي في المعالجة: {str(e)}")

@router.post("/analyze_questionnaire")
async def analyze_questionnaire(request: QuestionnaireRequest):
    """تحليل إجابات الاستبيان باستخدام الذكاء الاصطناعي"""
    start_time = time.time()
    
    if not initialization_status["is_initialized"]:
        raise HTTPException(status_code=503, detail=initialization_status.get("message", "التطبيق قيد الإعداد. حاول لاحقاً"))
    
    if not os.getenv('OPENROUTER_API_KEY'):
        raise HTTPException(status_code=500, detail="مفتاح OpenRouter API غير موجود.")
    
    try:
        if request.user_type == "treatment":
            analysis_prompt = _build_treatment_analysis_prompt(request.answers)
        else:
            analysis_prompt = _build_prevention_analysis_prompt(request.answers)
        
        response = requests.post(
            "https://openrouter.ai/api/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {os.getenv('OPENROUTER_API_KEY')}",
                "HTTP-Referer": "http://localhost:8000",
                "X-Title": "AFYA CARE - Questionnaire Analysis",
            },
            json={
                "model": "openai/gpt-oss-120b:free",
                "messages": analysis_prompt,
                "temperature": 0.3,
                "max_tokens": 1500,
                "top_p": 0.9,
            },
            timeout=45
        )
        
        if response.status_code != 200:
            raise HTTPException(status_code=500, detail=response.text[:200])
        
        response_data = response.json()
        ai_analysis = response_data["choices"][0]["message"]["content"]
        
        welcome_message = _generate_welcome_message(request.user_type, request.answers)
        total_time = time.time() - start_time
        
        return {
            "analysis": ai_analysis,
            "personalized_advice": _generate_personalized_advice(request.user_type, request.answers),
            "welcome_message": welcome_message,
            "processing_time": total_time
        }
    except Exception as e:
        logger.error(f"💥 خطأ غير متوقع في تحليل الاستبيان: {str(e)}")
        raise HTTPException(status_code=500, detail=f"خطأ داخلي في المعالجة: {str(e)}")

@router.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    """الإجابة على الأسئلة الطبية باستخدام Agent"""
    start_time = time.time()
    
    if not initialization_status["is_initialized"]:
        raise HTTPException(status_code=503, detail=initialization_status.get("message", "التطبيق قيد الإعداد"))
    
    if not os.getenv('OPENROUTER_API_KEY'):
        raise HTTPException(status_code=500, detail="مفتاح OpenRouter API غير موجود")
    
    try:
        chat_history = getattr(request, 'chat_history', [])
        answer, sources_response = run_agentic_chat(
            question=request.question,
            user_type=request.user_type,
            chat_history=chat_history
        )
        
        total_time = time.time() - start_time
        
        return ChatResponse(
            answer=answer,
            sources=sources_response,
            processing_time=total_time,
            user_type=request.user_type
        )
    except Exception as e:
        logger.error(f"💥 خطأ غير متوقع: {str(e)}")
        raise HTTPException(status_code=500, detail=f"خطأ داخلي: {str(e)}")

@router.post("/suggest_medication_schedule", response_model=MedicationScheduleResponse)
async def suggest_medication_schedule(request: MedicationScheduleRequest):
    """اقتراح جدول مواعيد الأدوية"""
    start_time = time.time()
    
    if not initialization_status["is_initialized"]:
        raise HTTPException(status_code=503, detail="التطبيق قيد الإعداد")
    
    try:
        medications_list = "\n".join([f"• {med}" for med in request.medications])
        preferences_text = "\n".join([f"• {k}: {v}" for k,v in request.user_preferences.items()]) if request.user_preferences else "لا توجد تفضيلات إضافية"
        
        messages = [
            {
                "role": "system",
                "content": "أنت مساعد طبي ذكي متخصص في جدولة الأدوية.\nاقترح جدول مثالي مع شرح موجز."
            },
            {
                "role": "user",
                "content": f"وقت النوم: {request.sleep_time}\nوقت الاستيقاظ: {request.wake_up_time}\n\nالأدوية:\n{medications_list}\n\nتفضيلات:\n{preferences_text}"
            }
        ]
        
        response = requests.post(
            "https://openrouter.ai/api/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {os.getenv('OPENROUTER_API_KEY')}",
                "HTTP-Referer": "http://localhost:8000",
                "X-Title": "AFYA CARE - Scheduler",
            },
            json={
                "model": "openai/gpt-oss-120b:free",
                "messages": messages,
                "temperature": 0.4,
                "max_tokens": 1200,
                "top_p": 0.9,
            },
            timeout=45
        )
        
        if response.status_code != 200:
            raise HTTPException(status_code=500, detail=response.text[:200])
        
        response_data = response.json()
        ai_response = response_data["choices"][0]["message"]["content"]
        total_time = time.time() - start_time
        
        return MedicationScheduleResponse(
            suggested_schedule=ai_response,
            explanation="تم إنشاء الاقتراح بناءً على معلوماتك",
            processing_time=total_time
        )
    except Exception as e:
        logger.error(f"💥 خطأ غير متوقع: {str(e)}")
        raise HTTPException(status_code=500, detail=f"خطأ داخلي: {str(e)}")
