import pdfplumber
import requests
import json
import re
import os

# --- CONFIGURATION ---
PDF_URL = "https://media4.egwwritings.org/pdf/en_CCh.pdf"
PDF_FILENAME = "en_CCh.pdf"
JSON_FILENAME = "assets/data/cch.json"

def download_pdf():
    if os.path.exists(PDF_FILENAME):
        print(f"Using local PDF: {PDF_FILENAME}")
        return
    print(f"Downloading {PDF_FILENAME}...")
    try:
        r = requests.get(PDF_URL, stream=True)
        with open(PDF_FILENAME, 'wb') as f:
            for chunk in r.iter_content(1024): f.write(chunk)
        print("Download complete.")
    except Exception as e:
        print(f"Error downloading PDF: {e}")

def clean_content(text):
    if not text: return ""
    
    # 1. Remove Page Numbers (standalone numbers at end of lines)
    text = re.sub(r'^\d+\s*$', '', text, flags=re.MULTILINE)
    
    # 2. Remove Book Header (repeated on every other page)
    text = re.sub(r"Counsels for the Church", "", text)
    
    # 3. Remove "Contents" header if it slipped in
    text = re.sub(r"^Contents\s+[ivx]+$", "", text, flags=re.MULTILINE)
    
    # 4. Fix Hyphenated words (e.g. "commu-\nnication")
    text = re.sub(r'(\w+)-\n(\w+)', r'\1\2', text)
    
    # 5. Remove footnotes [1], [2]
    text = re.sub(r'\[\d+\]', '', text)
    
    return " ".join(text.split())

def is_toc_line(line):
    """
    Detects lines that are part of the Table of Contents
    Example: "Chapter 1....... 7" or "My First Vision....... 45"
    """
    # Check for dots followed by a number at the end
    if re.search(r'\.\s*\d+$', line): return True
    # Check for just a number at the end of a short line (TOC style)
    if re.search(r'\s+\d+$', line) and len(line) < 70: return True
    return False

def extract_book():
    print("Scanning PDF (Header Hunter Mode)...")
    
    chapters = []
    current_chapter = {"number": 0, "title": "Preface", "content": ""}
    
    # Regex to catch "Chapter 1", "Chap. 1", "CHAPTER 1"
    header_regex = re.compile(r"^(?:Chap\.|Chapter)\s+(\d+)", re.IGNORECASE)

    with pdfplumber.open(PDF_FILENAME) as pdf:
        total = len(pdf.pages)
        
        # Skip the TOC pages (approx first 14 pages)
        start_page = 14
        
        for i in range(start_page, total):
            page = pdf.pages[i]
            
            # Crop headers/footers to remove page numbers/running titles
            # (Top 50px, Bottom 50px)
            cropped = page.crop((0, 50, page.width, page.height - 50))
            text = cropped.extract_text()
            if not text: continue
            
            lines = text.split('\n')
            skip_next = False
            
            for idx, line in enumerate(lines):
                line = line.strip()
                if not line: continue
                if skip_next:
                    skip_next = False
                    continue

                # Check for Chapter Header
                match = header_regex.match(line)
                
                # Verify it's not a TOC entry (just in case)
                if match and not is_toc_line(line):
                    
                    new_num = int(match.group(1))
                    
                    # Prevent finding the same chapter twice on one page
                    if new_num == current_chapter['number']:
                        continue
                    
                    # Prevent jumping backward (e.g. reading a footnote ref)
                    if new_num < current_chapter['number']:
                        continue

                    # --- Extract Title ---
                    # Case A: Title on same line ("Chapter 1—A Vision...")
                    # We strip the "Chapter 1" part and symbols
                    title_part = line[match.end():].strip(" .:-—–")
                    
                    if len(title_part) > 3:
                        new_title = title_part
                    else:
                        # Case B: Title on next line
                        if idx + 1 < len(lines):
                            new_title = lines[idx+1].strip()
                            skip_next = True
                        else:
                            new_title = f"Chapter {new_num}"

                    # --- Save Previous Chapter ---
                    if len(current_chapter['content']) > 200:
                        current_chapter['content'] = clean_content(current_chapter['content'])
                        chapters.append(current_chapter)
                        print(f"  [SAVED] Chapter {current_chapter['number']}")

                    print(f"  [FOUND] Chapter {new_num}: {new_title} (Page {i+1})")
                    
                    current_chapter = {
                        "number": new_num,
                        "title": new_title,
                        "content": ""
                    }
                else:
                    # Append content
                    # This naturally preserves Sub-Topics (like "My First Vision")
                    # because they are treated as regular text lines.
                    current_chapter['content'] += line + "\n"

            if i % 20 == 0: print(f"  Scanned page {i}/{total}...")

        # Save Last Chapter
        if len(current_chapter['content']) > 200:
            current_chapter['content'] = clean_content(current_chapter['content'])
            chapters.append(current_chapter)
            print(f"  [SAVED] Chapter {current_chapter['number']}")

    # Create JSON
    book_json = {
        "title": "Counsels for the Church",
        "chapters": chapters
    }

    os.makedirs(os.path.dirname(JSON_FILENAME), exist_ok=True)
    with open(JSON_FILENAME, 'w', encoding='utf-8') as f:
        json.dump(book_json, f, indent=2, ensure_ascii=False)
    
    print(f"\n[Success] JSON saved to {JSON_FILENAME}")
    print(f"Total Chapters: {len(chapters)}")

if __name__ == "__main__":
    download_pdf()
    extract_book()