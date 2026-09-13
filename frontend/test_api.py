import requests
import json
import time

url = "http://127.0.0.1:8000/api/v1/analyze"
headers = {"Content-Type": "application/json"}
data = {"text": "أنا غاضب جداً، أحدهم شتمني في الطريق"}

print("Testing API...")
response = requests.post(url, headers=headers, json=data)
try:
    print(json.dumps(response.json(), indent=2, ensure_ascii=False))
except Exception as e:
    print(response.text)
