import pdfplumber
import re
import json
import os

# --- CONFIGURATION ---
INPUT_FILENAME = "en_FH.pdf"
OUTPUT_FILENAME = "fh.json" 
BOOK_ID_PREFIX = "fh"

# --- MANUAL PATCHES ---
# If any specific dates fail to capture the title correctly, add them here.
# Format: "Month Day": "Correct Title"
MANUAL_PATCHES = {
    # Example (add if needed after first run):
    # "October 15": "Confrontation at Jacob’s Well",
}

def clean_title(raw_text):
    """
    Removes artifacts like [34], 12., or leading/trailing numbers.
    """
    if not raw_text: return ""
    
    # 1. Remove bracketed numbers e.g., [34] or [7]
    text = re.sub(r'\[\d+\]', '', raw_text)
    
    # 2. Remove leading numbers/dots e.g., "12. Title"
    text = re.sub(r'^[\d\s\.\-]+', '', text)
    
    # 3. Remove trailing dots/numbers e.g., "Title . . . 55"
    text = re.sub(r'[\.\s\d]+$', '', text)
    
    return text.strip()

def extract_devotional_json(pdf_path, output_path, id_prefix):
    print(f"Processing {pdf_path}...")

    if not os.path.exists(pdf_path):
        print(f"Error: Input file '{pdf_path}' not found.")
        return

    # --- REGEX PATTERNS ---
    
    # 1. Date Anchor: Matches "January 1" anywhere in the line
    date_regex = re.compile(
        r"(?:^|\s|[,.\-])(January|February|March|April|May|June|July|August|September|October|November|December)\s+(\d{1,2})\b",
        re.IGNORECASE
    )
    
    # 2. Verse Reference: Matches "Psalm 119:105." at end of line
    reference_pattern = re.compile(r".*?(\d?\s?[A-Za-z]+\s\d+:\d+(?:-\d+)?)\.?$")

    # 3. Noise to Ignore
    ignore_patterns = [
        r"^\d+$",                       # Page numbers
        r"^From the Heart$",            # Book Header
        r".*\. \. \..*",                # TOC lines
        r"^Contents$", 
        r"^--- PAGE \d+ ---$",
        r"^\[\d+\]$"                    # Stray footnote numbers
    ]

    month_map = {
        "January": 1, "February": 2, "March": 3, "April": 4, "May": 5, "June": 6,
        "July": 7, "August": 8, "September": 9, "October": 10, "November": 11, "December": 12
    }

    all_readings = []
    current_reading = None
    text_buffer = []
    processed_dates = set()

    # --- 1. LOAD ALL LINES ---
    all_lines = []
    with pdfplumber.open(pdf_path) as pdf:
        for page in pdf.pages:
            text = page.extract_text()
            if text:
                all_lines.extend([l.strip() for l in text.split('\n') if l.strip()])

    # --- 2. PROCESS LINES ---
    for i, line in enumerate(all_lines):
        # Skip noise
        if any(re.match(p, line) for p in ignore_patterns): continue

        match = date_regex.search(line)
        is_header = False
        title = ""
        month = ""
        day = ""

        if match:
            month_str, day_str = match.groups()
            date_key = f"{month_str} {day_str}"

            # A. Check Manual Patches
            if date_key in MANUAL_PATCHES and date_key not in processed_dates:
                title = MANUAL_PATCHES[date_key]
                month, day = month_str, day_str
                is_header = True
            
            # B. Standard Header Detection
            # Headers in this book look like: "The Old Year and the New, January 1"
            # Or sometimes with page number: "Title, Month Day 781"
            elif len(line) < 140:
                # Everything before the date match is the title candidate
                parts = line[:match.start()].strip()
                title_candidate = re.sub(r"[,–-]$", "", parts).strip()
                
                # Lookback: If title is empty, check previous line
                if len(title_candidate) < 3 and i > 0:
                    for lookback in range(1, 4):
                        if i - lookback < 0: break
                        prev = all_lines[i-lookback]
                        if not any(re.match(p, prev) for p in ignore_patterns):
                            title_candidate = prev
                            break
                
                if title_candidate:
                    title = clean_title(title_candidate)
                    month, day = month_str, day_str
                    is_header = True

        # --- SAVE ENTRY ---
        if is_header:
            date_key = f"{month} {day}"
            if date_key in processed_dates: continue

            # Close previous reading
            if current_reading:
                process_buffer(current_reading, text_buffer, reference_pattern)
                all_readings.append(current_reading)

            processed_dates.add(date_key)
            
            month_num = month_map.get(month, 1)
            day_num = int(day)
            id_string = f"{id_prefix}_{month_num:02d}_{day_num:02d}"

            current_reading = {
                "id": id_string,
                "month": month_num,
                "day": day_num,
                "title": title,
                "verse": "",
                "verse_ref": "",
                "content": ""
            }
            text_buffer = []
        else:
            if current_reading: text_buffer.append(line)

    # Save final reading
    if current_reading:
        process_buffer(current_reading, text_buffer, reference_pattern)
        all_readings.append(current_reading)

    # --- 3. WRITE JSON ---
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(all_readings, f, indent=4, ensure_ascii=False)

    print(f"\nProcessing Complete.")
    print(f"Extracted {len(all_readings)} readings.")
    print(f"Output saved to: {output_path}")

def process_buffer(reading_dict, buffer, ref_regex):
    if not buffer: return
    split_idx = -1
    reference_text = ""
    
    # Scan first 20 lines to find the Bible Verse Reference
    for i in range(min(len(buffer), 20)):
        match = ref_regex.match(buffer[i])
        if match:
            split_idx = i
            reference_text = match.group(1)
            break
    
    if split_idx != -1:
        # Verse is everything up to the reference
        reading_dict['verse'] = " ".join(buffer[:split_idx+1])
        reading_dict['verse_ref'] = reference_text
        # Content is everything after
        reading_dict['content'] = "\n".join(buffer[split_idx+1:])
    else:
        # Fallback: Treat whole buffer as content
        reading_dict['content'] = "\n".join(buffer)

if __name__ == "__main__":
    extract_devotional_json(INPUT_FILENAME, OUTPUT_FILENAME, BOOK_ID_PREFIX)