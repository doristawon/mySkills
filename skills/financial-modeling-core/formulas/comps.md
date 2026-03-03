# Comparable Company Analysis 公式庫（自有化）

## 核心倍數

- `EV = MarketCap + TotalDebt - Cash`
- `EV/Revenue = EV / Revenue_LTM`
- `EV/EBITDA = EV / EBITDA_LTM`
- `P/E = Price / EPS`
- `P/B = Price / BookValuePerShare`

## 成長與獲利

- `RevenueGrowthYoY = Revenue_t / Revenue_(t-1) - 1`
- `GrossMargin = GrossProfit / Revenue`
- `EBITDAMargin = EBITDA / Revenue`
- `FCFMargin = FCF / Revenue`

## 統計彙總

每個欄位至少輸出：
- `Min`
- `25th Percentile`
- `Median`
- `75th Percentile`
- `Max`

## Peer Selection 原則

- 商業模式一致
- 規模相近（市值/營收級距）
- 地區/法規環境相近
- 財務結構不可差異過大（極端槓桿、破產狀態需剔除）

## 輸出建議

- Trading range（以 EV/EBITDA、EV/Revenue 中位數 ± 四分位）
- 被估值公司 implied multiple 與 peers 偏離度
- Premium/Discount 原因（成長、毛利、風險、資本效率）
