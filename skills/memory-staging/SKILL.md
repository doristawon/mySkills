---
name: memory-staging
description: 多 agent 或跨頻道可能同時寫入記憶時，改用 memory staging 暫存碎片，避免直接 append `memory/YYYY-MM-DD.md` 造成覆寫衝突。適用於寫入工作進度、會議摘要、臨時結論、cron 產出；先寫入 `memory/staging/*.md`，再由 merge_memory 腳本整併。
---

# Memory Staging

## 何時使用

當任務需要把資訊寫進工作區記憶，而且符合以下任一情況時，使用這個 skill：

- 可能有 2 個 agent 幾乎同時工作
- cron / subagent / 主 agent 都可能寫入同一天的 daily memory
- 內容屬於工作進度、執行摘要、暫時結論、教材產出紀錄

如果只是單次讀取記憶，不用這個 skill。

如果內容是穩定偏好、長期設定、長期人物資訊，最終仍應整理進 `MEMORY.md`，不要永遠只留在 staging。

## 核心規則

不要直接修改 `memory/YYYY-MM-DD.md`。

改成每次寫入都建立一個獨立碎片檔，路徑放在：

```text
/home/chris93/.openclaw/workspace/memory/staging/
```

碎片檔只用 Markdown，副檔名固定是 `.md`。

## 檔名規則

檔名格式：

```text
YYYYMMDD_HHMMSS_model-tag.md
```

範例：

```text
20260308_091530_glm5.md
20260308_091544_minimax-m2-5.md
20260308_091601_claude-sonnet-4-6.md
```

`model-tag` 不要直接使用原始 provider/model 字串。必須先轉成安全檔名：

- 全部小寫
- 只保留 `a-z`、`0-9`、`.`、`-`
- 空白、斜線 `/`、反斜線 `\`、冒號 `:`、其餘符號都改成 `-`
- 連續多個 `-` 壓成一個

可接受對照：

- `agproxy/ag/claude-sonnet-4.6` -> `claude-sonnet-4-6`
- `minimax-portal/MiniMax-M2.5` -> `minimax-m2-5`
- `openai-codex/gpt-5.3-codex` -> `gpt-5-3-codex`

## 寫入內容格式

每個碎片檔只放一筆記憶，內容要短、可合併、可搜尋。

建議格式：

```md
# Memory Fragment

- Time: 2026-03-08 09:15:30 +08:00
- Source: discord-agent-hall
- Model: glm5
- Topic: 教材生成

## Summary
完成教材生成，但因 instruction 重複，主資料庫略過寫入。

## Details
- 產出已記錄
- 後續只需人工複查，不需立即修復
```

不要把整段對話原文、大量 tool output、或不經整理的噪音直接丟進碎片檔。

## 整併機制

此 skill 預設依賴 `scripts/merge_memory.py` 將 `memory/staging/*.md` 依檔名排序後 append 進當天的 `memory/YYYY-MM-DD.md`，成功後刪除已處理碎片。

這個 skill 目錄已附帶一份可參考的 merger 腳本：

```text
scripts/merge_memory.py
```

你目前 live workspace 的實際腳本位置是：

```text
/home/chris93/.openclaw/workspace/scripts/merge_memory.py
```

## 手動整併

如需立即整併或除錯，可在 WSL 執行：

```bash
python3 /home/chris93/.openclaw/workspace/scripts/merge_memory.py
```

如果是在 skill 目錄測試，可改用：

```bash
OPENCLAW_WORKSPACE=/home/chris93/.openclaw/workspace python3 scripts/merge_memory.py
```

## 重要界線

- 這個 skill 解決的是 `daily memory` 的寫入競爭，不是 `MEMORY.md` 的知識整理流程。
- `MEMORY.md` 仍應由 agent 或人工在適當時機做精煉整理。
- 如果任務只會有單一 agent、且你明確知道沒有其他 writer，理論上可直接寫 daily memory；但在這套 OpenClaw 佈署中，預設仍優先使用 staging，避免之後規模變大又回頭修。
