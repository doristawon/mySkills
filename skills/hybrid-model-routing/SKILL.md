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
```

## 智慧分流邏輯（2026-03-06 新增）

### 新路由規則

```
ag/* 請求進入 AGProxy
  有 function tools? 是(Gemini) → Manager 8045 直連 (2-4s)  失敗 → CLI
                     否(Gemini) → Gemini CLI (省 Manager 額度)
                     是(Claude) → Claude Proxy Adapter
```

### 驗證結果

| 路徑 | tools | 耗時 | 結果 |
|------|-------|------|------|
| AGP/ag/gemini-3-flash + tools | ✅ Manager | 3.0s | tool_calls OK |
| AGP/ag/gemini-3-flash + 純文字 | Gemini CLI | 12.2s | text OK |
| AGP/ag/claude-sonnet-4.6 + tools | Claude Adapter | 3.5s | tool_calls OK |
| AGP/agmgr/gemini-3-flash + tools | Manager 直連 | 2.4s | tool_calls OK |
| AGP/agmgr/gemini-3.1-pro + tools | Manager 直連 | 3.6s | tool_calls OK |

## Bug Fix：空文字被替換為罐頭回覆（2026-03-06）

### 症狀
channel agents 回傳 tool_calls 時仍只顯示 '收到，我在，正在處理。'

### 修復 (server.js)
```javascript
// 舊（有 bug）
if (!trimmed || trimmed === 'NO_REPLY') {
  text = '收到，我在，正在處理。';
}

// 新（正確）
if ((!trimmed || trimmed === 'NO_REPLY') && !backendResp.tool_calls) {
  text = '收到，我在，正在處理。';
}
```

## agproxy 路由優先序

| Model 前綴 | tools | 路由 |
|------------|-------|------|
| agmanager/* | 任意 | Manager 8045 primary，CLI 備援 |
| ag/gemini-* | 有 | Manager 8045 smart route |
| ag/gemini-* | 無 | Gemini CLI 省額度 |
| ag/claude-* | 任意 | Claude Proxy → 8080 → 8045 |

## 各服務

| 服務 | Port | Systemd |
|------|------|---------|
| agproxy | 4010 | agproxy.service |
| claude-proxy | 8080 | ag-proxy.service |
| Manager | 8045 | (GUI) |

## 快速診斷

```bash
systemctl --user restart agproxy   # 重啟 agproxy
systemctl --user status agproxy    # 檢查狀態
python3 /tmp/test_smart.py          # 測試智慧路由
python3 /tmp/scan_models.py         # 全面掃描
```
