---
name: agent-proactive-reporting
description: Agent 主動進度追蹤與反幻覺機制。透過 cron.add heartbeat 實現 subagent 自動輪詢，搭配反幻覺規則 7-8-9 杜絕記憶幻覺與偽造輸出。2026-03-07 建立，同日修正 cron API 為正確格式。
---

# Agent 主動進度追蹤技能 (Proactive Reporting) v2

> **建立日期：2026-03-07 | 更新日期：2026-03-07**
> 解決 OpenClaw agent 無法主動回報進度的架構限制，並加入反幻覺防護。

## 問題背景

### 1. 無法主動回報進度
OpenClaw 是 **request-driven** 架構：模型回應一次後 turn 結束，無法自發地在 30 秒後重新啟動。
所以即使 systemPrompt 寫了「每 30 秒 poll」，模型的 turn 結束後就不會再自動觸發。

### 2. 記憶幻覺
模型從 memory 取回過時/錯誤資訊（如把 4080 記成 3060），並以「✅ 執行證據」的格式呈現，用戶無法辨別真偽。

---

## 解法一：Cron Heartbeat（主動進度追蹤）

利用 OpenClaw 內建的 `cron` 工具（`group:automation`），讓系統定期送 system event 觸發 agent 重新 poll subagent 狀態。

### 流程圖

```
用戶下任務
    ↓
Agent 呼叫 sessions_spawn(worker)
    ↓
Agent 呼叫 cron.add (正確 JSON 格式，見下方)
    ↓
⚠️ 必須檢查 cron.add 回傳！error → 修正 JSON 重試
    ↓
每 30 秒系統送 heartbeat system event
    ↓
Agent 收到 heartbeat → session_status("worker") → message 推送進度
    ↓
done/error → cron.remove({ "jobId": "<jobId>" }) → 推送完成報告
```

### ⚠️ 正確的 cron.add JSON 格式

```json
{
  "name": "task-heartbeat",
  "schedule": { "kind": "every", "everyMs": 30000 },
  "sessionTarget": "main",
  "wakeMode": "now",
  "payload": { "kind": "systemEvent", "text": "🔄 heartbeat: 請 poll subagent 狀態並回報進度" }
}
```

**常見錯誤（已修正）：**

| ❌ 錯誤 API | ✅ 正確 API |
|------------|-----------|
| `cron.schedule(...)` | `cron.add({ JSON })` |
| `cron.cancel("name")` | `cron.remove({ "jobId": "..." })` |
| `interval="30s"` | `"schedule": { "kind": "every", "everyMs": 30000 }` |
| 不檢查回傳結果 | 必須檢查 error → 修正重試 |

### 在 SOUL.md 中的 Dispatcher 協議

```
步驟 3 — 設定 Heartbeat（自動追蹤進度）
  spawn 完成後，立刻呼叫 cron.add 工具設定定期追蹤。正確 JSON 格式：
    {
      "name": "task-heartbeat",
      "schedule": { "kind": "every", "everyMs": 30000 },
      "sessionTarget": "main",
      "wakeMode": "now",
      "payload": { "kind": "systemEvent", "text": "🔄 heartbeat: 請 poll subagent 狀態並回報進度" }
    }
  ⚠️ 呼叫後必須檢查回傳結果！若回傳 error → 立刻修正 JSON 重試，禁止假裝成功。
  成功後記下回傳的 jobId，後續清理時需要。

步驟 4 — 收到 heartbeat 時的動作
  每次收到 heartbeat system event 時，必須：
    1) 呼叫 session_status("worker-{task_id}") 取得真實狀態
    2) 根據狀態回報：
       → running：用 message 推送進度更新（含進度條）
       → done：解析輸出 → message 推送 ✅ 完成報告 → cron.remove({ "jobId": "<jobId>" })
       → error：進入協商流程
    3) 禁止忽略 heartbeat 訊息！收到就必須 poll
```

---

## 解法二：反幻覺規則 7-8-9

在所有 agent 的 systemPrompt「任務執行硬規則」中追加：

```
7) 禁止記憶幻覺：回報硬體規格/系統狀態/版本號/IP 等即時數據時，
   必須當場 exec 取得真實輸出，禁止從記憶或訓練資料推斷填入
8) 禁止偽造輸出：禁止用 codeblock 模擬工具回傳。
   真實結果由系統附加，不需自行產生
9) 引用必真實：「✅ 執行證據」必須摘錄系統實際回傳的輸出（至少 1 行原文），
   不得編撰。若無法確認，必須明說「未確認，需重新執行」
```

---

## 部署方式

### 1. Gateway 設定（必要！）

```json
// openclaw.json 頂層
{
  "cron": {
    "enabled": true,
    "sessionRetention": "24h",
    "runLog": { "maxBytes": "2mb", "keepLines": 2000 }
  },
  "tools": {
    "profile": "full",
    "allow": ["group:automation", "apply_patch"]
  }
}
```

> **不加 `cron.enabled` 和 `tools.allow: ["group:automation"]`，cron 工具會被 Gateway 標記為 "unknown entry" 而無法使用！**

### 2. Agent 工具權限

所有需要 heartbeat 的 agent 必須包含 `"cron"` 在 `tools.alsoAllow`：

```json
"tools": {
  "alsoAllow": ["cron", "sessions_spawn", "message", ...]
}
```

### 3. 更新 SOUL.md + systemPrompts

- SOUL.md Dispatcher 協議步驟 3-4 使用 cron.add JSON 格式
- 所有 channel systemPrompts 包含 cron.add 指引 + 規則 7-8-9

### 4. 重啟 Gateway

```bash
systemctl --user restart openclaw-gateway
```

---

## 驗證方式

在 Discord/Telegram 下一個長任務，觀察：
1. Agent 是否真正呼叫 `exec` 而非從記憶回答
2. 是否用 `cron.add` 設定 heartbeat（檢查 JSON 格式正確）
3. 是否檢查 `cron.add` 回傳結果
4. 是否每 30 秒自動推送進度更新
5. 完成後是否主動推送 ✅ 報告並呼叫 `cron.remove`
