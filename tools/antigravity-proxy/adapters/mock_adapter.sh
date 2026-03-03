#!/usr/bin/env bash
set -euo pipefail
payload="$(cat)"
model=$(echo "$payload" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("model","ag/gemini-3-flash"))')
prompt=$(echo "$payload" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("prompt",""))')
python3 - <<PY
import json
model = ${model@Q}
prompt = ${prompt@Q}
print(json.dumps({
  "text": f"[MOCK:{model}] 收到請求，prompt長度={len(prompt)}",
  "usage": {"prompt_tokens": 0, "completion_tokens": 0, "total_tokens": 0}
}, ensure_ascii=False))
PY
