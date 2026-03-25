from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import os
import time
import logging
from dotenv import load_dotenv

# Import global state correctly
from core.state import embedding_manager, initialization_status, validate_environment
from core.pdf_processor import PDFProcessor
from rag.routes import router as rag_router

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

load_dotenv()

app = FastAPI(
    title="AFYA CARE - Medical RAG Chatbot",
    description="مساعد طبي ذكي يعتمد على الموسوعة الطبية باستخدام تقنية RAG",
    version="2.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(rag_router)

@app.on_event("startup")
async def startup_event():
    """تهيئة التطبيق عند البدء"""
    global initialization_status
    
    env_valid, env_message = validate_environment()
    if not env_valid:
        initialization_status["error"] = env_message
        logger.error(f"خطأ في إعدادات البيئة: {env_message}")
        return
    
    pdf_path = "data/Medical_book.pdf"
    db_filename = "database/medical_db"
    
    try:
        start_time = time.time()
        
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
            return
        
        processor.save_chunks("data/chunks_output.txt")
        
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
        initialization_status.update({
            "message": f"خطأ في التهيئة: {str(e)}",
            "error": str(e)
        })
        logger.error(f"❌ خطأ في التهيئة: {e}")

@app.get("/")
async def root():
    return {
        "message": "مرحباً في AFYA CARE - المساعد الطبي الذكي",
        "version": "2.0.0",
        "docs": "/docs",
        "status": "/status"
    }

@app.get("/status")
async def status():
    env_valid, env_message = validate_environment()
    status_info = {
        "initialized": initialization_status["is_initialized"],
        "message": initialization_status["message"],
        "environment_ok": env_valid,
        "environment_message": env_message,
        "total_documents": len(embedding_manager.documents) if embedding_manager.documents else 0,
    }
    if "error" in initialization_status and initialization_status["error"]:
        status_info["error"] = initialization_status["error"]
    return status_info

@app.get("/health")
async def health():
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
    if not os.path.exists("database/medical_db.index"):
        return {"error": "قاعدة البيانات غير موجودة"}
    try:
        embedding_manager.load("database/medical_db")
        return {"message": "تم إعادة تحميل قاعدة البيانات بنجاح", "documents": len(embedding_manager.documents)}
    except Exception as e:
        return {"error": str(e)}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True, log_level="info")