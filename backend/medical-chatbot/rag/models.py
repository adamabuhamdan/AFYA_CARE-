from pydantic import BaseModel
from typing import List, Dict

class ChatRequest(BaseModel):
    question: str
    user_type: str = "general"
    questionnaire_data: dict = None
    chat_history: List[Dict[str, str]] = []

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
    warning_level: str
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
