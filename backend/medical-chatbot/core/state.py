from core.embeddings import EmbeddingManager
import os

embedding_manager = EmbeddingManager()
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
