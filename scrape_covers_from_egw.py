import os
import requests
from bs4 import BeautifulSoup
from urllib.parse import urljoin

# --- CONFIGURATION ---
TARGET_URL = "https://m.egwwritings.org/en/folders/1227"
SAVE_DIR = "assets/images/devotionals"

# Map the "Website Title" to your "App ID"
BOOK_MAPPING = {
    "To Be Like Jesus": "blj",
    "Homeward Bound": "hb",
    "In Heavenly Places": "hp",
    "Lift Him Up": "lhu",
    "Maranatha": "mar",
    "Our Father Cares": "ofc",
    "Our High Calling": "ohc",
    "Reflecting Christ": "rc",
    "Sons and Daughters of God": "sd",
    "This Day With God": "tdg",
    "That I May Know Him": "tmk",
    "The Upward Look": "ul",
    "Ye Shall Receive Power": "yrp",
}

def scrape_and_download():
    # 1. Create directory
    if not os.path.exists(SAVE_DIR):
        os.makedirs(SAVE_DIR)
        print(f"Created directory: {SAVE_DIR}")

    print(f"Fetching page: {TARGET_URL}...")
    
    try:
        # 2. Get the HTML
        headers = {'User-Agent': 'Mozilla/5.0'} # Pretend to be a browser
        response = requests.get(TARGET_URL, headers=headers)
        response.raise_for_status()
        
        soup = BeautifulSoup(response.text, 'html.parser')
        
        # 3. Find all book entries
        # On m.egwwritings, books are usually in a list. 
        # We look for images and check if their Title/Alt matches our list.
        
        found_count = 0
        
        # Iterate over all images on the page
        for img in soup.find_all('img'):
            alt_text = img.get('alt', '').strip()
            src = img.get('src', '')
            
            if not alt_text or not src:
                continue
                
            # Check if this image corresponds to one of our books
            # We do a loose match (e.g. if "Maranatha" is in the alt text)
            matched_code = None
            for title, code in BOOK_MAPPING.items():
                if title.lower() in alt_text.lower():
                    matched_code = code
                    break
            
            if matched_code:
                # 4. Construct Full URL
                # The src might be relative (e.g. "/images/cover.jpg")
                full_image_url = urljoin(TARGET_URL, src)
                
                # 5. Download
                save_path = os.path.join(SAVE_DIR, f"{matched_code}_cover.png")
                
                if os.path.exists(save_path):
                    print(f"  [SKIP] {matched_code} already exists.")
                    found_count += 1
                    continue

                print(f"  [DOWNLOADING] {matched_code} ({alt_text})...")
                try:
                    img_data = requests.get(full_image_url, headers=headers).content
                    with open(save_path, 'wb') as f:
                        f.write(img_data)
                    found_count += 1
                except Exception as e:
                    print(f"    -> Error downloading {full_image_url}: {e}")

        print(f"\nProcessing Complete. Found {found_count} of {len(BOOK_MAPPING)} covers.")
        
        if found_count < len(BOOK_MAPPING):
            print("Warning: Some books were not found. The website structure might have changed or titles didn't match exactly.")

    except Exception as e:
        print(f"Fatal Error: {e}")

if __name__ == "__main__":
    scrape_and_download()