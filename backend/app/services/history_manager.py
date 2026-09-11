import json
import os
from datetime import datetime
from typing import List, Dict

class HistoryManager:
    def __init__(self, filepath="data/history.json"):
        self.filepath = filepath
        os.makedirs(os.path.dirname(self.filepath), exist_ok=True)
        if not os.path.exists(self.filepath):
            with open(self.filepath, 'w', encoding='utf-8') as f:
                json.dump([], f)

    def add_record(self, input_text: str, emotion: str, message: str, source: str = None, tafsir: str = None):
        if emotion == "طبيعي":
            return
            
        try:
            with open(self.filepath, 'r', encoding='utf-8') as f:
                history = json.load(f)
        except:
            history = []

        record = {
            "id": str(datetime.now().timestamp()),
            "timestamp": datetime.now().isoformat(),
            "input_text": input_text,
            "recommendation": {
                "emotion": emotion,
                "message": message,
                "source": source,
                "tafsir": tafsir,
                "confidence": 1.0,
                "tier": "moderate"
            },
            "feedback": 0
        }
        
        history.insert(0, record) # Prepend
        
        with open(self.filepath, 'w', encoding='utf-8') as f:
            json.dump(history, f, ensure_ascii=False, indent=2)

    def update_feedback(self, record_id: str, feedback: int):
        try:
            with open(self.filepath, 'r', encoding='utf-8') as f:
                history = json.load(f)
                
            for item in history:
                if item["id"] == record_id:
                    item["feedback"] = feedback
                    break
                    
            with open(self.filepath, 'w', encoding='utf-8') as f:
                json.dump(history, f, ensure_ascii=False, indent=2)
            return True
        except:
            return False

    def get_history(self) -> List[Dict]:
        try:
            with open(self.filepath, 'r', encoding='utf-8') as f:
                return json.load(f)
        except:
            return []
            
    def get_user_context(self) -> str:
        history = self.get_history()
        liked = set([item["recommendation"]["emotion"] for item in history if item.get("feedback") == 1][:3])
        disliked = set([item["recommendation"]["emotion"] for item in history if item.get("feedback") == -1][:3])
        
        if not liked and not disliked:
            return ""
            
        context = ""
        if liked:
            context += f"User finds guidance helpful for: {', '.join(liked)}. "
        if disliked:
            context += f"User disliked previous guidance for: {', '.join(disliked)}."
        return context
