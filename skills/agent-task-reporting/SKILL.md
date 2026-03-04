---
name: agent-task-reporting
description: OpenClaw Agent 任務執行與主動回報機制。確保所有 Agent 在處理長時任務時，能透過 sessions_spawn 派發 Worker Subagent，並在完成後用 message 工具主動推送標準化回報至父頻道。
---

# Agent 任務執行與主動回報技能 (Agent Task Reporting Skill)

## 概述

本技能解決 OpenClaw Discord Agent 的核心痛點：
- **先說後做** — Agent 先回覆「好的，我去做」，然後沉默消失
- **靜默完成** — 任務完成了但從不回報結果
- **失敗無聲** — 工具出錯只道歉，不給原因和方案

透過 **Worker Subagent + Callback Message** 架構，讓所有 Agent 能：
1. 即時公告任務啟動
2. 派發 Worker Subagent 處理長時任務
3. 輪詢進度，完成後主動推送標準化回報

---

## 架構流程圖

```
用戶輸入長任務
  ↓
主 Agent：先回「執行中：...」
  ↓
sessions_spawn("worker", systemPrompt="...完成後 message 回報...")
  ↓
sessions_send("worker", <完整任務描述>)
  ↓
[每 30 秒] session_status("worker") 輪詢
  ↓
Worker 完成
  ↓
message(channelId, "✅ 已完成：...")  ← 主動推播
```

---

## System Prompt 必要規則

在每個 Discord Channel 的 `systemPrompt` 末尾加入以下規則：

```
【長時任務處理規定 + 主動回報機制】

─── 短任務（預估 < 10 秒）───
1) 先完成工具操作，取得結果後再回覆
2) 禁止在工具執行前說「已完成/已執行」

─── 長任務（預估 ≥ 10 秒）必用流程 ───
1) 先回一行確認：「執行中：<任務描述>」
2) sessions_spawn 建立 worker subagent，傳入 systemPrompt：
   "完成任務後，必須用 message 工具回報給 peer.id 頻道。
    ✅ 格式：✅ 已完成：<任務> | ❌ 格式：❌ 失敗：<原因+方案>"
3) sessions_send 把完整任務傳給 worker
4) 每 30 秒 session_status 輪詢進度
5) Worker 完成後，立刻用 message 主動推送至本頻道：

✅ 成功格式：
✅ 已完成：<任務名稱>
📊 執行結果：<關鍵輸出或摘要>
📁 影響範圍：<已更動的檔案、系統或頻道>
⏭️ 下一步：<後續建議>

❌ 失敗格式：
❌ 執行失敗：<任務名稱>
🔍 失敗原因：<具體錯誤>
🛠️ 修復方案：<建議的解法>

─── 失敗與錯誤 ───
1) 工具失敗：必須回「錯誤原因 + 修復方案」，禁止只道歉
2) 超過 60 秒無進展：至少回一次進度更新
3) Worker 失敗：主動回報失敗原因並提供替代方案

─── 參考執行範例（學習此格式）───
【執行公告】執行中：正在派遣 Codex 5.3，預計耗時 2 分鐘
【派發】sessions_spawn("codex-worker", systemPrompt="...完成後 message 回報...")
【傳任務】sessions_send("codex-worker", "分析架構並優化 SSH 連線...")
【監控】session_status 每 30 秒輪詢
【完成推播】message(channelId, "✅ 已完成：Codex 分析\\n📊 結果：...")
```

---

## 部署方式

### 批次更新所有頻道 (Python 腳本)

```python
import json, re

path = '/home/<user>/.openclaw/openclaw.json'
data = json.load(open(path, encoding='utf-8'))

RULE_BLOCK = """
【長時任務處理規定 + 主動回報機制】
... # 貼上上方完整規則
"""

guilds = data.get('channels', {}).get('discord', {}).get('guilds', {})
for gid, gval in guilds.items():
    for cid, cval in gval.get('channels', {}).items():
        sp = cval.get('systemPrompt', '')
        if RULE_BLOCK not in sp:
            cval['systemPrompt'] = sp.rstrip() + RULE_BLOCK

json.dump(data, open(path, 'w', encoding='utf-8'), indent=2, ensure_ascii=False)
print("Done!")
```

---

## 重要限制

> [!WARNING]
> `agents.defaults.subagents.systemPrompt` **不是 OpenClaw 支援的 key**！
> 無法透過 config 全域注入 subagent 系統提示。
> 唯一正確方法是：在**主 Agent 的 channel systemPrompt** 裡指示它在 `sessions_spawn` 時傳入 systemPrompt 參數。

---

## 支援的 `agents.defaults.subagents` 有效 Key

| Key | 說明 | 預設值 |
|-----|------|--------|
| `maxConcurrent` | 最大並發 subagent 數 | 1 |
| `model` | 預設使用模型 | 繼承父 Agent |
| `runTimeoutSeconds` | 逾時秒數 | 0 (無限) |
| `archiveAfterMinutes` | 完成後幾分鐘歸檔 | 60 |

---

*Last updated: 2026-03-05*
