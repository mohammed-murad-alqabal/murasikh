from pydantic import BaseModel, Field, conint, constr
from typing import Optional, Literal

class UserContextSchema(BaseModel):
    age: Optional[conint(ge=7, le=120)] = Field(None, description="عمر المستخدم (اختياري)")
    gender: Optional[Literal["male", "female"]] = Field(None, description="جنس المستخدم (اختياري)")
    facial_emotion: Optional[constr(max_length=50)] = Field(None, description="ملامح الوجه (اختياري)")
    biometric_stress: Optional[bool] = Field(None, description="مؤشرات التوتر الحيوي (اختياري)")
    source: Optional[constr(max_length=50)] = Field(None, description="مصدر الإشارة (اختياري)")

    class Config:
        extra = "forbid"
