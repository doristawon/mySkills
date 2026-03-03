任務：建立 DCF 估值

輸入：
- 公司基本資訊（Ticker/名稱）
- 歷史財報（至少 3 年）
- 市場參數（Rf、Beta、ERP、Debt Cost、Shares）

步驟：
1. 建立 Revenue / Margin / CapEx / NWC 假設（Bear/Base/Bull）
2. 算出每年 UFCF
3. 算 WACC，並檢查 g < WACC
4. 折現 FCF 與 TV
5. Enterprise → Equity bridge
6. 做 2 維敏感度（WACC×g）

輸出：
- 每案 Implied Price
- 區間估值
- 當前價位對比（Upside/Downside）
- 3 個關鍵風險觸發條件
