---
name: hybrid-model-routing
description: 混合模型路由與智慧分流系統。透過 agproxy 中轉服務，實現 Gemini CLI 用完額度後自動 fallback 到 Antigravity Manager；Claude 透過 claude-proxy（8080→8045）雙層保障。2026-03-06 新增智慧分流：有 tools 直連 Manager，無 tools 走 CLI 省額度。
---

# 混合模型路由技能 (Hybrid Model Routing)

> **最後更新：2026-03-06**
> 本次更新包含 Bug Fix 與 Smart Routing（智慧分流）兩項重要改動。

## 架構總覽

```
OpenClaw Discord Bot
        |
        v
  [agproxy Port 4010]  ─── 自建 Node.js 中轉
    ag/gemini-* (有 tools)   -> Manager 8045  [Smart Route ✨]
    ag/gemini-* (無 tools)   -> Gemini CLI   [省 Manager 額度]
    ag/claude-*              -> Claude Proxy Adapter → 8080 → 8045 fallback

  [agmanager/* 直連 Port 4010]  ─── 跳過 CLI，直接走 Manager
    agmanager/gemini-3-flash / gemini-3.1-pro

  [agproxy/agmanager direct bypass Port 4010]
    isDirectManager 路徑：Manager primary → CLI fallback
```

---

## 智慧分流邏輯（2026-03-06 新增）

### 問題背景
舊邏輯中 `ag/*` 一律先走 Gemini CLI → CLI 無法處理 tool_calls → error → Manager 備援
結果：每次 tool_calls 請求都浪費 7-10s 在 CLI 嘗試後才得到 Manager 回應。

### 新路由規則 (`server.js` 智慧路由分支)

```
ag/* 請求進入 AGProxy
        |
        v
  有 function tools ? ─── 是（Gemini）───> Manager 8045 直連 (2-4s) ✅
        |                                      |失敗
        |                                      v
        |                              CLI Fallback
        |
        └── 否（Gemini 純文字）──────> Gemini CLI (省 Manager 額度)
            是（Claude）─────────────> Claude Proxy Adapter
```

### 驗證基準（改後掃描結果）

| 路徑 | 有 tools | 耗時 | 結果 |
|------|---------|------|------|
| AGP/ag/gemini-3-flash + tools | ✅ Manager | 3.0s | tool_calls OK |
| AGP/ag/gemini-3-flash + 純文字 | Gemini CLI | 12.2s | text OK |
| AGP/ag/claude-sonnet-4.6 + tools | Claude Adapter | 3.5s | tool_calls OK |
| AGP/agmgr/gemini-3-flash + tools | Manager 直連 | 2.4s | tool_calls OK |
| AGP/agmgr/gemini-3.1-pro + tools | Manager 直連 | 3.6s | tool_calls OK |
| AGP/ag/claude-opus-4.6-thinking | Claude Adapter | 4.6s | tool_calls OK |

---

## Bug Fix：空文字被替換為罐頭回覆（2026-03-06 修復）

### 症狀
channel agents 即使在模型成功回傳 `tool_calls` 時，仍然只回覆
`'收到，我在，正在處理。'` 而不執行工具。

### 根因
`server.js` 的空文字處理邏輯在 `tool_calls` 有值時也會觸發：
```javascript
// 舊 — 有 bug：有 tool_calls 時 content 本來就是空的，卻被替換
if (!trimmed || trimmed === 'NO_REPLY') {
  text = '收到，我在，正在處理。';  // ← 錯誤地覆蓋了空 content
}
```

### 修復
```javascript
// 新 — 正確：只在沒有 tool_calls 時才注入罐頭文字
if ((!trimmed || trimmed === 'NO_REPLY') && !backendResp.tool_calls) {
  text = '收到，我在，正在處理。';
}
```

---

## 各服務說明

### 1. agproxy（Port 4010）

**路徑**：`~/.openclaw/workspace/tools/antigravity-proxy/`
**啟動**：`start-agproxy.sh`
**Systemd**：`agproxy.service`

#### 關鍵環境變數

```bash
AG_PROXY_PORT=4010
AG_PROXY_BACKEND_CMD='bash .../adapters/gemini_cli_adapter.sh'
AG_PROXY_BACKEND_CLAUDE_CMD='bash .../adapters/claude_via_antigravity_proxy_adapter.sh'
GEMINI_API_KEY='your-gemini-api-key'
AG_PROXY_MODEL_MAP='{
  "ag/gemini-3-flash":           "gemini-3-flash",
  "ag/gemini-3.1-pro":           "gemini-3.1-pro-high",
  "ag/claude-sonnet-4.6":        "claude-sonnet-4-6",
  "ag/claude-opus-4.6-thinking": "claude-opus-4-6-thinking",
  "ag/nano-banana-2":            "gemini-2.5-flash-image",
  "ag/media-understand-v1":      "gemini-3.1-pro-high"
}'
```

#### 路由優先序

| Model 前綴 | tools 有無 | 路由 |
|------------|-----------|------|
| `agmanager/*` | 任意 | Manager 直連 8045（primary），CLI 為備援 |
| `ag/gemini-*` | **有** | Manager 直連 8045（smart route）|
| `ag/gemini-*` | **無** | Gemini CLI 省額度 |
| `ag/claude-*` | 任意 | Claude Proxy Adapter → 8080 → 8045 |

---

### 2. antigravity-claude-proxy（Port 8080）

**安裝**：`npm install -g antigravity-claude-proxy`
**Systemd**：`ag-proxy.service`

- OAuth Token 來源：`~/.config/Antigravity/User/globalStorage/state.vscdb`
- 支援最多 10 個帳號輪換，429 自動退避換帳號

```bash
systemctl --user status ag-proxy.service
antigravity-claude-proxy accounts list
```

---

### 3. Antigravity Manager（Port 8045）

**GitHub**：https://github.com/lbjlaq/Antigravity-Manager
**最低版本**：v4.1.28（修復 Gemini 模型 400 錯誤）

| 模型 ID | 說明 |
|---------|------|
| `gemini-3-flash` | Gemini 3 Flash |
| `gemini-3.1-pro-high` | Gemini 3.1 Pro 高品質 |
| `gemini-3-pro-image` | Pro 圖片生成（Imagen 3）|
| `claude-sonnet-4-6` | Claude Sonnet 4.6 |
| `claude-opus-4-6-thinking` | Claude Opus 思考模式 |

---

## OpenClaw providers 設定

```json
"agproxy": {
  "baseUrl": "http://127.0.0.1:4010/v1",
  "apiKey": "change-me",
  "api": "openai-completions"
},
"agmanager": {
  "baseUrl": "http://127.0.0.1:4010/v1",
  "apiKey": "change-me",
  "api": "openai-completions"
},
"ag-manager": {
  "baseUrl": "http://127.0.0.1:8045/v1",
  "apiKey": "your-manager-api-key",
  "api": "openai-completions"
}
```

## Discord Channel → Agent → Model 對應

| 頻道 | Agent | Primary Model | 路由 |
|------|-------|---------------|------|
| 一般對話 | discord-claude-ag | `agproxy/ag/claude-sonnet-4.6` | Claude Adapter |
| Pro 對話 | discord-gemini-pro | `agproxy/agmanager/gemini-3.1-pro` | Manager 直連 |
| Flash 對話 | discord-gemini-flash | `agproxy/agmanager/gemini-3-flash` | Manager 直連 |
| #nano-banana | discord-nano-banana | `agproxy/agmanager/gemini-3-pro-image` | Manager 直連 |
| #免費產圖 | discord-free-image | `agproxy/agmanager/gemini-3-flash` | Manager 直連 |

---

## 快速診斷

```bash
# 確認服務
systemctl --user status agproxy.service         # 4010
systemctl --user status ag-proxy.service        # 8080

# 測試 smart routing（有 tools）
python3 /tmp/test_smart.py

# 全面掃描 tool_calls
python3 /tmp/scan_models.py

# 重啟 agproxy（修改 server.js 後）
systemctl --user restart agproxy
```

---

## 檔案結構

```
skills/hybrid-model-routing/
├── SKILL.md                          # 本文件
└── configs/
    ├── start-agproxy.sh              # agproxy 啟動腳本範本
    └── openclaw-providers.json       # openclaw.json providers 區段範本
```
