with open("backend/app/core/config.py", "r") as f:
    content = f.read()

import re
replacement = """    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        if self.ENVIRONMENT == "production":
            if (
                self.SECRET_KEY == "super-secret-key-change-in-production"
                or len(self.SECRET_KEY) < 32
            ):
                raise ValueError(
                    "SECRET_KEY must be set to at least 32 characters in production"
                )
            if self.POSTGRES_PASSWORD == "postgres":
                raise ValueError("POSTGRES_PASSWORD must be changed in production")

            # P3: Mandatory production CORS without localhost
            if not self.CORS_ORIGINS:
                raise ValueError("CORS_ORIGINS must be explicitly set in production")
            cors_list = [o.strip() for o in self.CORS_ORIGINS.split(",") if o.strip()]
            for origin in cors_list:
                if "localhost" in origin or "127.0.0.1" in origin:
                    raise ValueError(f"CORS_ORIGINS cannot contain localhost in production: {origin}")"""

content = re.sub(r'    def __init__\(self, \*\*kwargs\):.*?raise ValueError\("POSTGRES_PASSWORD must be changed in production"\)', replacement, content, flags=re.DOTALL)

with open("backend/app/core/config.py", "w") as f:
    f.write(content)
