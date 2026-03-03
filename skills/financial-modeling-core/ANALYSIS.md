# Anthropic Financial Services Plugins 深度分析（可自有化版本）

## A. 原始插件結構觀察

來源目錄（本機快取）：
- `~/.claude/plugins/cache/financial-services-plugins/financial-analysis/0.1.0`

主要構成：
1. `.claude-plugin/plugin.json`：插件中繼資料
2. `commands/*.md`：slash command 定義（dcf/comps/lbo/3-statements/check-deck）
3. `skills/*/SKILL.md`：每個任務的行為規範與流程
4. `.mcp.json`：金融資料供應商 MCP 連接器（Daloopa/Morningstar/S&P/FactSet...）
5. `hooks/hooks.json`：目前為空陣列（也是你那邊載入失敗主因之一，程式期待 object）

## B. 可複製核心（已完成）

### 1) 架構
我們已完成 clean-room 改寫版本，路徑：
- `/home/chris93/.openclaw/workspace/custom_skills/financial-modeling-core`

### 2) 公式模組
- DCF：`formulas/dcf.md`
- 三表：`formulas/three_statements.md`
- Comps：`formulas/comps.md`
- 可執行函式：`scripts/finance_formulas.py`

### 3) 任務提示詞
- `prompts/system_financial_analyst.md`
- `prompts/task_dcf.md`
- `prompts/task_three_statements.md`
- `prompts/task_comps.md`

### 4) 工作流
- `workflows/dcf_workflow.json`
- `workflows/three_statements_workflow.json`
- `workflows/comps_workflow.json`

## C. 公式對照（原插件思想 → 我們版本）

| 類別 | 原插件重點 | 我們版本 |
|---|---|---|
| DCF | CAPM/WACC、UFCF、TV、敏感度矩陣 | `formulas/dcf.md` + `finance_formulas.py` |
| 三表 | IS/BS/CF 勾稽、RE roll-forward、cash tie-out | `formulas/three_statements.md` |
| Comps | EV/Revenue、EV/EBITDA、統計分位 | `formulas/comps.md` |
| 任務流程 | command → skill → output | `prompts/*` + `workflows/*` |

## D. 直接導入我們模型的方法

1. 主模型 system prompt 先附加：
   - `prompts/system_financial_analyst.md`
2. 依任務附加專用 prompt + formula 檔
3. 需要計算時呼叫 `scripts/finance_formulas.py`
4. 報告輸出固定使用 Bear/Base/Bull 區間

## E. 法務與實作邊界

- 金融公式屬通用方法（非專屬程式碼）
- 已採「架構映射 + clean-room 改寫」，避免整段專有文案複製
- 建議後續若要公開，保留「參考公開資料、由內部改寫」說明
