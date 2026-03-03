# DCF 公式庫（自有化）

## 核心公式

- Cost of Equity (CAPM)
  - `Ke = Rf + Beta * ERP`
- After-tax Cost of Debt
  - `Kd_at = Kd * (1 - TaxRate)`
- WACC
  - `WACC = Ke * We + Kd_at * Wd`

其中：
- `We = EquityValue / (EquityValue + NetDebt)`
- `Wd = NetDebt / (EquityValue + NetDebt)`

## 現金流

- `NOPAT = EBIT * (1 - TaxRate)`
- `UFCF = NOPAT + D&A - CapEx - ΔNWC`

## 折現

- Mid-year convention 折現因子：
  - `DF_t = 1 / (1 + WACC)^(t - 0.5)`
- `PV_FCF_t = UFCF_t * DF_t`

## 終值（Perpetuity Growth）

- `TV = UFCF_(n+1) / (WACC - g)`
- `PV_TV = TV / (1 + WACC)^(n - 0.5)`
- 約束：`g < WACC`

## 企業價值到股權價值

- `EV = ΣPV_FCF + PV_TV`
- `EquityValue = EV - NetDebt`
  - 若 `NetDebt < 0`（淨現金）等同加回
- `ImpliedPrice = EquityValue / DilutedShares`

## 敏感度分析（最低要求）

1. `WACC × g`（5x5）
2. `Revenue CAGR × Terminal EBIT Margin`（5x5）

輸出：
- Base / Bear / Bull 三案
- 每案的 Implied Price、Upside/Downside
