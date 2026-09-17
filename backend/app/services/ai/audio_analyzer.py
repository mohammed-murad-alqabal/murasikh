import asyncio
import io

import librosa
import numpy as np


class AudioAnalyzer:
    def __init__(self):
        pass

    async def analyze_tone(self, file_bytes: bytes) -> dict:
        """
        تحليل نبرة الصوت واستخراج الحالة العاطفية باستخدام الميزات الصوتية
        """
        try:
            # تحميل الملف الصوتي في الذاكرة
            y, sr = await asyncio.to_thread(
                librosa.load, io.BytesIO(file_bytes), sr=22050
            )

            # استخراج الميزات الأساسية
            # 1. الطاقة/الشدة (Volume/Energy)
            rms = librosa.feature.rms(y=y)
            mean_rms = float(np.mean(rms))

            # 2. الحدة/التردد الأساسي (Pitch/Brightness)
            cent = librosa.feature.spectral_centroid(y=y, sr=sr)
            mean_cent = float(np.mean(cent))

            # 3. معدل تغير الإشارة (Harshness/ZCR)
            zcr = librosa.feature.zero_crossing_rate(y)
            mean_zcr = float(np.mean(zcr))

            # 4. سرعة الحديث (Tempo)
            tempo, _ = librosa.beat.beat_track(y=y, sr=sr)
            tempo = float(tempo[0]) if isinstance(tempo, np.ndarray) else float(tempo)

            # منطق تصنيف المشاعر المبني على النبرة
            emotion = "طبيعي"
            confidence = 0.7

            if mean_rms > 0.08 and mean_zcr > 0.1:
                emotion = "غضب"
                confidence = min(0.9, mean_rms * 10)
            elif mean_rms < 0.02 and tempo < 100:
                emotion = "حزن"
                confidence = 0.8
            elif tempo > 130 and mean_cent > 2000:
                emotion = "توتر"
                confidence = 0.75
            elif mean_rms < 0.03 and tempo > 110:
                emotion = "قلق"
                confidence = 0.7

            return {
                "emotion": emotion,
                "confidence": round(confidence, 2),
                "features": {
                    "energy": round(mean_rms, 4),
                    "pitch": round(mean_cent, 2),
                    "harshness": round(mean_zcr, 4),
                    "tempo": round(tempo, 2),
                },
            }
        except Exception as e:  # noqa: BLE001
            print(f"Audio analysis error: {e}")
            # Fallback
            return {"emotion": "طبيعي", "confidence": 0.5, "features": {}}
