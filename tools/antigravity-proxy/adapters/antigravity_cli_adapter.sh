#!/usr/bin/env bash
set -euo pipefail

# Contract:
# - Read JSON payload from stdin: {model,prompt,messages,...}
# - Output JSON to stdout: {text, usage?}
#
# NOTE:
# Antigravity CLI flags can change. Adjust CMD_TEMPLATE to your local CLI syntax.
# Example template (replace with actual supported args):
#   antigravity chat --model "{{model}}" --prompt-file "{{prompt_file}}" --output json

payload_file=$(mktemp)
cat > "$payload_file"

model=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("model","ag/gemini-3-flash"))' "$payload_file")
prompt=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("prompt",""))' "$payload_file")

prompt_file=$(mktemp)
printf "%s" "$prompt" > "$prompt_file"

CMD_TEMPLATE=${AG_PROXY_AG_CMD_TEMPLATE:-'antigravity --help >/dev/null; echo "{""text"":""[TODO] 設定 AG_PROXY_AG_CMD_TEMPLATE 後即可實際呼叫 Antigravity CLI""}"'}
cmd=${CMD_TEMPLATE//'{{model}}'/$model}
cmd=${cmd//'{{prompt_file}}'/$prompt_file}

set +e
raw=$(bash -lc "$cmd" 2>&1)
code=$?
set -e

rm -f "$payload_file" "$prompt_file"

if [[ $code -ne 0 ]]; then
  python3 - <<PY
import json
print(json.dumps({"text":"", "error":"antigravity_cli_failed", "detail": """$raw"""}, ensure_ascii=False))
PY
  exit 1
fi

# If backend already outputs JSON with text, pass through; else wrap it.
python3 - <<PY
import json
raw = '''$raw'''.strip()
try:
    obj = json.loads(raw)
    if isinstance(obj, dict) and 'text' in obj:
        print(json.dumps(obj, ensure_ascii=False))
    else:
        print(json.dumps({"text": raw}, ensure_ascii=False))
except Exception:
    print(json.dumps({"text": raw}, ensure_ascii=False))
PY
