import json

def update_hymnal_topics():
    # 1. Load your current JSON file
    file_path = 'assets/hymns.json'
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            hymns = json.load(f)
    except FileNotFoundError:
        print("Error: assets/hymns.json not found.")
        return

    # 2. Define SDA Hymnal topic ranges
    # You can expand this list based on the SDA Hymnal index
    topic_ranges = [
        (1, 38, "Adoration and Praise"),
        (39, 53, "Morning Worship"),
        (54, 63, "Evening Worship"),
        (64, 69, "Opening of Worship"),
        (70, 91, "Holy Trinity"),
        (92, 114, "God the Father"),
        (115, 153, "Jesus Christ"),
        (154, 164, "Holy Spirit"),
        (165, 199, "Holy Scripture"),
        (200, 221, "Gospel Invitation"),
        (382, 395, "The Sabbath"),
        (412, 437, "The Second Coming"),
    ]

    # 3. Apply topics to each hymn
    for hymn in hymns:
        hymn_id = hymn.get('id', 0)
        hymn['topic'] = "General"  # Default topic

        for start, end, label in topic_ranges:
            if start <= hymn_id <= end:
                hymn['topic'] = label
                break

    # 4. Save the updated JSON
    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(hymns, f, indent=2, ensure_ascii=False)
    
    print(f"Successfully updated {len(hymns)} hymns with topics!")

if __name__ == "__main__":
    update_hymnal_topics()