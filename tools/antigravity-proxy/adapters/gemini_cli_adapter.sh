#!/usr/bin/env bash
set -euo pipefail

# Ensure npm global bin is in PATH (non-interactive shells may not source .bashrc)
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$HOME/.bun/bin:$PATH"

# Force the CLI to use OAuth (the 5-hour quota) instead of the exhausted API key
unset GEMINI_API_KEY

tmp_payload=$(mktemp -t agproxy_payload_XXXXXX.json)
tmp_prompt=$(mktemp -t agproxy_prompt_XXXXXX.txt)
tmp_resp=$(mktemp -t agproxy_resp_XXXXXX.txt)

# Cleanup trap to ensure we always delete the temp files
trap 'rm -f "$tmp_payload" "$tmp_prompt" "$tmp_resp"' EXIT

# Read payload directly into temp file to avoid huge bash variables
cat > "$tmp_payload"

model=$(python3 -c 'import sys,json;print(json.load(sys.stdin).get("model","gemini-3-flash-preview"))' < "$tmp_payload")

# Map models natively for CLI
case "$model" in
  gemini-3.1-pro-high|gemini-3.1-pro) model="gemini-2.5-pro" ;;
  gemini-3-flash*) model="gemini-2.5-flash" ;;
  gemini-3-pro-image) model="gemini-2.5-pro" ;;
esac

# Write prompt purely to a temporary file
python3 -c 'import sys,json; sys.stdout.write(json.load(sys.stdin).get("prompt",""))' < "$tmp_payload" > "$tmp_prompt"

run_json_mode() {
  # Add random human-like jitter (0.3 to 1.5 seconds) to avoid robotic detection
  sleep $(awk 'BEGIN{srand(); print 0.3 + rand() * 1.2}')
  cat "$tmp_prompt" | gemini -p "" -m "$model" --output-format json --yolo --sandbox=false
}

run_text_mode() {
  # Add random human-like jitter
  sleep $(awk 'BEGIN{srand(); print 0.3 + rand() * 1.2}')
  cat "$tmp_prompt" | gemini -p "" -m "$model" --yolo --sandbox=false
}

# 1) Prefer json mode for usage parsing
set +e
run_json_mode > "$tmp_resp" 2>&1
code=$?
set -e

# INTERCEPT CLI BUG (Exits 0 but contains fatal error)
if grep -q "ModelNotFoundError\|GoogleQuotaError\|Error when talking to Gemini\|Requested entity was not found" "$tmp_resp"; then
  code=1
fi

if [[ $code -ne 0 ]]; then
  # Pass detail via stdin to avoid Argument list too long
  python3 -c '
import json, sys
detail = sys.stdin.read()
print(json.dumps({"error":"gemini_cli_failed","detail": detail, "status":502}, ensure_ascii=False))
  ' < "$tmp_resp"
  exit 0
fi

# 2) Parse json robustly; extract text from multiple shapes
parsed=$(python3 -c '
import json,sys,re
raw=sys.stdin.read().strip()
resp=""
usage={"prompt_tokens":0,"completion_tokens":0,"total_tokens":0}
try:
    obj=json.loads(raw)
except Exception:
    # gemini CLI may prepend status lines before JSON; try to recover trailing JSON blob
    obj=None
    for i in range(len(raw)):
        if raw[i] != "{":
            continue
        cand = raw[i:]
        try:
            obj = json.loads(cand)
            break
        except Exception:
            pass
    if obj is None:
        obj={"response":raw}

if isinstance(obj, dict):
    resp = (obj.get("response") or obj.get("text") or "").strip()
    if not resp:
        # common alternative schemas
        cands = obj.get("candidates") or []
        for c in cands:
            content = c.get("content") if isinstance(c,dict) else None
            parts = (content or {}).get("parts",[]) if isinstance(content,dict) else []
            for p in parts:
                t = p.get("text") if isinstance(p,dict) else None
                if t: resp += t
        resp = resp.strip()
        
    # Sanitize leaked internal thought blocks (e.g. CRITICAL INSTRUCTION)
    resp = re.sub(r"^(?:t\n|t\r\n)?CRITICAL INSTRUCTION 1:.*?CRITICAL INSTRUCTION 2:.*?(?=\n\n|\n\[|\Z)", "", resp, flags=re.DOTALL).strip()

    models = obj.get("stats",{}).get("models",{}) if isinstance(obj.get("stats",{}),dict) else {}
    if models:
        m = next(iter(models.values()))
        tok = m.get("tokens",{}) if isinstance(m, dict) else {}
        usage = {
          "prompt_tokens": int(tok.get("prompt",0) or 0),
          "completion_tokens": int(tok.get("candidates",0) or 0),
          "total_tokens": int(tok.get("total",0) or 0),
        }

print(json.dumps({"text":resp,"usage":usage}, ensure_ascii=False))
' < "$tmp_resp")

# Use a file again to avoid extremely long arguments
echo "$parsed" > "$tmp_resp"
text=$(python3 -c 'import sys,json;print((json.load(sys.stdin).get("text") or "").strip())' < "$tmp_resp")

# 3) Fallback: if json mode yields empty text, run plain text mode once
if [[ -z "$text" ]]; then
  set +e
  run_text_mode > "$tmp_resp" 2>&1
  code2=$?
  set -e
  if [[ $code2 -ne 0 ]]; then
    python3 -c '
import json, sys
detail = sys.stdin.read()
print(json.dumps({"error":"gemini_cli_empty_and_fallback_failed","detail": detail, "status":502}, ensure_ascii=False))
    ' < "$tmp_resp"
    exit 0
  fi
  
  cat "$tmp_resp" | sed 's/\r$//' | tr -d '\000' > "${tmp_resp}.clean"
  mv "${tmp_resp}.clean" "$tmp_resp"
  
  python3 -c '
import sys,re,json
text=sys.stdin.read()
text=re.sub(r"^(?:t\n|t\r\n)?CRITICAL INSTRUCTION 1:.*?CRITICAL INSTRUCTION 2:.*?(?=\n\n|\n\[|\Z)", "", text, flags=re.DOTALL).strip()
if not text:
    print(json.dumps({"error":"empty_response","detail":"gemini cli returned empty content","status":502}, ensure_ascii=False))
else:
    print(json.dumps({"text": text, "usage": {"prompt_tokens":0,"completion_tokens":0,"total_tokens":0}}, ensure_ascii=False))
  ' < "$tmp_resp"
  exit 0
fi

# 4) normal json-mode success
printf "%s\n" "$parsed"
