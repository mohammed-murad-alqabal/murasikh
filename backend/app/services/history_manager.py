import os
import sqlite3
from datetime import datetime


class HistoryManager:
    def __init__(self, filepath="data/history.db"):
        self.filepath = filepath
        os.makedirs(os.path.dirname(self.filepath), exist_ok=True)
        self._init_db()

    def _init_db(self):
        with sqlite3.connect(self.filepath) as conn:
            cursor = conn.cursor()
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS history (
                    id TEXT PRIMARY KEY,
                    timestamp TEXT,
                    input_text TEXT,
                    emotion TEXT,
                    message TEXT,
                    source TEXT,
                    tafsir TEXT,
                    confidence REAL,
                    tier TEXT,
                    feedback INTEGER
                )
            ''')
            conn.commit()

    def add_record(self, input_text: str, emotion: str, message: str, source: str = None, tafsir: str = None):
        record_id = str(datetime.now().timestamp())
        timestamp = datetime.now().isoformat()
        confidence = 1.0
        tier = "moderate"
        feedback = 0

        with sqlite3.connect(self.filepath) as conn:
            cursor = conn.cursor()
            cursor.execute('''
                INSERT INTO history (id, timestamp, input_text, emotion, message, source, tafsir, confidence, tier, feedback)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (record_id, timestamp, input_text, emotion, message, source, tafsir, confidence, tier, feedback))
            conn.commit()

    def update_feedback(self, record_id: str, feedback: int):
        try:
            with sqlite3.connect(self.filepath) as conn:
                cursor = conn.cursor()
                cursor.execute('UPDATE history SET feedback = ? WHERE id = ?', (feedback, record_id))
                conn.commit()
                return cursor.rowcount > 0
        except Exception:
            return False

    def clear_history(self) -> bool:
        try:
            with sqlite3.connect(self.filepath) as conn:
                cursor = conn.cursor()
                cursor.execute('DELETE FROM history')
                conn.commit()
            return True
        except Exception:
            return False

    def get_history(self) -> list[dict]:
        try:
            with sqlite3.connect(self.filepath) as conn:
                conn.row_factory = sqlite3.Row
                cursor = conn.cursor()
                cursor.execute('SELECT * FROM history ORDER BY timestamp DESC')
                rows = cursor.fetchall()

            history = []
            for row in rows:
                record = {
                    "id": row["id"],
                    "timestamp": row["timestamp"],
                    "input_text": row["input_text"],
                    "recommendation": {
                        "emotion": row["emotion"],
                        "message": row["message"],
                        "source": row["source"],
                        "tafsir": row["tafsir"],
                        "confidence": row["confidence"],
                        "tier": row["tier"]
                    },
                    "feedback": row["feedback"]
                }
                history.append(record)
            return history
        except Exception:
            return []
            
    def get_user_context(self) -> str:
        try:
            with sqlite3.connect(self.filepath) as conn:
                conn.row_factory = sqlite3.Row
                cursor = conn.cursor()
                cursor.execute('SELECT emotion, feedback FROM history WHERE feedback != 0 ORDER BY timestamp DESC')
                rows = cursor.fetchall()
                
                liked = set()
                disliked = set()
                
                for row in rows:
                    if row["feedback"] == 1 and len(liked) < 3:
                        liked.add(row["emotion"])
                    elif row["feedback"] == -1 and len(disliked) < 3:
                        disliked.add(row["emotion"])
                
                if not liked and not disliked:
                    return ""
                    
                context = ""
                if liked:
                    context += f"User finds guidance helpful for: {', '.join(liked)}. "
                if disliked:
                    context += f"User disliked previous guidance for: {', '.join(disliked)}."
                return context
        except Exception:
            return ""
