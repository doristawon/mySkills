# mySkills  OpenClaw 自建技能庫

自建的 OpenClaw 技能（Skills）與工具（Tools）集合。

## 目錄結構

`
mySkills/
 skills/                       # OpenClaw Skill 定義
    hybrid-model-routing/     # 混合模型路由技能
        SKILL.md              # 技能說明與完整架構文件
        configs/              # 設定範本
            start-agproxy.sh        # agproxy 啟動腳本範本
            openclaw-providers.json # openclaw.json providers 區段範本

 tools/                        # 底層工具程式
     antigravity-proxy/        # agproxy 中轉服務（Node.js）
         server.js             # 主程式（路由、fallback 邏輯）
         start-agproxy.sh      # 啟動腳本
         adapters/             # 各模型 adapter 腳本
             gemini_cli_adapter.sh
             claude_via_antigravity_proxy_adapter.sh
             mock_adapter.sh
`

## 快速開始

### 1. 安裝先決條件

- [OpenClaw](https://openclaw.dev) 2026.x+
- [Antigravity Manager](https://github.com/lbjlaq/Antigravity-Manager) v4.1.28+（重要：v4.1.27 有 Gemini 400 錯誤）
- Node.js 18+
- ntigravity-claude-proxy：
pm install -g antigravity-claude-proxy

### 2. 部署 agproxy

`ash
# 複製工具
cp -r tools/antigravity-proxy ~/.openclaw/workspace/tools/
cd ~/.openclaw/workspace/tools/antigravity-proxy

# 編輯 start-agproxy.sh，填入你的 API key
nano start-agproxy.sh

# 啟動
bash start-agproxy.sh
`

### 3. 將 skills/ 複製到你的 workspace

`ash
cp -r skills/ ~/.openclaw/workspace/skills/
`

### 4. 更新 openclaw.json

參考 skills/hybrid-model-routing/configs/openclaw-providers.json，
在你的 ~/.openclaw/openclaw.json 的 models.providers 區段加入 gproxy 和 g-manager。

---

## 技能列表

| 技能 | 說明 |
|------|------|
| [hybrid-model-routing](./skills/hybrid-model-routing/SKILL.md) | Gemini + Claude 混合路由與 Fallback 系統 |

---

>  所有設定檔中的 API Key 均已替換為 placeholder（YOUR_MANAGER_API_KEY_HERE 等），請記得填入你自己的金鑰。
