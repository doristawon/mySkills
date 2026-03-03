#!/bin/bash
# agproxy 啟動腳本範本
# 路徑：~/.openclaw/workspace/tools/antigravity-proxy/start-agproxy.sh

echo "Stopping old agproxy server..."
pkill -f "node server.js" || true
sleep 1

cd /home/chris93/.openclaw/workspace/tools/antigravity-proxy

export AG_PROXY_PORT=4010
export AG_PROXY_BACKEND_CMD='bash /home/chris93/.openclaw/workspace/tools/antigravity-proxy/adapters/gemini_cli_adapter.sh'
export AG_PROXY_BACKEND_CLAUDE_CMD='bash /home/chris93/.openclaw/workspace/tools/antigravity-proxy/adapters/claude_via_antigravity_proxy_adapter.sh'
export GEMINI_API_KEY='your-gemini-api-key-here'
export AG_PROXY_IMAGE_PLANNER_MODEL=gemini-3.1-pro-high

export AG_PROXY_MODEL_MAP='{"ag/gemini-3-flash":"gemini-3-flash","ag/gemini-3.1-pro":"gemini-3.1-pro-high","ag/claude-sonnet-4.6":"claude-sonnet-4-6","ag/claude-opus-4.6-thinking":"claude-opus-4-6-thinking","ag/nano-banana-2":"gemini-2.5-flash-image","ag/media-understand-v1":"gemini-3.1-pro-high"}'

export AG_MANAGER_API_KEY='your-manager-api-key-here'

echo "Starting agproxy server..."
exec node server.js
