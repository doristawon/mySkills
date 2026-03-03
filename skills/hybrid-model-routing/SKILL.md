---
name: hybrid-model-routing
description: 混合模型路由與 Fallback 系統。透過 agproxy 中轉服務，實現 Gemini CLI 用完額度後自動 fallback 到 Antigravity Manager 多帳號輪詢；Claude 透過 antigravity-claude-proxy（8080）主路線與 Manager（8045）雙層保障。
---

# 混合模型路由技能 (Hybrid Model Routing)

## 架構總覽

本技能記錄了一套以 **OpenClaw** 為核心的混合 AI 模型路由系統，整合三個服務層。

```
OpenClaw Discord Bot
        |
        v
  [agproxy Port 4010]  ─── 自建 Node.js 中轉
    ag/gemini-*  ->  Gemini CLI (Primary)
                         | 失敗/rate limit
                         v
             Antigravity Manager (8045)
             gemini-3.1-pro-high / gemini-3-flash

    ag/claude-*  ->  claude_via_antigravity_proxy_adapter.sh
                         |
                [Port 8080]──[Port 8045 fallback]

  [ag-manager 直連 Port 8045]  ─── 不經 agproxy
    gemini-3-pro-image (nano-banana 生圖)
```

---

## 各服務說明

### 1. agproxy（Port 4010）

**路徑**：`~/.openclaw/workspace/tools/antigravity-proxy/`
**啟動**：`start-agproxy.sh`
**Systemd**：`antigravity-proxy.service`

#### 關鍵環境變數

```bash
AG_PROXY_PORT=4010
AG_PROXY_MODEL_MAP='{
  "ag/gemini-3-flash":          "gemini-3-flash",
  "ag/gemini-3.1-pro":          "gemini-3.1-pro-high",
  "ag/claude-sonnet-4.6":       "claude-sonnet-4-6",
  "ag/claude-opus-4.6-thinking":"claude-opus-4-6-thinking",
  "ag/nano-banana-2":           "gemini-2.5-flash-image",
  "ag/media-understand-v1":     "gemini-3.1-pro-high"
}'
AG_MANAGER_API_KEY='your-manager-api-key'
AG_PROXY_IMAGE_PLANNER_MODEL=gemini-3.1-pro-high
```

#### Gemini Fallback 邏輯（server.js）

```
請求 ag/gemini-*
  -> Gemini CLI (gemini_cli_adapter.sh)
     成功 -> 返回
     失敗 / gemini_cli_failed
  -> POST http://127.0.0.1:8045/v1/chat/completions
     model: "gemini-3.1-pro-high" (由 MODEL_MAP 決定)
     成功 -> 返回
     失敗 -> HTTP 502
```

> 注意：Claude 型號不觸發 Manager fallback，由 adapter.sh 內部處理

---

### 2. antigravity-claude-proxy（Port 8080）

**安裝**：`npm install -g antigravity-claude-proxy`
**Systemd**：`ag-proxy.service`

模擬 Antigravity VSCode 插件，從本機 SQLite DB 取 OAuth Token：

- 路徑：`~/.config/Antigravity/User/globalStorage/state.vscdb`
- 支援最多 10 個帳號輪換
- 遇 429 自動退避換帳號

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
| `gemini-3-pro-image` | Pro 圖片生成（Imagen 3） |
| `claude-sonnet-4-6` | Claude Sonnet 4.6 |
| `claude-opus-4-6-thinking` | Claude Opus 思考模式 |

**v4.1.27 已知 Bug**：對 Gemini 模型注入 Claude 專用的 `thinkingLevel`，導致 `400 INVALID_ARGUMENT`。升級到 v4.1.28+ 即可。

---

## OpenClaw models.providers 設定

```json
"agproxy": {
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

## Discord Channel -> Agent -> Model 對應

| 頻道 | Agent | Primary Model | 路由 |
|------|-------|---------------|------|
| 一般對話 | discord-claude-ag | `agproxy/ag/claude-sonnet-4.6` | 8080->8045 |
| Pro 對話 | discord-gemini-pro | `agproxy/ag/gemini-3.1-pro` | CLI->8045 |
| Flash 對話 | discord-gemini-flash | `agproxy/ag/gemini-3-flash` | CLI->8045 |
| #nano-banana | discord-nano-banana | `ag-manager/gemini-3-pro-image` | 直連 Manager |
| #免費產圖 | discord-free-image | `agproxy/ag/gemini-3-flash` | CLI->8045 |

---

## 快速診斷

```bash
# 確認三服務
systemctl --user status ag-proxy.service           # 8080
systemctl --user status antigravity-proxy.service  # 4010
# 8045 = Manager GUI 確認系統托盤

# 測試 Gemini fallback
python3 test_proxy.py

# 測試 Manager 直連
python3 test_manager2.py

# 查看 agproxy 日誌
tail -f ~/.openclaw/workspace/tools/antigravity-proxy/proxy_debug.log
```

---

## 檔案結構

```
skills/hybrid-model-routing/
├── SKILL.md
└── configs/
    ├── start-agproxy.sh         # agproxy 啟動腳本範本
    └── openclaw-providers.json  # openclaw.json providers 區段範本
```
