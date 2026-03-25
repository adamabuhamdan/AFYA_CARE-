import pdfplumber
from typing import List
import os

class PDFProcessor:
    def __init__(self, pdf_path: str, chunk_size: int = 500):
        """
        معالج ملفات PDF الطبية
        chunk_size: عدد الأحرف في كل جزء (chunk)
        """
        self.pdf_path = pdf_path
        self.chunk_size = chunk_size
        self.chunks = []
    
    def extract_text(self) -> str:
        """استخراج كل النص من ملف PDF"""
        text = ""
        try:
            with pdfplumber.open(self.pdf_path) as pdf:
                print(f"عدد الصفحات: {len(pdf.pages)}")
                for page_num, page in enumerate(pdf.pages):
                    page_text = page.extract_text()
                    if page_text:
                        text += f"\n--- صفحة {page_num + 1} ---\n"
                        text += page_text
                    
                    # طباعة التقدم كل 50 صفحة
                    if (page_num + 1) % 50 == 0:
                        print(f"تم معالجة {page_num + 1} صفحة...")
        except Exception as e:
            print(f"خطأ في قراءة PDF: {e}")
            return ""
        
        return text
    
    def split_into_chunks(self, text: str) -> List[str]:
        """تقسيم النص إلى أجزاء صغيرة مع الحفاظ على السياق"""
        chunks = []
        sentences = text.split('.')
        
        current_chunk = ""
        for sentence in sentences:
            if len(current_chunk) + len(sentence) < self.chunk_size:
                current_chunk += sentence + "."
            else:
                if current_chunk:
                    chunks.append(current_chunk.strip())
                current_chunk = sentence + "."
        
        if current_chunk:
            chunks.append(current_chunk.strip())
        
        return chunks
    
    def process(self) -> List[str]:
        """معالجة ملف PDF كاملاً"""
        print("جاري استخراج النص من PDF...")
        text = self.extract_text()
        
        print("جاري تقسيم النص إلى أجزاء...")
        self.chunks = self.split_into_chunks(text)
        
        print(f"تم إنشاء {len(self.chunks)} جزء من النص")
        return self.chunks
    
    def save_chunks(self, output_file: str = "chunks.txt"):
        """حفظ الأجزاء في ملف للمراجعة"""
        with open(output_file, 'w', encoding='utf-8') as f:
            for i, chunk in enumerate(self.chunks):
                f.write(f"--- Chunk {i+1} ---\n")
                f.write(chunk)
                f.write("\n\n")
        print(f"تم حفظ الأجزاء في {output_file}")