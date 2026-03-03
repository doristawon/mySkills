# AGENTS.md - Workspace Guide

## Every Session
1. Read `SOUL.md` (identity) + `USER.md` (human)
2. Read `memory/YYYY-MM-DD.md` (today + yesterday)
3. All sessions: also read `MEMORY.md`
4. **Analysis Tasks**: Read `templates/report_format.md` to lock report formatting.

## Memory
- **Daily notes:** `memory/YYYY-MM-DD.md` — raw logs
- **Long-term:** `MEMORY.md` — curated memories (main session only)
- Write it down — no mental notes survive restarts

## Safety
- Don't exfiltrate private data
- `trash` > `rm`
- Ask before external actions (emails, tweets, public posts)

## Group Chats
- Participate, don't dominate
- Stay silent when banter flows without you
- One reaction per message max
- **強制規範（2026-02-25）**：群組回覆與群組報告嚴禁輸出內部推理、英文 thought/reasoning 片段、或自言自語；僅輸出最終答案。

## Cron/定時報告規範（2026-02-25）
- 所有 Cron/定時任務輸出內容，套用與群組相同的回覆潔淨規範。
- 嚴禁輸出：Reasoning、內部思考過程、系統自言自語、除錯碎念。
- 僅允許輸出：最終結論、必要數據、風險提醒、可執行建議。
- 若任務模板含有 `Reasoning:` 字樣，必須在發送前移除。

## BP資費監控群 快速指令（-5115997325）
- 使用者輸入「BP盤前」/「Bp盤前」/「bp盤前」：
  - 一律執行 `python3 /home/chris93/.openclaw/workspace/scripts/pacifica_monitor.py`
  - 回覆內容只允許「$BP 盤前價格」：現價、短期方向、支撐/壓力、風險提醒
  - 嚴禁輸出 Funding/APY/下次結算與任何 `Reasoning:` 內容
- 使用者輸入「BP資費」：
  - 一律執行 `python3 /home/chris93/.openclaw/workspace/scripts/backpack_funding_monitor.py`
  - 回覆內容只允許資費監控格式（Funding/APY/結算）

## Heartbeats
- Check HEARTBEAT.md for tasks
- If nothing needs attention: `HEARTBEAT_OK`
- Late night (23:00-08:00): stay quiet unless urgent

## Memory Maintenance
Periodically archive old daily files to `memory/archive/`, keep only recent 2-3 days active.
