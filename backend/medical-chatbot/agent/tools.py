from core.state import embedding_manager
from typing import List, Dict, Tuple

def execute_search_medicaldb(query: str) -> Tuple[str, List[Dict]]:
    """يبحث في قاعدة البيانات ويستخرج النصوص ومصادرها"""
    relevant_docs = embedding_manager.search(query, k=5)
    filtered_docs = [doc for doc in relevant_docs if doc['score'] < 1.8]
    
    if not filtered_docs:
        filtered_docs = relevant_docs[:2] # fallback
        
    context = "\n\n".join([f"[مصدر {i+1}]: {doc['text']}" for i, doc in enumerate(filtered_docs)])
    return context, filtered_docs

search_tool_schema = {
    "type": "function",
    "function": {
        "name": "search_medicaldb",
        "description": "استخدم هذه الأداة للبحث في الموسوعة الطبية لمرجع طبي أو للتحقق من الأعراض، الأمراض، أو الأدوية. يجب استخدامها عندما تحتاج لمعلومات دقيقة قبل الإجابة.",
        "parameters": {
            "type": "object",
            "properties": {
                "query": {
                    "type": "string",
                    "description": "مصطلح البحث، مثلاً 'أعراض السكري' أو 'علاج الصداع النصفى'"
                }
            },
            "required": ["query"]
        }
    }
}
