# mySkills  OpenClaw 自建技能庫

自建的 OpenClaw 技能（Skills）、工具（Tools）與 Agent 人格設定集合。

## 目錄結構

`
mySkills/
 skills/
    hybrid-model-routing/    # Gemini + Claude 混合路由與 Fallback 系統
    financial-modeling-core/ # 財務建模（DCF、Comps、三表模型）
    bird/                   # X/Twitter CLI 技能

 tools/
    antigravity-proxy/      # agproxy 中轉服務（Node.js）

 agent-identity/             # Agent 人格與記憶設定範本
     SOUL.md
     IDENTITY.md
     AGENTS.md
     BOOT.md
     HEARTBEAT.md
     MEMORY.md
     TOOLS.md
`

## 技能列表

| 技能 | 描述 |
|------|------|
| [hybrid-model-routing](./skills/hybrid-model-routing/SKILL.md) | Gemini CLI + Antigravity Manager 雙層 Fallback 路由；Claude 80808045 雙層保障 |
| [financial-modeling-core](./skills/financial-modeling-core/README.md) | DCF 估值、Comps 比較分析、三表財務建模工作流程 + Python 公式計算 |
| [bird](./skills/bird/SKILL.md) | X/Twitter CLI（GraphQL + Cookie 認證），支援閱讀、搜尋、發文、互動 |

## 快速開始（hybrid-model-routing）

### 先決條件
- [OpenClaw](https://openclaw.dev) 2026.x+
- [Antigravity Manager](https://github.com/lbjlaq/Antigravity-Manager) **v4.1.28+**（ v4.1.27 有 Gemini 400 錯誤）
- Node.js 18+
- 
pm install -g antigravity-claude-proxy

### 部署 agproxy
`ash
cp -r tools/antigravity-proxy ~/.openclaw/workspace/tools/
cd ~/.openclaw/workspace/tools/antigravity-proxy
# 編輯 start-agproxy.sh，填入你的 API key
nano start-agproxy.sh
bash start-agproxy.sh
`

### 更新 openclaw.json
參考 skills/hybrid-model-routing/configs/openclaw-providers.json，
在 ~/.openclaw/openclaw.json 的 models.providers 加入 gproxy 和 g-manager。

---

>  所有 API Key 均已替換為 placeholder（YOUR_MANAGER_API_KEY_HERE 等），請填入你自己的金鑰。
