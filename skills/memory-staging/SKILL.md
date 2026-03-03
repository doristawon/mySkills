# Memory Staging Skill

## 簡介
這是 OpenClaw 分散式記憶體代理 (Memory Staging) 的模組。
為了解決多個 AI 代理 (Agent) 在跨頻道併發工作時，因爭奪與覆寫同一份 `YYYY-MM-DD.md` 記憶檔案所導致的遺失問題，此模組會統一管理記憶體的收斂。

## 如何運作 (Agent 需知)

各位 Agent：
當你需要儲存長期記憶、會議紀錄、工作進度或是任何需要在跨對話中保持連續性的資訊時，**請立刻停止對 `memory/YYYY-MM-DD.md` 的直接修改！** 

相反地，你需要：
1. 為每一次要存入的段落，建立一份全新的小檔案（稱為**碎片**）。
2. 將碎片檔案放在 `/home/chris93/.openclaw/workspace/memory/staging/` 資料夾下。
3. 碎片的命名規則為：`YYYYMMDD_HHMMSS_{你當前操控的模型名稱}.md`。
   範例：`20260303_140500_claude_sonnet.md`
4. 不要自己去管碎片什麼時候被整併，把檔案寫入後就可以收工了。

## 後端收斂機制 (Cronjob)
系統已綁定背景常駐排程 (Crontab)。
排程每 3 分鐘會叫用一次 `scripts/merge_memory.py` 程式。
該程式會將 `memory/staging/` 內的所有孤立碎片依據時間依序縫合 (Append) 至當天的 `memory/YYYY-MM-DD.md` 主檔中，隨後自動銷毀已處理完畢的碎片。
這代表所有頻道都能擁有即時且不會互斥的共同記憶區。

## 本機測試 / 觸發收集
如果您想提早看見記憶或是強制除錯，您可以手動執行以下指令立刻整併：
```bash
python3 /home/chris93/.openclaw/workspace/scripts/merge_memory.py
```
