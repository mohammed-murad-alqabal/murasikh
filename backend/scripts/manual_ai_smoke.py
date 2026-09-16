"""Manual smoke check for the conversational agent.

This is intentionally not named ``test_*.py`` so pytest does not collect it.
Run from ``backend/`` with ``python scripts/manual_ai_smoke.py``.
"""

import asyncio
import json

from app.services.ai.conversational_agent import ConversationalAgent


async def main() -> None:
    agent = ConversationalAgent()
    for text in (
        "أنا غاضب جداً، مديري يظلمني ولم أعد أحتمل!",
        "أشعر ببعض القلق بشأن امتحاني غداً، لكنني متفائل.",
    ):
        result = await agent.analyze(text)
        print(f"\n[نص المستخدم]: {text}")
        print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    asyncio.run(main())
