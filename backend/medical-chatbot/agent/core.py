import os
import requests
import json
import logging
import time
from typing import List, Dict, Tuple
from agent.tools import execute_search_medicaldb, search_tool_schema
import re

logger = logging.getLogger(__name__)

def parse_sources(filtered_docs: List[Dict]) -> List[Dict]:
    sources_response = []
    # تجنب تكرار المصادر
    seen_texts = set()
    for doc in filtered_docs:
        source_text = doc["text"]
        if source_text in seen_texts:
            continue
        seen_texts.add(source_text)
        
        page_num = None
        if "صفحة" in source_text:
            page_match = re.search(r'صفحة\s+(\d+)', source_text)
            if page_match:
                page_num = int(page_match.group(1))
        
        sources_response.append({
            "text": source_text[:250] + "...",
            "relevance_score": float(doc["score"]),
            "confidence": 1/(1+doc["score"]),
            "page_number": page_num
        })
    return sources_response

def run_agentic_chat(question: str, user_type: str, chat_history: List[Dict]) -> Tuple[str, List[Dict]]:
    user_context = "المستخدم حالياً تحت العلاج الطبي" if user_type == "treatment" else "المستخدم يهتم بالوقاية"
    
    system_content = f"""أنت طبيب ذكي ومساعد بديهي في تطبيق AFYA CARE (Agentic Chatbot).
👤 **معلومات المستخدم**: {user_context}

🎯 **المهمة**: 
أنت الآن في محادثة تشخيصية واستشارية مستمرة مع المريض. هدفك هو فهم حالته بدقة خطوة بخطوة.
لديك أداة للبحث في الموسوعة الطبية `search_medicaldb`. يجب عليك استدعاء الأداة إذا احتجت للبحث عن أعراض، أسباب، أو إرشادات طبية قبل الإجابة. لا تعتمد على ما تحفظه، بل ابحث عند الضرورة.

📝 **تعليمات المحادثة**:
1. إذا كانت المعلومات غير كافية للرد أو تحتاج للبحث في الموسوعة الطبية، قم باستدعاء الدالة `search_medicaldb` مع الكلمات المفتاحية المناسبة.
2. بعد المعرفة والبحث، أجب بشكل مختصر ومفيد بناءً على المصادر وسياق المحادثة.
3. **يجب دائماً** أن تنهي إجابتك بسؤال ذكي واحد (سؤال واحد فقط) لجمع المزيد من التفاصيل (مثل الأعراض المرافقة، مدة الألم، التاريخ الطبي، إلخ).
4. استمر في هذه الخطوات مع المريض وعندما تتضح الصورة، قدم نصيحة توجيهية نهائية واطلب منه مراجعة الطبيب المختص.
5. لا تقدم تشخيصات نهائية ولا تصف أدوية أو جرعات محددة. أجب باللغة العربية الفصحى."""

    messages = [{"role": "system", "content": system_content}]
    
    if chat_history:
        for msg in chat_history[-6:]:
            messages.append({"role": msg.get("role", "user"), "content": msg.get("content", "")})
            
    messages.append({
        "role": "user",
        "content": question
    })

    api_key = os.getenv('OPENROUTER_API_KEY')
    headers = {
        "Authorization": f"Bearer {api_key}",
        "HTTP-Referer": "http://localhost:8000",
        "X-Title": "AFYA CARE - Agent"
    }

    used_docs = []
    
    def call_llm(current_messages):
        payload = {
            "model": "openai/gpt-oss-120b:free",
            "messages": current_messages,
            "tools": [search_tool_schema],
            "tool_choice": "auto",
            "temperature": 0.3,
            "max_tokens": 1000
        }
        resp = requests.post("https://openrouter.ai/api/v1/chat/completions", headers=headers, json=payload, timeout=60)
        if resp.status_code != 200:
            raise Exception(f"API Error: {resp.text[:200]}")
        return resp.json()['choices'][0]['message']

    logger.info("🤖 Agent is thinking...")
    message = call_llm(messages)
    
    # Check if tool is called
    if message.get("tool_calls"):
        messages.append(message) # Add assistant tool call
        for tool_call in message["tool_calls"]:
            if tool_call["function"]["name"] == "search_medicaldb":
                try:
                    args = json.loads(tool_call["function"]["arguments"])
                    query = args.get("query", question)
                except:
                    query = question
                
                logger.info(f"🔍 Agent executed tool search_medicaldb with query: {query}")
                context, filtered_docs = execute_search_medicaldb(query)
                used_docs.extend(filtered_docs)
                
                messages.append({
                    "role": "tool",
                    "tool_call_id": tool_call["id"],
                    "name": tool_call["function"]["name"],
                    "content": context
                })
        
        # Second call to get final answer
        logger.info("🧠 Agent is summarizing tool results...")
        message = call_llm(messages)
        answer = message.get("content", "")
    else:
        answer = message.get("content", "")

    sources = parse_sources(used_docs)
    return answer, sources
