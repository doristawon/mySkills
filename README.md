# mySkills — OpenClaw 自建技能庫

自建的 OpenClaw 技能（Skills）、工具（Tools）、Workflow 與 Agent 人格設定集合。

## 目錄結構

```
mySkills/
├── skills/
│   ├── hybrid-model-routing/    # Gemini + Claude 混合路由與 Fallback 系統
│   ├── financial-modeling-core/ # 財務建模（DCF、Comps、三表模型）
│   ├── bird/                   # X/Twitter CLI 技能
│   ├── memory-staging/         # 分散式記憶體代理（防多 Agent 並發覆寫）
│   └── qwen-tts/              # Qwen3-TTS 語音生成 API 服務
│
├── tools/
│   └── antigravity-proxy/      # agproxy 中轉服務（Node.js）
│
├── workflows/
│   └── agproxy_hybrid_routing.md  # AGProxy 混合路由完整設定指南
│
└── agent-identity/             # Agent 人格與記憶設定範本
    ├── SOUL.md / IDENTITY.md / AGENTS.md
    ├── BOOT.md / HEARTBEAT.md
    └── MEMORY.md / TOOLS.md
```

## 技能列表

| 技能 | 描述 |
|------|------|
| [hybrid-model-routing](./skills/hybrid-model-routing/SKILL.md) | Gemini CLI + Antigravity Manager 雙層 Fallback；Claude 8080→8045 雙層保障 |
| [financial-modeling-core](./skills/financial-modeling-core/README.md) | DCF 估值、Comps 比較分析、三表財務建模工作流程 + Python 公式計算 |
| [bird](./skills/bird/SKILL.md) | X/Twitter CLI（GraphQL + Cookie 認證），支援閱讀、搜尋、發文、互動 |
| [memory-staging](./skills/memory-staging/SKILL.md) | 分散式記憶碎片化寫入 + 3分鐘 Cron 自動整併，防止多 Agent 並發覆寫記憶 |
| [qwen-tts](./skills/qwen-tts/SKILL.md) | Qwen3-TTS 0.6B 本機語音生成 API 服務（Systemd 常駐） |

## Workflow 列表

| Workflow | 描述 |
|----------|------|
| [agproxy_hybrid_routing](./workflows/agproxy_hybrid_routing.md) | AGProxy 混合路由 + Stealth Mode 完整設定（含 server.js fallback 程式碼） |

## 快速開始（hybrid-model-routing）

### 先決條件
- [OpenClaw](https://openclaw.dev) 2026.x+
- [Antigravity Manager](https://github.com/lbjlaq/Antigravity-Manager) **v4.1.28+**（⚠️ v4.1.27 有 Gemini 400 錯誤）
- Node.js 18+
- `npm install -g antigravity-claude-proxy`

### 部署 agproxy
```bash
cp -r tools/antigravity-proxy ~/.openclaw/workspace/tools/
cd ~/.openclaw/workspace/tools/antigravity-proxy
# 填入你的 API key
nano start-agproxy.sh
bash start-agproxy.sh
```

### 更新 openclaw.json
參考 `skills/hybrid-model-routing/configs/openclaw-providers.json`，
在 `~/.openclaw/openclaw.json` 的 `models.providers` 加入 `agproxy` 和 `ag-manager`。

---

> ⚠️ 所有 API Key 均已替換為 placeholder（`YOUR_MANAGER_API_KEY_HERE` 等），請填入你自己的金鑰。
