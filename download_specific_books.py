import pdfplumber
import re
import json
import os
from datetime import date, timedelta

# --- CONFIGURATION ---
JSON_DIR = "json_output"
PDF_DIR = "pdf_downloads"

# Focused list of books that still need fixing
BOOKS_TO_PROCESS = [
    {"code": "BLJ", "title": "To Be Like Jesus"},
    {"code": "HP",  "title": "In Heavenly Places"},
    {"code": "LHU", "title": "Lift Him Up"},
    {"code": "OFC", "title": "Our Father Cares"},
    {"code": "RC",  "title": "Reflecting Christ"},
    {"code": "YRP", "title": "Ye Shall Receive Power"},
]

def get_missing_dates(json_path):
    """Finds which dates are still missing from the JSON file."""
    try:
        with open(json_path, 'r', encoding='utf-8') as f:
            readings = json.load(f)
    except:
        readings = []

    found_keys = set()
    for r in readings:
        found_keys.add(f"{r['month']}-{r['day']}")

    missing = []
    # Check 2024 (Leap Year) to be safe
    start = date(2024, 1, 1)
    end = date(2024, 12, 31)
    curr = start
    
    while curr <= end:
        key = f"{curr.month}-{curr.day}"
        if key not in found_keys:
            # We ignore Feb 29 for standard verification unless it's explicitly sought
            if not (curr.month == 2 and curr.day == 29):
                missing.append({
                    "month": curr.month, 
                    "day": curr.day,
                    "month_name": curr.strftime("%B"), # Full name "January"
                    "short_name": curr.strftime("%b")  # Short name "Jan"
                })
        curr += timedelta(days=1)
    
    return missing, readings

def clean_title(raw_text):
    if not raw_text: return "Devotional Reading"
    # Remove bracketed numbers [12], page numbers 123, dots ...
    text = re.sub(r'\[\d+\]', '', raw_text)
    text = re.sub(r'\d+$', '', text) # Remove trailing numbers
    text = re.sub(r'[\.\s]+$', '', text) # Remove trailing dots/spaces
    text = re.sub(r',\s*$', '', text) # Remove trailing comma
    return text.strip()

def extract_fuzzy_match(page_text, target):
    """
    Aggressively searches for the date in the page text.
    Handles: "JANUARY 1", "January 1", "Jan 1", "Jan. 1"
    """
    if not page_text: return None
    
    lines = [l.strip() for l in page_text.split('\n') if l.strip()]
    if not lines: return None

    # We only scan the top 15 lines (headers shouldn't be lower)
    header_zone = lines[:15]
    
    found_idx = -1
    
    # 1. Prepare search variations
    target_day = str(target['day'])
    variations = [
        target['month_name'].lower(), # "january"
        target['short_name'].lower() + ".", # "jan."
        target['short_name'].lower() + " "  # "jan "
    ]

    for i, line in enumerate(header_zone):
        line_lower = line.lower()
        
        # Check if line contains Month AND Day
        # AND check that the day isn't part of a year (like 1991) or page number
        if target_day in line_lower:
            for v in variations:
                if v in line_lower:
                    # Found a candidate line!
                    # Verify it's not a Table of Contents line (dots ...)
                    if "..." in line or ". . ." in line: continue
                    
                    found_idx = i
                    break
        if found_idx != -1: break
    
    if found_idx != -1:
        # We found the header line!
        header_line = lines[found_idx]
        
        # Attempt to extract title from the header line
        # Remove the date parts to leave the title
        temp_title = header_line
        for v in [target['month_name'], target['short_name']]:
            temp_title = re.sub(v, '', temp_title, flags=re.IGNORECASE)
        temp_title = temp_title.replace(target_day, "").replace(",", "").strip()
        
        title = clean_title(temp_title)
        if len(title) < 3: 
            # If title is empty, maybe the PREVIOUS line was the title?
            if found_idx > 0:
                prev_line = lines[found_idx - 1]
                if not re.match(r"^\d+$", prev_line): # Ensure it's not a page number
                    title = clean_title(prev_line)
            else:
                title = "Devotional Reading"

        # Content is everything after the header line
        content_lines = lines[found_idx+1:]
        
        # Helper to extract verse reference from the first few lines of content
        verse = ""
        verse_ref = ""
        # Regex for verse ref like "John 3:16" or "1 Peter 5:7"
        ref_regex = re.compile(r".*?(\d?\s?[A-Za-z]+\s\d+:\d+(?:-\d+)?)\.?$")
        
        for k in range(min(len(content_lines), 10)):
            line = content_lines[k]
            match = ref_regex.match(line)
            if match:
                verse = " ".join(content_lines[:k+1])
                verse_ref = match.group(1)
                content_lines = content_lines[k+1:]
                break
        
        return {
            "id": "FIXED_ID", # Will be set by caller
            "month": target['month'],
            "day": target['day'],
            "title": title,
            "verse": verse,
            "verse_ref": verse_ref,
            "content": "\n".join(content_lines)
        }

    return None

def finalize_books():
    for book in BOOKS_TO_PROCESS:
        code = book['code']
        json_file = os.path.join(JSON_DIR, f"{code.lower()}.json")
        pdf_file = os.path.join(PDF_DIR, f"en_{code}.pdf")
        
        if not os.path.exists(json_file):
            print(f"[Skip] {code} JSON not found.")
            continue
        if not os.path.exists(pdf_file):
            print(f"[Skip] {code} PDF not found.")
            continue

        missing, current_readings = get_missing_dates(json_file)
        
        if not missing:
            print(f"[OK] {code} is already 100% complete.")
            continue

        print(f"\n[Fixing] {code} - Hunting for {len(missing)} stubborn dates...")
        
        recovered_count = 0
        
        # Open PDF once
        with pdfplumber.open(pdf_file) as pdf:
            # We iterate pages. For optimization, if we have many missing, 
            # we just check every page against the missing set.
            for page_num, page in enumerate(pdf.pages):
                text = page.extract_text()
                if not text: continue
                
                # Check this page against ALL remaining missing items
                # Copy list to allow removal during iteration
                for m in list(missing):
                    result = extract_fuzzy_match(text, m)
                    if result:
                        # Found it!
                        result['id'] = f"{code.lower()}_{m['month']:02d}_{m['day']:02d}"
                        current_readings.append(result)
                        missing.remove(m) # Don't look for this one anymore
                        recovered_count += 1
                        print(f"  + Found: {m['month_name']} {m['day']}")
                        break # Move to next page (assume 1 reading per page)
                
                if not missing: break # Done with this book!

        # Save updates
        if recovered_count > 0:
            print(f"  -> Saved {recovered_count} new entries to {code.lower()}.json")
            # Sort by date
            current_readings.sort(key=lambda x: (x['month'], x['day']))
            with open(json_file, 'w', encoding='utf-8') as f:
                json.dump(current_readings, f, indent=4, ensure_ascii=False)
        
        if missing:
            print(f"  [Warning] {code} still missing {len(missing)} days: {[f'{m['month']}/{m['day']}' for m in missing]}")

if __name__ == "__main__":
    finalize_books()