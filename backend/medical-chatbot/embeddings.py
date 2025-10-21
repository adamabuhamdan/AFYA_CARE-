from sentence_transformers import SentenceTransformer
import faiss
import numpy as np
import pickle
import os
from typing import List, Dict

class EmbeddingManager:
    def __init__(self, model_name: str = 'all-MiniLM-L6-v2'):
        """
        إدارة التضمينات والبحث
        يمكن استخدام نماذج عربية: 'BAAI/bge-small-ar'
        """
        print(f"جاري تحميل النموذج: {model_name}")
        self.model = SentenceTransformer(model_name)
        self.index = None
        self.documents = []
        self.embeddings = None
    
    def add_documents(self, documents: List[str]):
        """إضافة المستندات وإنشاء embeddings"""
        self.documents = documents
        print(f"جاري إنشاء embeddings لـ {len(documents)} مستند...")
        
        # إنشاء embeddings بدفعات لتوفير الذاكرة
        batch_size = 32
        all_embeddings = []
        
        for i in range(0, len(documents), batch_size):
            batch = documents[i:i + batch_size]
            embeddings = self.model.encode(batch, convert_to_numpy=True)
            all_embeddings.extend(embeddings)
            
            if (i + batch_size) % 100 == 0:
                print(f"تم معالجة {i + batch_size} مستند...")
        
        self.embeddings = np.array(all_embeddings).astype('float32')
        
        # إنشاء FAISS index
        dimension = self.embeddings.shape[1]
        self.index = faiss.IndexFlatL2(dimension)
        self.index.add(self.embeddings)
        
        print(f"تم إنشاء index بـ {self.index.ntotal} عنصر")
    
    def search(self, query: str, k: int = 5) -> List[Dict]:
        """البحث عن أقرب k مستندات"""
        query_embedding = self.model.encode([query], convert_to_numpy=True)
        distances, indices = self.index.search(query_embedding.astype('float32'), k)
        
        results = []
        for idx, i in enumerate(indices[0]):
            results.append({
                "text": self.documents[i],
                "score": float(distances[0][idx]),
                "index": int(i)
            })
        
        return results
    
    def save(self, filename: str = "medical_db"):
        """حفظ الـ index والمستندات"""
        # حفظ FAISS index
        faiss.write_index(self.index, f"{filename}.index")
        
        # حفظ المستندات
        with open(f"{filename}_docs.pkl", 'wb') as f:
            pickle.dump(self.documents, f)
        
        print(f"تم حفظ قاعدة البيانات في {filename}")
    
    def load(self, filename: str = "medical_db"):
        """تحميل الـ index والمستندات المحفوظة"""
        self.index = faiss.read_index(f"{filename}.index")
        
        with open(f"{filename}_docs.pkl", 'rb') as f:
            self.documents = pickle.load(f)
        
        print(f"تم تحميل قاعدة البيانات من {filename}")