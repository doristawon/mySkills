#!/usr/bin/env bash
set -euo pipefail

# Ensure npm global bin is in PATH (non-interactive shells may not source .bashrc)
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$HOME/.bun/bin:$PATH"

# Claude via Antigravity service adapter
# Priority:
#  1) Local antigravity-claude-proxy (default: http://127.0.0.1:8080)
#  2) Antigravity Manager API (default: http://127.0.0.1:8045)

payload_file=$(mktemp -t agpx_claude_in_XXXXXX.json)
extracted_file=$(mktemp -t agpx_claude_out_XXXXXX.json)

# Ensure temp files are cleaned up on exit
trap 'rm -f "$payload_file" "$extracted_file"' EXIT

# Read massive payload from stdin directly to file
cat > "$payload_file"

# Extract and separate system messages from non-system messages
# Translates OpenAI Vision and Tools payload into Anthropic Messages API format
python3 - "$payload_file" > "$extracted_file" <<'EOFPY'
import sys, json, os, re
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    p = json.load(f)

# Strip ag/ prefix and normalize dots to dashes for Anthropic API
raw_model = p.get('model', 'claude-sonnet-4-6')
model = raw_model.replace('ag/', '').replace('.', '-')
msgs = p.get('messages', [])
max_tokens = int(p.get('max_tokens', 4096) or 4096)
temperature = p.get('temperature')

system_parts = []
non_system = []

for m in msgs:
    role = (m.get('role') or 'user').strip()
    c = m.get('content', '')
    
    if role in ('system', 'developer'):
        if isinstance(c, list):
            c = ' '.join(item.get('text','') for item in c if isinstance(item, dict) and 'text' in item)
        if c: system_parts.append(str(c))
        continue

    out_role = role if role in ('user','assistant') else 'user'
    out_content = []
    
    if isinstance(c, str):
        if c.strip(): out_content.append({"type": "text", "text": c.strip()})
    elif isinstance(c, list):
        for item in c:
            if not isinstance(item, dict): continue
            if item.get("type") == "text" and item.get("text"):
                out_content.append({"type": "text", "text": item["text"]})
            elif item.get("type") == "image_url":
                url = item.get("image_url", {}).get("url", "")
                if url.startswith("data:"):
                    match = re.match(r"data:(image/[a-zA-Z0-9]+);base64,(.+)", url)
                    if match:
                        mime_type = match.group(1)
                        b64_data = match.group(2)
                        out_content.append({
                            "type": "image", 
                            "source": {"type": "base64", "media_type": mime_type, "data": b64_data}
                        })
    if not out_content: continue
    non_system.append({'role': out_role, 'content': out_content})

# Extract Tools and translation
anthropic_tools = []
openapi_tools = p.get('tools', [])
for t in openapi_tools:
    if t.get("type") == "function" and "function" in t:
        fn = t["function"]
        anthropic_tools.append({
            "name": fn.get("name"),
            "description": fn.get("description", ""),
            "input_schema": fn.get("parameters", {"type": "object", "properties": {}})
        })

MAX = int(os.environ.get('AG_MAX_CONTEXT_CHARS', 120000)) if 'os' in sys.modules else 120000
try: MAX = int(os.environ.get('AG_MAX_CONTEXT_CHARS', 120000))
except Exception: pass

total = sum(len(json.dumps(m, ensure_ascii=False)) for m in non_system) + len(' '.join(system_parts))
if total > MAX:
    keep_tail = min(10, len(non_system))
    non_system = non_system[-keep_tail:]
    print('[adapter] truncated messages', file=sys.stderr)

req = {
    'model': model,
    'max_tokens': max_tokens,
    'messages': non_system
}
if system_parts: req['system'] = '\n'.join(system_parts)
if p.get('stream'): req['stream'] = p.get('stream')
if anthropic_tools: req['tools'] = anthropic_tools
if temperature is not None: req['temperature'] = temperature

# Map tool_choice
if p.get('tool_choice'):
    tc = p['tool_choice']
    if tc == 'auto': req['tool_choice'] = {"type": "auto"}
    elif tc == 'required': req['tool_choice'] = {"type": "any"}
    elif isinstance(tc, dict) and 'function' in tc:
        req['tool_choice'] = {"type": "tool", "name": tc['function'].get('name')}

print(json.dumps(req, ensure_ascii=False))
EOFPY

MANAGER_BASE_URL="${AG_MANAGER_BASE_URL:-http://127.0.0.1:8045}"
MANAGER_API_KEY="${AG_MANAGER_API_KEY:-}"
FALLBACK_BASE_URL="${AG_CLAUDE_PROXY_BASE_URL:-http://127.0.0.1:8080}"
FALLBACK_API_KEY="${AG_CLAUDE_PROXY_API_KEY:-test}"

call_anthropic_compat() {
  local base_url="$1"
  local api_key="$2"
  local tmpfile
  tmpfile=$(mktemp)

  # Stealth Mode: Add human-readable jitter before sending request
  sleep $(awk 'BEGIN{srand(); print 0.3 + rand() * 1.2}')
  
  set +e
  curl -sS --connect-timeout 5 --max-time 120 "${base_url%/}/v1/messages" \
    -H 'Content-Type: application/json' \
    -H "Authorization: Bearer ${api_key}" \
    -H "x-api-key: ${api_key}" \
    -H 'anthropic-version: 2023-06-01' \
    -d @"$extracted_file" > "$tmpfile"
  local code=$?
  set -e

  cat "$tmpfile"
  rm -f "$tmpfile"
  return $code
}

raw=''
# Primary: local 8080 proxy
if raw=$(call_anthropic_compat "$FALLBACK_BASE_URL" "$FALLBACK_API_KEY"); then
  :
else
  raw=''
fi

primary_raw="$raw"

# If primary returned a structured upstream error (e.g. quota exhausted), allow fallback to manager
if [[ -n "$raw" ]] && echo "$raw" | grep -q '"error"'; then
  raw=''
fi

# Fallback: manager 8045 (only when configured)
if [[ -z "$raw" && -n "$MANAGER_API_KEY" ]]; then
  if raw=$(call_anthropic_compat "$MANAGER_BASE_URL" "$MANAGER_API_KEY"); then
    :
  else
    raw=''
  fi
fi

# If fallback was skipped or failed, but primary had an error, return primary error!
if [[ -z "$raw" && -n "$primary_raw" ]]; then
  raw="$primary_raw"
fi

if [[ -z "$raw" ]]; then
  python3 - <<PY
import json
print(json.dumps({"error":"ag_service_unreachable","detail":"primary 8080 and fallback 8045 both unreachable/failed","status":502}, ensure_ascii=False))
PY
  exit 0
fi

# Save raw to tmpfile for safe Python parsing (avoids quote issues in responses)
_tmpraw=$(mktemp)
echo "$raw" > "$_tmpraw"

python3 - "$_tmpraw" <<'PY'
import json, sys
with open(sys.argv[1], 'r') as f:
    raw = f.read().strip()
import os; os.unlink(sys.argv[1])

try:
    obj = json.loads(raw)
except Exception:
    print(json.dumps({"error":"ag_non_json","detail":raw[:500],"status":502}, ensure_ascii=False)); raise SystemExit(0)

if isinstance(obj, dict) and obj.get('error'):
    err = obj.get('error')
    msg = err.get('message') or str(err) if isinstance(err, dict) else str(err)
    etype = err.get('type') or 'ag_error' if isinstance(err, dict) else 'ag_error'
    print(json.dumps({"error":etype,"detail":msg,"status":502}, ensure_ascii=False)); raise SystemExit(0)

text = ''
tool_calls = []
for block in obj.get('content', []):
    if isinstance(block, dict):
        if block.get('type') == 'text':
            text += block.get('text', '')
        elif block.get('type') == 'tool_use':
            tool_calls.append({
                "id": block.get('id', 'call_ag'),
                "type": "function",
                "function": {
                    "name": block.get('name'),
                    "arguments": json.dumps(block.get('input', {}), ensure_ascii=False)
                }
            })

usage0 = obj.get('usage', {}) if isinstance(obj, dict) else {}
usage = {
  "prompt_tokens": int(usage0.get('input_tokens',0) or 0),
  "completion_tokens": int(usage0.get('output_tokens',0) or 0),
  "total_tokens": int((usage0.get('input_tokens',0) or 0)+(usage0.get('output_tokens',0) or 0)),
}

out_data = {"text": text, "usage": usage}
if tool_calls:
    out_data["tool_calls"] = tool_calls
elif not text.strip():
    print(json.dumps({"error":"empty_response","detail":"upstream returned empty content","status":502}, ensure_ascii=False)); raise SystemExit(0)

print(json.dumps(out_data, ensure_ascii=False))
PY

