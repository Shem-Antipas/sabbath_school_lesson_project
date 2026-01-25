import pdfplumber
import json
import os
import re

# --- CONFIGURATION ---
JSON_DIR = "json_output"
PDF_DIR = "pdf_downloads"

# The specific stubborn dates we identified from your logs
TARGETS = [
    {"code": "OFC", "month": 1, "day": 11},
    {"code": "OFC", "month": 2, "day": 29},
    {"code": "OHC", "month": 9, "day": 29},
    {"code": "BLJ", "month": 2, "day": 17},
    {"code": "BLJ", "month": 2, "day": 25},
    {"code": "YRP", "month": 7, "day": 28},
    {"code": "YRP", "month": 12, "day": 21},
]

def clean_title(raw_text):
    if not raw_text: return "Devotional Reading"
    text = re.sub(r'\[\d+\]', '', raw_text)
    text = re.sub(r'\d+$', '', text) 
    text = re.sub(r'[\.\s]+$', '', text)
    text = re.sub(r',\s*$', '', text) 
    return text.strip()

def extract_surgical(page_text, month_int, day_int):
    """
    Tries multiple 'dirty' tricks to find the date in messy PDF text.
    """
    if len(page_text) < 500: return None # Ignore TOC/Empty pages
    
    lines = [l.strip() for l in page_text.split('\n') if l.strip()]
    if not lines: return None

    # Maps
    months = ["", "January", "February", "March", "April", "May", "June", 
              "July", "August", "September", "October", "November", "December"]
    month_name = months[month_int]
    day_str = str(day_int)
    
    header_idx = -1
    found_strategy = ""

    # Check top 15 lines
    for i in range(min(len(lines), 15)):
        line = lines[i]
        line_clean = line.replace(" ", "").lower() # squashed version
        target_clean = (month_name + day_str).lower()
        
        # Strategy 1: Squashed Match (e.g. "February17" matching "February 17")
        if target_clean in line_clean:
            # Verify it's not just a reference in the text
            if len(line) < 150: 
                header_idx = i
                found_strategy = "Squashed"
                break
        
        # Strategy 2: Split Line Match (Month on line i, Day on line i+1)
        if month_name in line and i + 1 < len(lines):
            next_line = lines[i+1]
            # Check if next line starts with the day number
            if next_line.strip().startswith(day_str):
                 # Ensure it's the number alone or followed by text, not 290 or something
                if re.match(rf"^{day_str}\b", next_line):
                    header_idx = i # Title is usually the Month line or above
                    found_strategy = "Split"
                    break

    if header_idx != -1:
        # We found it!
        # Extract Title: Try to grab text from the header line or previous line
        raw_header = lines[header_idx]
        if found_strategy == "Split":
            # If split, title is likely on the line WITH the month
            raw_header = lines[header_idx]
        
        # Clean title logic
        temp_title = raw_header.replace(month_name, "").replace(day_str, "").replace(",", "").strip()
        title = clean_title(temp_title)
        
        # If title is empty, check previous line
        if len(title) < 3 and header_idx > 0:
             if not re.match(r"^\d+$", lines[header_idx-1]):
                title = clean_title(lines[header_idx-1])

        if len(title) < 3: title = "Devotional Reading"

        # Content is everything after the found header (and split day if applicable)
        start_content_idx = header_idx + 1
        if found_strategy == "Split": start_content_idx += 1
        
        content_lines = lines[start_content_idx:]
        
        # Extract Verse
        verse = ""
        verse_ref = ""
        ref_regex = re.compile(r".*?(\d?\s?[A-Za-z]+\s\d+:\d+(?:-\d+)?)\.?$")
        
        for k in range(min(len(content_lines), 12)):
            match = ref_regex.match(content_lines[k])
            if match:
                verse = " ".join(content_lines[:k+1])
                verse_ref = match.group(1)
                content_lines = content_lines[k+1:]
                break
        
        return {
            "title": title,
            "verse": verse,
            "verse_ref": verse_ref,
            "content": "\n".join(content_lines)
        }
        
    return None

def run_surgery():
    print("--- SURGICAL REPAIR STARTED ---")
    
    for t in TARGETS:
        code = t['code']
        month = t['month']
        day = t['day']
        
        json_path = os.path.join(JSON_DIR, f"{code.lower()}.json")
        pdf_path = os.path.join(PDF_DIR, f"en_{code}.pdf")
        
        if not os.path.exists(json_path): continue

        # Load current readings
        with open(json_path, 'r', encoding='utf-8') as f:
            readings = json.load(f)

        print(f"\n[{code}] Operating on {month}/{day}...")
        
        found_data = None
        
        # Scan PDF
        with pdfplumber.open(pdf_path) as pdf:
            for page in pdf.pages:
                text = page.extract_text()
                if not text: continue
                
                result = extract_surgical(text, month, day)
                if result:
                    found_data = result
                    print(f"   -> Match found! Strategy used: (Squashed/Split)")
                    break
        
        if found_data:
            # Inject into JSON
            updated = False
            for r in readings:
                if r['month'] == month and r['day'] == day:
                    r['title'] = found_data['title']
                    r['verse'] = found_data['verse']
                    r['verse_ref'] = found_data['verse_ref']
                    r['content'] = found_data['content']
                    updated = True
                    break
            
            # If the entry didn't exist at all, create it
            if not updated:
                new_entry = {
                    "id": f"{code.lower()}_{month:02d}_{day:02d}",
                    "month": month,
                    "day": day,
                    "title": found_data['title'],
                    "verse": found_data['verse'],
                    "verse_ref": found_data['verse_ref'],
                    "content": found_data['content']
                }
                readings.append(new_entry)
                # Sort to keep order
                readings.sort(key=lambda x: (x['month'], x['day']))
                print("   -> Entry was missing. Created new entry.")

            # Save
            with open(json_path, 'w', encoding='utf-8') as f:
                json.dump(readings, f, indent=4, ensure_ascii=False)
            print("   -> JSON Updated Successfully.")
        else:
            print("   -> FAILED. Could not find this date even with surgical methods.")

if __name__ == "__main__":
    run_surgery()