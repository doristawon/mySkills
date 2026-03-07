---
name: agent-proactive-reporting
description: Agent 主動進度追蹤與反幻覺機制。透過 cron heartbeat 實現 subagent 自動輪詢，搭配反幻覺規則 7-8-9 杜絕記憶幻覺與偽造輸出。
---

# Agent 主動進度追蹤技能 (Proactive Reporting)

> **建立日期：2026-03-07**

## 問題背景

### 1. 無法主動回報進度
OpenClaw 是 request-driven 架構：模型回應一次後 turn 結束，無法自發地在 30 秒後重新啟動。

### 2. 記憶幻覺
模型從 memory 取回過時資訊，以「執行證據」格式呈現，用戶無法辨別真偽。

## 解法一：Cron Heartbeat

利用 OpenClaw 內建 cron 工具，定期觸發 agent 重新 poll subagent 狀態。

### 流程

1. 用戶下任務 → Agent 呼叫 sessions_spawn(worker)
2. Agent 呼叫 cron.schedule("task-heartbeat", interval="30s", message="🔄 heartbeat")
3. 每 30 秒系統自動送 heartbeat 訊息
4. Agent 收到 → session_status("worker") → 推送進度更新
5. done/error → cron.cancel("task-heartbeat") → 推送完成報告

### 前提
- main agent 的 tools.alsoAllow 包含 "cron"
- OpenClaw 2026.3.x+

## 解法二：反幻覺規則 7-8-9

7) 禁止記憶幻覺：回報硬體規格/系統狀態/版本號/IP 等即時數據時，
   必須當場 exec 取得真實輸出，禁止從記憶或訓練資料推斷填入
8) 禁止偽造輸出：禁止用 codeblock 模擬工具回傳。
   真實結果由系統附加，不需自行產生
9) 引用必真實：執行證據必須摘錄系統實際回傳的輸出（至少 1 行原文），
   不得編撰。若無法確認，必須明說「未確認，需重新執行」

## 部署

1. 更新 SOUL.md（Dispatcher 協議 + 規則 7-8-9）
2. 更新 openclaw.json 所有 channel agents 的 systemPrompt
3. 確認 main agent 有 cron 工具權限
4. systemctl --user restart openclaw-gateway
