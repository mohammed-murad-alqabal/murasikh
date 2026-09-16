import os
import sys

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.services.ai.embeddings import EmbeddingService


def seed_database():
    print("بدء تهيئة قاعدة المعرفة الشرعية (MVP Curated Data)...")
    service = EmbeddingService()
    
    # بيانات أولية منتقاة بعناية للحالات العاطفية الأساسية
    knowledge_base = [
        {
            "id": "verse_1",
            "text": "وَالْكَاظِمِينَ الْغَيْظَ وَالْعَافِينَ عَنِ النَّاسِ ۗ وَاللَّهُ يُحِبُّ الْمُحْسِنِينَ",
            "metadata": {"type": "verse", "emotion": "غضب", "source": "سورة آل عمران: 134", "tafsir": "الذين يمسكون ما في أنفسهم من الغضب، ويعفون عمن أساء إليهم."}
        },
        {
            "id": "hadith_1",
            "text": "لَيْسَ الشَّدِيدُ بِالصُّرَعَةِ، إِنَّمَا الشَّدِيدُ الَّذِي يَمْلِكُ نَفْسَهُ عِنْدَ الْغَضَبِ",
            "metadata": {"type": "hadith", "emotion": "غضب", "source": "صحيح البخاري", "tafsir": "القوة الحقيقية ليست في الصراع البدني، بل في السيطرة على النفس عند الغضب."}
        },
        {
            "id": "verse_2",
            "text": "وَبَشِّرِ الصَّابِرِينَ * الَّذِينَ إِذَا أَصَابَتْهُمْ مُصِيبَةٌ قَالُوا إِنَّا لِلَّهِ وَإِنَّا إِلَيْهِ رَاجِعُونَ",
            "metadata": {"type": "verse", "emotion": "حزن", "source": "سورة البقرة: 155-156", "tafsir": "بشارة عظيمة لمن يصبر على الحزن والمصيبة محتسباً الأجر من الله."}
        },
        {
            "id": "verse_3",
            "text": "أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ",
            "metadata": {"type": "verse", "emotion": "قلق", "source": "سورة الرعد: 28", "tafsir": "القلوب تسكن وتستريح بذكر الله والتوكل عليه في أوقات التوتر والقلق."}
        },
        {
            "id": "verse_4",
            "text": "لَا تَحْزَنْ إِنَّ اللَّهَ مَعَنَا",
            "metadata": {"type": "verse", "emotion": "يأس", "source": "سورة التوبة: 40", "tafsir": "لا تيأس ولا تحزن، فإن الله يحفظنا ويرعانا في أشد الأوقات ضيقاً."}
        }
    ]
    
    for item in knowledge_base:
        print(f"جاري إضافة: {item['text'][:40]}...")
        service.store_document(
            doc_id=item["id"],
            text=item["text"],
            metadata=item["metadata"]
        )
        
    print("✅ تم حفظ الآيات والأحاديث بنجاح في قاعدة بيانات ChromaDB (Vector DB).")

if __name__ == "__main__":
    seed_database()
