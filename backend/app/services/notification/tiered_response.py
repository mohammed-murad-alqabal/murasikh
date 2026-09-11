from typing import Dict
import random

class TieredResponse:
    """
    نظام الاستجابة المدرجة:
    الهدف: عدم إزعاج المستخدم إذا كان في ذروة الغضب أو التوتر.
    """
    TIERS = {
        'minimal': {'description': 'تنبيه رمزي مهدئ وغير مزعج', 'examples': ['🌸', '🌿', '🕊️', 'نفس عميق... 🤍']},
        'moderate': {'description': 'نص قرآني قصير أو حديث'},
        'full': {'description': 'النص كاملاً مع التفسير'}
    }
    
    def determine_tier(self, emotion: str, confidence: float) -> str:
        # إذا كان الانفعال السلبي شديداً جداً (أكبر من 85%)
        if confidence >= 0.85 and emotion in ['غضب', 'توتر', 'يأس']:
            return 'minimal'
        
        # إذا كان الانفعال متوسطاً (أكبر من 60%)
        if confidence >= 0.60:
            return 'moderate'
            
        # الحالة الطبيعية أو الانفعال الخفيف
        return 'full'
        
    def get_minimal_response(self, emotion: str) -> Dict:
        """إرجاع رد رمزي لتجنب الاستفزاز"""
        symbols = self.TIERS['minimal']['examples']
        return {
            'emotion': emotion,
            'tier': 'minimal',
            'message': random.choice(symbols),
            'action': 'تم تأجيل التفسير المفصل لحين هدوئك.'
        }
