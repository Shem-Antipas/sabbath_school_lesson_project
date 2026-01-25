import pdfplumber
import re
import json
import os
import shutil

# --- CONFIGURATION ---
JSON_DIR = "json_output"
PDF_DIR = "pdf_downloads"

# Books to check
BOOKS_TO_PROCESS = [
    {"code": "BLJ", "title": "To Be Like Jesus"},
    {"code": "HP",  "title": "In Heavenly Places"},
    {"code": "LHU", "title": "Lift Him Up"},
    {"code": "OFC", "title": "Our Father Cares"},
    {"code": "OHC", "title": "Our High Calling"},
    {"code": "RC",  "title": "Reflecting Christ"},
    {"code": "TDG", "title": "This Day With God"},
    {"code": "TMK", "title": "That I May Know Him"},
    {"code": "YRP", "title": "Ye Shall Receive Power"},
    # Add others if needed
]

# Minimum characters to consider a reading "Valid". 
# Any entry with less than this is considered "Blank" and will be re-scanned.
MIN_CONTENT_LENGTH = 100 

def get_blank_entries(json_path):
    """Returns a list of entries that exist but are empty."""
    try:
        with open(json_path, 'r', encoding='utf-8') as f:
            readings = json.load(f)
    except:
        return [], []

    blanks = []
    
    # Month name map for searching
    month_names = ["", "January", "February", "March", "April", "May", "June", 
                   "July", "August", "September", "October", "November", "December"]
    short_names = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", 
                   "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    for r in readings:
        # Check if content is too short
        if len(r.get('content', '').strip()) < MIN_CONTENT_LENGTH:
            blanks.append({
                "month": r['month'],
                "day": r['day'],
                "month_name": month_names[r['month']],
                "short_name": short_names[r['month']],
                "original_entry": r
            })
            
    return blanks, readings

def clean_title(raw_text):
    if not raw_text: return "Devotional Reading"
    text = re.sub(r'\[\d+\]', '', raw_text)
    text = re.sub(r'\d+$', '', text) 
    text = re.sub(r'[\.\s]+$', '', text)
    text = re.sub(r',\s*$', '', text)
    return text.strip()

def extract_page_content(page_text, target):
    """
    Scans a whole page to see if it contains the target date AND substantial text.
    """
    if not page_text: return None
    
    # Must have enough text to be a real reading
    if len(page_text) < MIN_CONTENT_LENGTH: return None

    lines = [l.strip() for l in page_text.split('\n') if l.strip()]
    if not lines: return None

    # Check the top 15 lines for the date header
    header_found = False
    header_idx = -1
    
    target_day = str(target['day'])
    search_terms = [
        target['month_name'].lower(), # "january"
        target['short_name'].lower() + " "  # "jan "
    ]

    for i in range(min(len(lines), 15)):
        line_lower = lines[i].lower()
        
        # Does line have the Day number?
        if target_day in line_lower:
            # Does line have the Month name?
            for term in search_terms:
                if term in line_lower:
                    # Exclude TOC lines (dots)
                    if "..." in lines[i] or ". . ." in lines[i]: continue
                    
                    header_found = True
                    header_idx = i
                    break
        if header_found: break

    if header_found:
        # Extract Title (Text in header line excluding date)
        header_line = lines[header_idx]
        temp_title = header_line
        for term in search_terms:
            temp_title = re.sub(term, '', temp_title, flags=re.IGNORECASE)
        temp_title = temp_title.replace(target_day, "").replace(",", "").strip()
        
        title = clean_title(temp_title)
        if len(title) < 3 and header_idx > 0:
            # Check previous line for title
            if not re.match(r"^\d+$", lines[header_idx-1]):
                title = clean_title(lines[header_idx-1])

        # Content is everything after the header
        content_lines = lines[header_idx+1:]
        
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

def fix_books():
    for book in BOOKS_TO_PROCESS:
        code = book['code']
        json_file = os.path.join(JSON_DIR, f"{code.lower()}.json")
        pdf_file = os.path.join(PDF_DIR, f"en_{code}.pdf")
        
        if not os.path.exists(json_file) or not os.path.exists(pdf_file):
            print(f"[Skip] {code} - Missing files.")
            continue

        # 1. FIND BLANKS
        blanks, all_readings = get_blank_entries(json_file)
        
        if not blanks:
            print(f"[OK] {code} has no blank entries.")
            continue

        print(f"\n[Repairing] {code} - Found {len(blanks)} blank entries (content < {MIN_CONTENT_LENGTH} chars)")
        print(f"  -> Target Dates: {[f'{b['month']}/{b['day']}' for b in blanks]}")

        fixed_count = 0
        
        # 2. SCAN PDF
        with pdfplumber.open(pdf_file) as pdf:
            # Performance optimization: Only scan if we have blanks left to fix
            for page in pdf.pages:
                if not blanks: break
                
                text = page.extract_text()
                if not text: continue
                
                # Check this page against all remaining blanks
                for b in list(blanks): # Copy list to modify safely
                    result = extract_page_content(text, b)
                    if result:
                        # 3. UPDATE DATA
                        # Find the original entry in all_readings and update it
                        for r in all_readings:
                            if r['month'] == b['month'] and r['day'] == b['day']:
                                r['title'] = result['title']
                                r['verse'] = result['verse']
                                r['verse_ref'] = result['verse_ref']
                                r['content'] = result['content']
                                break
                        
                        print(f"  + Fixed: {b['month_name']} {b['day']}")
                        blanks.remove(b)
                        fixed_count += 1
                        break # Move to next page

        # 4. SAVE
        if fixed_count > 0:
            # Backup original just in case
            shutil.copy(json_file, json_file + ".bak")
            
            with open(json_file, 'w', encoding='utf-8') as f:
                json.dump(all_readings, f, indent=4, ensure_ascii=False)
            print(f"  -> Successfully repaired {fixed_count} entries for {code}!")
        
        if blanks:
            print(f"  [Warning] Could not fix {len(blanks)} entries: {[f'{b['month']}/{b['day']}' for b in blanks]}")

if __name__ == "__main__":
    fix_books()