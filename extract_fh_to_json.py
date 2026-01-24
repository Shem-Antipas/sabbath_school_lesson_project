import pdfplumber
import re
import json
import os

# --- CONFIGURATION ---
INPUT_FILENAME = "en_HB.pdf"
OUTPUT_FILENAME = "hb.json" 
BOOK_ID_PREFIX = "hb"

# --- NUCLEAR RESCUE PATCHES ---
# We look for specific Month + Day combinations in a line.
# If found, we FORCE the header, regardless of what the rest of the line looks like.
NUCLEAR_PATCHES = [
    { "month_trigger": "March", "day_trigger": "15", "title": "Holiness Is . . . !" },
    { "month_trigger": "March", "day_trigger": "16", "title": "Righteousness Is . . . !" },
    { "month_trigger": "March", "day_trigger": "17", "title": "Sanctification Is . . . !" },
    { "month_trigger": "March", "day_trigger": "19", "title": "Repentance Is . . . !" },
    { "month_trigger": "December", "day_trigger": "10", "title": "The Translation of The Righteous Living" },
]

def clean_title(raw_text):
    if not raw_text: return ""
    text = re.sub(r'\[\d+\]', '', raw_text)
    text = re.sub(r'^[\d\s\.\-]+', '', text)
    text = re.sub(r'[\.\s\d]+$', '', text)
    text = re.sub(r',\s*$', '', text) 
    return text.strip()

def extract_devotional_json(pdf_path, output_path, id_prefix):
    print(f"Processing {pdf_path}...")

    if not os.path.exists(pdf_path):
        print(f"Error: Input file '{pdf_path}' not found.")
        return

    # --- REGEX ---
    date_regex = re.compile(
        r"(?:^|\s|[,.\-])(January|February|March|April|May|June|July|August|September|October|November|December)\s+(\d{1,2})\b",
        re.IGNORECASE
    )
    reference_pattern = re.compile(r".*?(\d?\s?[A-Za-z]+\s\d+:\d+(?:-\d+)?)\.?$")

    ignore_patterns = [
        r"^\d+$", r"^The Upward Look$", r".*\. \. \..*", r"^Contents$", 
        r"^--- PAGE \d+ ---$", r"^\[\d+\]$", r"^January-The Book Of Books$"
    ]

    month_map = {
        "January": 1, "February": 2, "March": 3, "April": 4, "May": 5, "June": 6,
        "July": 7, "August": 8, "September": 9, "October": 10, "November": 11, "December": 12
    }

    all_readings = []
    current_reading = None
    text_buffer = []
    processed_dates = set()

    # --- 1. LOAD LINES ---
    all_lines = []
    with pdfplumber.open(pdf_path) as pdf:
        for page in pdf.pages:
            text = page.extract_text()
            if text:
                all_lines.extend([l.strip() for l in text.split('\n') if l.strip()])

    # --- 2. PROCESS LINES ---
    for i, line in enumerate(all_lines):
        if any(re.match(p, line) for p in ignore_patterns): continue

        is_header = False
        title = ""
        month = ""
        day = ""

        # --- A. NUCLEAR PATCH CHECK (Fuzzy Match) ---
        for patch in NUCLEAR_PATCHES:
            # Check if line contains "March" AND "15" (case insensitive)
            if (patch["month_trigger"].lower() in line.lower() and 
                patch["day_trigger"] in line):
                
                # Verify it's not a Bible verse (e.g. "read March 15") by length
                # Headers are usually short (< 100 chars)
                if len(line) < 120:
                    title = patch["title"]
                    month = patch["month_trigger"]
                    day = patch["day_trigger"]
                    is_header = True
                    # Debug print to confirm it worked
                    print(f"  [Patch Applied] Found {month} {day}") 
                    break

        # --- B. STANDARD DETECTION ---
        if not is_header:
            match = date_regex.search(line)
            if match:
                month_str, day_str = match.groups()
                if len(line) < 140:
                    parts = line[:match.start()].strip()
                    title_candidate = re.sub(r"[,–-]$", "", parts).strip()
                    
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
    print(f"Extracted {len(all_readings)} readings. (Target: 366)")
    print(f"Output saved to: {output_path}")

def process_buffer(reading_dict, buffer, ref_regex):
    if not buffer: return
    split_idx = -1
    reference_text = ""
    for i in range(min(len(buffer), 20)):
        match = ref_regex.match(buffer[i])
        if match:
            split_idx = i
            reference_text = match.group(1)
            break
    
    if split_idx != -1:
        reading_dict['verse'] = " ".join(buffer[:split_idx+1])
        reading_dict['verse_ref'] = reference_text
        reading_dict['content'] = "\n".join(buffer[split_idx+1:])
    else:
        reading_dict['content'] = "\n".join(buffer)

if __name__ == "__main__":
    extract_devotional_json(INPUT_FILENAME, OUTPUT_FILENAME, BOOK_ID_PREFIX)