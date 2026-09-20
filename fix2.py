import re

with open('backend/app/api/v1/endpoints/home.py', 'r') as f:
    content = f.read()

old = """                        except:
                            pass"""
new = """                        except (
                            ValueError,
                            TypeError,
                            dateutil.parser.ParserError,
                        ) as e:
                            logger.warning(f"Failed to parse timestamp in history: {e}")"""
content = content.replace(old, new)
with open('backend/app/api/v1/endpoints/home.py', 'w') as f:
    f.write(content)
