import glob
import os
from datetime import datetime


DEFAULT_WORKSPACE = "/home/chris93/.openclaw/workspace"
WORKSPACE_DIR = os.environ.get("OPENCLAW_WORKSPACE", DEFAULT_WORKSPACE)
STAGING_DIR = os.path.join(WORKSPACE_DIR, "memory", "staging")
OUTPUT_DIR = os.path.join(WORKSPACE_DIR, "memory")


def merge_staging_memory():
    if not os.path.exists(STAGING_DIR):
        print(f"Staging directory not found: {STAGING_DIR}")
        return

    today = datetime.now().strftime("%Y-%m-%d")
    main_memory_file = os.path.join(OUTPUT_DIR, f"{today}.md")
    staging_files = sorted(glob.glob(os.path.join(STAGING_DIR, "*.md")))

    if not staging_files:
        print("No staging files to merge.")
        return

    print(f"Found {len(staging_files)} staging files.")
    merged_parts = []

    for file_path in staging_files:
        try:
            with open(file_path, "r", encoding="utf-8") as f:
                content = f.read().strip()
        except Exception as exc:
            print(f"Error reading {file_path}: {exc}")
            continue

        if not content:
            print(f"Skipping empty fragment: {file_path}")
            continue

        file_name = os.path.basename(file_path)
        merged_parts.append(f"\n\n<!-- merged from {file_name} -->\n{content}")

    if not merged_parts:
        print("No non-empty staging files to merge.")
        return

    os.makedirs(OUTPUT_DIR, exist_ok=True)

    try:
        with open(main_memory_file, "a", encoding="utf-8") as main_f:
            main_f.write("".join(merged_parts) + "\n")
        print(f"Appended {len(merged_parts)} fragment(s) to {main_memory_file}")
    except Exception as exc:
        print(f"Fatal error appending to main memory: {exc}")
        return

    for file_path in staging_files:
        try:
            os.remove(file_path)
            print(f"Deleted {file_path}")
        except Exception as exc:
            print(f"Failed to delete {file_path}: {exc}")


if __name__ == "__main__":
    merge_staging_memory()
