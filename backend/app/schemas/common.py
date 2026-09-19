from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

class UserContextSchema(BaseModel):
    model_config = ConfigDict(extra="forbid")

    age: int | None = Field(None, ge=13, le=120, description="عمر المستخدم")
    gender: Literal["male", "female"] | None = Field(
        None, description="جنس المستخدم"
    )
    facial_emotion: str | None = Field(
        None, min_length=1, max_length=50, description="ملامح الوجه"
    )
    biometric_stress: bool | None = Field(None, description="مؤشرات التوتر الحيوي")
    source: str | None = Field(None, min_length=1, max_length=50, description="مصدر الإشارة")
