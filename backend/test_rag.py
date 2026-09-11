import asyncio
import json
import os
from app.api.v1.endpoints.recommend import analyze_and_recommend, UserInput

async def run_test():
    texts = [
        "أشعر ببعض القلق والتوتر بشأن امتحاني غداً، قلبي مقبوض.",
        "فقدت وظيفتي اليوم وأنا في غاية الحزن والأسى على رزقي."
    ]
    for t in texts:
        print(f"\n[نص المستخدم]: {t}")
        req = UserInput(text=t)
        res = await analyze_and_recommend(req)
        print("[رد مُرَسِّخ - RAG]:")
        print(json.dumps(res, ensure_ascii=False, indent=2))

if __name__ == "__main__":
    asyncio.run(run_test())
