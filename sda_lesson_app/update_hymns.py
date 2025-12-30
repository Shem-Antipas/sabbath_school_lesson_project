import json
import os

def update_hymnal_topics():
    target_file = "hymns.json"
    file_path = None

    # This searches the current folder and all subfolders for hymns.json
    for root, dirs, files in os.walk("."):
        if target_file in files:
            file_path = os.path.join(root, target_file)
            break

    if not file_path:
        print(f"Error: Could not find '{target_file}' anywhere in this folder!")
        return

    print(f"Found file at: {file_path}")

    with open(file_path, 'r', encoding='utf-8') as f:
        hymns = json.load(f)

    # Full SDA Hymnal Categories
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
        (200, 223, "Gospel Invitation"),
        (224, 256, "Repentance/Forgiveness"),
        (257, 300, "Christian Gratitude"),
        (301, 333, "Christian Prayer"),
        (334, 343, "Baptism"),
        (344, 354, "Lord's Supper"),
        (376, 381, "The Sanctuary"),
        (382, 395, "The Sabbath"),
        (412, 437, "The Second Coming"),
    ]

    for hymn in hymns:
        hymn_id = int(hymn.get('id', 0))
        hymn['topic'] = "Christian Life" # Modern Default
        for start, end, label in topic_ranges:
            if start <= hymn_id <= end:
                hymn['topic'] = label
                break

    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(hymns, f, indent=2, ensure_ascii=False)
    
    print(f"Done! Updated {len(hymns)} hymns in {file_path}")

if __name__ == "__main__":
    update_hymnal_topics()