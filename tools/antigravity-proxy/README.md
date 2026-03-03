# Antigravity Proxy (v1)

OpenAI-compatible proxy for OpenClaw:
- `GET /v1/models`
- `POST /v1/chat/completions`
- `GET /health`

## 1) Start (mock mode)

```bash
cd /home/chris93/.openclaw/workspace/tools/antigravity-proxy
AG_PROXY_PORT=4010 \
AG_PROXY_API_KEY='change-me' \
AG_PROXY_BACKEND_CMD='bash /home/chris93/.openclaw/workspace/tools/antigravity-proxy/adapters/mock_adapter.sh' \
node server.js
```

## 2) Test

```bash
curl -s http://127.0.0.1:4010/v1/models | jq

curl -s http://127.0.0.1:4010/v1/chat/completions \
  -H 'Authorization: Bearer change-me' \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "ag/gemini-3-flash",
    "messages": [{"role":"user","content":"hello"}]
  }' | jq
```

## 3) Switch to Antigravity CLI adapter

```bash
AG_PROXY_BACKEND_CMD='bash /home/chris93/.openclaw/workspace/tools/antigravity-proxy/adapters/antigravity_cli_adapter.sh'
```

Then set CLI command template (example only, adjust to your real CLI flags):

```bash
export AG_PROXY_AG_CMD_TEMPLATE='antigravity chat --model "{{model}}" --prompt-file "{{prompt_file}}" --output json'
```

## 4) OpenClaw provider example

In `openclaw.json` add a provider:

```json
{
  "models": {
    "providers": {
      "agproxy": {
        "baseUrl": "http://127.0.0.1:4010/v1",
        "apiKey": "change-me",
        "api": "openai-completions",
        "models": [
          {"id":"ag/gemini-3-flash","name":"AG Gemini 3 Flash","reasoning":false,"input":["text"],"cost":{"input":0,"output":0,"cacheRead":0,"cacheWrite":0},"contextWindow":131072,"maxTokens":8192},
          {"id":"ag/gemini-3.1-pro","name":"AG Gemini 3.1 Pro","reasoning":true,"input":["text"],"cost":{"input":0,"output":0,"cacheRead":0,"cacheWrite":0},"contextWindow":200000,"maxTokens":8192}
        ]
      }
    }
  }
}
```

## Notes
- v1 focuses on non-streaming response path first.
- Keep proxy local (`127.0.0.1`) + API key auth.
- Add rate limit / queue / circuit breaker in v2.
