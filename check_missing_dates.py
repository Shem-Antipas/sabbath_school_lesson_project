import json
import os
from datetime import date, timedelta

INPUT_FILE = 'hb.json'

if not os.path.exists(INPUT_FILE):
    print(f"Error: {INPUT_FILE} not found.")
    exit()

with open(INPUT_FILE, 'r', encoding='utf-8') as f:
    readings = json.load(f)

# Collect found dates
found_dates = set()
for r in readings:
    d = date(2024, r['month'], r['day'])
    # Store standard format "January 1"
    found_dates.add(f"{d.strftime('%B')} {d.day}")

# Check 366 days (leap year covers everything)
start_date = date(2024, 1, 1)
end_date = date(2024, 12, 31)
curr = start_date
missing = []

print(f"Checking {len(readings)} readings...")

while curr <= end_date:
    check_str = f"{curr.strftime('%B')} {curr.day}"
    
    if check_str not in found_dates:
        # Ignore Feb 29 unless you know the book has it
        if not (curr.month == 2 and curr.day == 29):
            missing.append(check_str)
            
    curr += timedelta(days=1)

print("-" * 30)
if not missing:
    print("SUCCESS: All dates found!")
else:
    print(f"WARNING: Missing {len(missing)} dates.")
    print("Copy these into your RESCUE_PATCHES list:\n")
    for m in missing:
        print(f'    {{ "unique_text": "{m}", "month": "{m.split()[0]}", "day": "{m.split()[1]}", "title": "MISSING_TITLE" }},')
print("-" * 30)