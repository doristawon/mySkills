---
description: 替 AGProxy 與 OpenClaw 配置混血容錯路由 (Hybrid Routing) 與擬真防封鎖 (Stealth Mode) 機制
---

# AGProxy Hybrid Routing & Stealth Mode 設定指南

這是一套為了突破單一 API Key 或登入帳號的額度限制，並同時降低被模型原廠封鎖機率的高階設定流程。透過本技巧，您可以讓 OpenClaw 擁有「**主帳號優先 + 多帳號資源池無縫備援**」的強大能力。

## 核心架構理念

* **去中心化配置：** 不要把 Fallbacks 邏輯寫在 `openclaw.json`。讓 OpenClaw 的所有 Agent 都**純粹且唯一地綁定到 `agproxy`** (Port: 4010)。
* **內部智能降級 (Graceful Degradation)：** 當 `agproxy` 在呼叫本機端 CLI 或主要端點遇到 限流 (429) 或其他致命錯誤時，由 `agproxy` 的 `server.js` 內部自動攔截錯誤，並在背景發起對 `Antigravity Manager` (Port: 8045 多帳號池) 的備援請求。對前台的 Discord 使用者而言，不會感受到任何伺服器當機或請求失敗。
* **人機行為擬真 (Stealth Jitter)：** 自動化腳本在呼叫終端機 CLI 時，加入極低延遲的亂數暫停 (例如 0.3 到 1.5 秒)，打破機械式的固定呼叫頻率，偽裝成人類手打指令，以符合系統流量分析的安全特徵。

---


### v2.0 更新日誌 (2026/03/04)
- **修正 Gemini CLI Exit Code Bug**：在 `gemini_cli_adapter.sh` 加入 `grep` 攔截 `ModelNotFoundError` 與 `GoogleQuotaError`，將 Exit Code 0 強制轉為 1 以觸發 Manager 備援。
- **支援 Tool Calls 轉發**：修改 `server.js`，在觸發 Fallback 路線時，將 `body.tools` 帶入，確保 Manager 備援依然具備工具操作能力。
- **原生 Gemini 3.1 支援**：修正 `ag/gemini-3.1-pro` 路由轉換，不再被降級為 2.5 系列。
- **開放多模態**：確認支援圖片與語音辨識 (`audio` payload)。


## 實作步驟

### 1. 收束 `openclaw.json` (清空外部 Fallbacks)
進入 OpenClaw 的設定檔，將所有需要受保護的頻道大腦，將其 `primary` 統一指向 `agproxy/...`，並且**清空 `fallbacks: []` 陣列**。
例如：
```json
{
  "id": "discord-gemini-pro",
  "name": "discord-gemini-pro",
  "model": {
    "primary": "agproxy/ag/gemini-3.1-pro",
    "fallbacks": []
  }
}
```

### 2. 於 AGProxy 的 `server.js` 內實作攔截備援
目標路徑：`$workspace/tools/antigravity-proxy/server.js`

在處理 `/v1/chat/completions` API 請求的地方，在 `const backendResp = await runBackend(...)` 執行完畢後加入錯誤攔截邏輯：
```javascript
let backendResp = await runBackend({ ... }, backendCmd);

// 如果 Primary 失敗 (可能是 Quota 用盡)，啟動 Antigravity Manager 無縫備援
if (backendResp && backendResp.error) {
  if (!model.includes('claude') && !String(mappedModel).includes('claude')) {
    console.log(`[AGProxy] Primary backend failed. Falling back to Antigravity Manager API...`);
    try {
      const fbResp = await fetch("http://127.0.0.1:8045/v1/chat/completions", {
        method: "POST",
        headers: { "Content-Type": "application/json", "Authorization": "Bearer YOUR_MANAGER_API_KEY_HERE" },
        body: JSON.stringify({ model: mappedModel, messages: body.messages || [], temperature: body.temperature, max_tokens: body.max_tokens, stream: false })
      });
      if (fbResp.ok) {
        const fbData = await fbResp.json();
        const fbText = fbData?.choices?.[0]?.message?.content;
        if (fbText) {
            console.log(`[AGProxy] Fallback successful! Returning manager response.`);
            backendResp = { text: fbText, usage: fbData.usage || {} };
            delete backendResp.error;
            delete backendResp.status;
            delete backendResp.detail;
        }
      }
    } catch (e) {
      console.error("[AGProxy] Manager fallback requested but failed entirely:", e);
    }
  }
}
```

### 3. 加入 Stealth Jitter (偽裝人類延遲)
找到 AGProxy 對接底層邏輯的 Adapters（例如 `gemini_cli_adapter.sh` 或是 `claude_via_antigravity_proxy_adapter.sh`）。
在發起終端機指令或 `curl` 的前置步驟，呼叫隨機 Sleep 函數：

```bash
# Stealth Mode: Add human-readable jitter (0.3s to 1.5s)
sleep $(awk 'BEGIN{srand(); print 0.3 + rand() * 1.2}')
```

### 4. 重啟測試
完成上述修改後，請務必重新啟動背景代理服務。
```bash
systemctl --user restart agproxy openclaw-gateway
```
如此一來，OpenClaw 將變得異常強韌且不可阻擋。
