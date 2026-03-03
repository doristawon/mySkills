import json
import subprocess
import os

source_file = "/home/chris93/.openclaw/workspace/training_materials.jsonl"
modifier_script = "/home/chris93/.openclaw/workspace/scripts/append_coder_training.py"

with open(source_file, 'r', encoding='utf-8') as f:
    lines = f.readlines()

if not lines:
    exit(0)

# get up to last 3 lines
num_to_read = min(3, len(lines))
last_lines = lines[-num_to_read:]

to_delete_lines = []

for line in last_lines:
    try:
        data = json.loads(line)
        instruction = data.get("instruction", "")
        output = data.get("output", "")
        
        # Check if OpenClaw related
        is_openclaw = "openclaw" in instruction.lower() or "openclaw" in output.lower()
        
        if is_openclaw:
            cmd = ["python3", modifier_script, instruction, output, "codex-review", "minimax-portal/MiniMax-M2.5"]
            result = subprocess.run(cmd, capture_output=True, text=True)
            if result.returncode == 0:
                to_delete_lines.append(line)
    except Exception as e:
        pass

if to_delete_lines:
    remaining_last = []
    # track which ones we've deleted to handle exact duplicates properly
    deleted_counts = {}
    for l in to_delete_lines:
        deleted_counts[l] = deleted_counts.get(l, 0) + 1
        
    for line in last_lines:
        if deleted_counts.get(line, 0) > 0:
            deleted_counts[line] -= 1
        else:
            remaining_last.append(line)
            
    final_lines = lines[:-num_to_read] + remaining_last
    
    with open(source_file, 'w', encoding='utf-8') as f:
        f.writelines(final_lines)
