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
# Anthropic API requires system as a top-level field, NOT in messages array
python3 - "$payload_file" > "$extracted_file" <<'EOFPY'
import sys, json, os
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    p = json.load(f)

# Strip ag/ prefix and normalize dots to dashes for Anthropic API
raw_model = p.get('model', 'claude-sonnet-4-6')
model = raw_model.replace('ag/', '').replace('.', '-')
msgs = p.get('messages', [])
max_tokens = int(p.get('max_tokens', 1024) or 1024)

# Separate system/developer messages from non-system messages
system_parts = []
non_system = []
for m in msgs:
    role = (m.get('role') or 'user').strip()
    c = m.get('content', '')
    if isinstance(c, list):
        c = ' '.join(item.get('text','') for item in c if isinstance(item, dict))
    if c is None:
        c = ''

    if role in ('system', 'developer'):
        if c:
            system_parts.append(str(c))
        continue

    # Anthropic messages only supports user/assistant roles
    out_role = role if role in ('user','assistant') else 'user'
    out_content = str(c).strip()
    if not out_content:
        continue
    non_system.append({'role': out_role, 'content': out_content})

# Context overflow protection: truncate if too large
# Note: Since the prompt can be very large, sys.stderr logging helps track truncation without breaking stdout JSON.
MAX = int(os.environ.get('AG_MAX_CONTEXT_CHARS', 120000)) if 'os' in sys.modules else 120000
import os
try:
    MAX = int(os.environ.get('AG_MAX_CONTEXT_CHARS', 120000))
except Exception:
    pass

total = sum(len(json.dumps(m, ensure_ascii=False)) for m in non_system) + len(' '.join(system_parts))
if total > MAX:
    keep_tail = min(10, len(non_system))
    non_system = non_system[-keep_tail:]
    print('[adapter] truncated messages', file=sys.stderr)

# Build proper Anthropic Messages API request
req = {
    'model': model,
    'max_tokens': max_tokens,
    'messages': non_system
}
# System prompt goes as top-level field, NOT in messages
if system_parts:
    req['system'] = '\n'.join(system_parts)

# We preserve stream if it's there (useful for OpenClaw)
if p.get('stream'):
    req['stream'] = p.get('stream')

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
    if isinstance(err, dict):
      etype = err.get('type') or 'ag_error'
      msg = err.get('message') or str(err)
    else:
      etype = 'ag_error'
      msg = str(err)
    print(json.dumps({"error":etype,"detail":msg,"status":502}, ensure_ascii=False)); raise SystemExit(0)

text=''
for block in obj.get('content',[]):
    if isinstance(block,dict) and block.get('type')=='text':
        text += block.get('text','')
usage0=obj.get('usage',{}) if isinstance(obj,dict) else {}
usage={
  "prompt_tokens": int(usage0.get('input_tokens',0) or 0),
  "completion_tokens": int(usage0.get('output_tokens',0) or 0),
  "total_tokens": int((usage0.get('input_tokens',0) or 0)+(usage0.get('output_tokens',0) or 0)),
}
if not (text or '').strip():
    print(json.dumps({"error":"empty_response","detail":"upstream returned empty text content","status":502}, ensure_ascii=False)); raise SystemExit(0)
print(json.dumps({"text": text, "usage": usage}, ensure_ascii=False))
PY

