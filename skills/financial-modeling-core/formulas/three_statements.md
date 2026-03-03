# 3-Statements 公式庫（自有化）

## 勾稽主軸

- `Assets = Liabilities + Equity`
- `Ending Cash (CF) = Cash (BS)`
- `Ending RE = Beginning RE + NetIncome - Dividends`

## 損益表（IS）

- `GrossProfit = NetRevenue - COGS`
- `EBITDA = EBIT + D&A`
- `EBIT = GrossProfit - OpEx`
- `EBT = EBIT - InterestExpense`
- `Taxes = TaxableIncome * TaxRate`
- `NetIncome = EBT - Taxes`

## 資產負債表（BS）

- `NetDebt = TotalDebt - Cash`
- `NWC = AR + Inventory - AP`
- `ΔNWC = NWC_t - NWC_(t-1)`

## 現金流量表（CF）

- `CFO = NetIncome + D&A + SBC - ΔNWC (+/-其他非現金調整)`
- `CFI = -CapEx (+投資處分淨額)`
- `CFF = DebtIssuance - DebtRepayment + EquityIssuance - Dividends`
- `ΔCash = CFO + CFI + CFF`
- `EndingCash = BeginningCash + ΔCash`

## 預測常用（% of Revenue）

- `COGS_t = Revenue_t * COGS%`
- `S&M_t = Revenue_t * S&M%`
- `R&D_t = Revenue_t * R&D%`
- `G&A_t = Revenue_t * G&A%`
- `D&A_t = Revenue_t * D&A%`
- `CapEx_t = Revenue_t * CapEx%`

## 檢查項目

- Balance check = 0
- Cash tie-out = 0
- RE roll-forward check = 0
- Debt schedule 與利息費用一致
