import json
import os
import glob
from datetime import date, timedelta

# Folder where your JSONs are
JSON_DIR = "json_output"

def check_file(filepath):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            readings = json.load(f)
    except:
        return [] # Skip broken files
    
    found_dates = set()
    for r in readings:
        # We use a leap year (2024) to check for Feb 29 too
        d = date(2024, r['month'], r['day'])
        found_dates.add(f"{d.strftime('%B')} {d.day}")
    
    # Check full year
    start = date(2024, 1, 1)
    end = date(2024, 12, 31)
    curr = start
    missing = []
    
    while curr <= end:
        check = f"{curr.strftime('%B')} {curr.day}"
        if check not in found_dates:
            # Only flag Feb 29 if the book usually has it, 
            # but for now, we ignore Feb 29 to reduce noise unless it's a leap year book
            if not (curr.month == 2 and curr.day == 29):
                missing.append(check)
        curr += timedelta(days=1)
        
    return missing

print("--- MISSING DATES REPORT ---")
files = glob.glob(os.path.join(JSON_DIR, "*.json"))

if not files:
    print(f"No JSON files found in {JSON_DIR}")

for f in files:
    filename = os.path.basename(f)
    book_code = filename.split('.')[0].upper()
    
    # User asked to ignore Maranatha
    if book_code == "MAR": 
        continue

    missing = check_file(f)
    
    if missing:
        print(f"\nBOOK: {book_code} ({len(missing)} missing)")
        print("Copy these lines into 'BOOK_PATCHES' in the next script:")
        for m in missing:
            parts = m.split()
            # We put a placeholder title. You might need to check the PDF for the real one later.
            print(f'    {{ "book": "{book_code}", "text": "{m}", "month": "{parts[0]}", "day": "{parts[1]}", "title": "REPLACE_TITLE" }},')
    else:
        print(f"OK: {book_code} is complete!")