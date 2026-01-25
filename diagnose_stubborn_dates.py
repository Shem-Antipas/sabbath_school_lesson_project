import pdfplumber
import re
import os

# --- CONFIGURATION ---
PDF_DIR = "pdf_downloads"

# The specific "Stubborn" dates that failed to fix
# Format: "CODE": ["Month Day", "Month Day"]
STUBBORN_TARGETS = {
    "OFC": ["January 11", "February 29"],
    "OHC": ["September 29"],
    "BLJ": ["February 17", "February 25"],
    "YRP": ["July 28", "December 21"]
}

def diagnose_dates():
    print("--- DIAGNOSING STUBBORN DATES ---\n")

    for code, dates in STUBBORN_TARGETS.items():
        pdf_path = os.path.join(PDF_DIR, f"en_{code}.pdf")
        if not os.path.exists(pdf_path):
            print(f"Error: {pdf_path} not found.")
            continue

        print(f"Scanning {code} for {dates}...")
        
        with pdfplumber.open(pdf_path) as pdf:
            for target_date in dates:
                found_count = 0
                print(f"\n>>> Searching for '{target_date}' in {code}...")
                
                # Split target (e.g., "February 17") to search loosely
                parts = target_date.split()
                month = parts[0]
                day = parts[1]

                for i, page in enumerate(pdf.pages):
                    text = page.extract_text()
                    if not text: continue
                    
                    # Check if page contains both Month and Day
                    if month in text and day in text:
                        # Grab the top 5 lines to show the user
                        lines = [l.strip() for l in text.split('\n') if l.strip()]
                        header_sample = "\n".join(lines[:5])
                        
                        print(f"   [Page {i+1} Match?]")
                        print(f"   -------------------")
                        print(f"{header_sample}")
                        print(f"   -------------------")
                        found_count += 1
                        
                        # Stop after finding 2 potential candidates to avoid flooding console
                        if found_count >= 2: break
                
                if found_count == 0:
                    print(f"   [!!!] text '{target_date}' NOT FOUND on any page.")

if __name__ == "__main__":
    diagnose_dates()