import json
import hashlib
from pathlib import Path
import sys

DATA_DIR = Path(__file__).resolve().parents[1]
QURAN_FILE = DATA_DIR / "quran.json"
MANIFEST_FILE = DATA_DIR / "quran_manifest.json"

def main():
    if not MANIFEST_FILE.exists():
        print(f"Error: Manifest file missing at {MANIFEST_FILE}")
        sys.exit(1)
        
    with MANIFEST_FILE.open("r", encoding="utf-8") as f:
        manifest = json.load(f)
        
    expected_hash = manifest.get("checksum_sha256")
    
    if not expected_hash:
        print("Error: checksum_sha256 missing in manifest")
        sys.exit(1)
        
    with QURAN_FILE.open("rb") as f:
        actual_hash = hashlib.sha256(f.read()).hexdigest()
        
    if actual_hash != expected_hash:
        print(f"Error: Quran text hash mismatch! Expected {expected_hash}, got {actual_hash}")
        sys.exit(1)
        
    print("Quran Source Provenance Verified. Matches Manifest.")
    sys.exit(0)

if __name__ == "__main__":
    main()
