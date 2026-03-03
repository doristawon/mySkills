# Financial Modeling Core (for our own models)

這是一份「可自有化」的金融分析能力包，參考 Anthropic financial-services-plugins 的架構思想，改寫成可直接給我們自己模型（OpenClaw + 本地/雲端模型）使用的版本。

## 1) 模組架構

```text
financial-modeling-core/
├─ formulas/
│  ├─ dcf.md
│  ├─ three_statements.md
│  └─ comps.md
├─ prompts/
│  ├─ system_financial_analyst.md
│  ├─ task_dcf.md
│  ├─ task_three_statements.md
│  └─ task_comps.md
├─ workflows/
│  ├─ dcf_workflow.json
│  ├─ three_statements_workflow.json
│  └─ comps_workflow.json
└─ scripts/
   └─ finance_formulas.py
```

## 2) 對應原插件能力（改寫版）

- `financial-analysis`（核心）→ 我們拆成三大任務：
  1. DCF valuation
  2. 3-statement model
  3. Comparable company analysis

- 原本的 command + skill 設計（comps/dcf/3-statements）→ 我們用
  - `prompts/*`（任務指令）
  - `workflows/*`（流程節點）
  - `scripts/finance_formulas.py`（統一公式實作）

## 3) 使用方式（建議）

1. 讓主模型先讀 `prompts/system_financial_analyst.md`
2. 根據任務類型附上：
   - DCF → `prompts/task_dcf.md` + `formulas/dcf.md`
   - 三表 → `prompts/task_three_statements.md` + `formulas/three_statements.md`
   - Comps → `prompts/task_comps.md` + `formulas/comps.md`
3. 如需數值計算，呼叫 `scripts/finance_formulas.py` 內函數

## 4) 資料來源層級（可直接照抄到系統規範）

1. 結構化資料源（MCP/API/DB）
2. 使用者提供資料（財報、估值假設、券商報告）
3. 公開網頁資料（僅補充，不作唯一主來源）

## 5) 交付標準（建議）

- 所有輸入假設需可追溯來源
- 結果需有敏感度分析（至少 2 維）
- 同步輸出「結論 + 風險 + 觸發條件」
- 嚴禁只給單點估值，不給區間

## 6) 實務注意

- DCF 終值成長率 `g` 必須小於 `WACC`
- 若公司為淨現金，Enterprise → Equity bridge 要正確「加回淨現金」
- 三表模型需做 balance check 與 cash tie-out
- Comps 必須保證 peer group 可比性（商業模式/規模/區域）
