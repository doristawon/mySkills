# Qwen3-TTS Skill

## 啟動 Qwen3-TTS API 伺服器 (在 Chris93MLK)

```bash
# 1. 複製 service 檔案
cp ~/.openclaw/workspace/scripts/qwen-tts.service ~/.config/systemd/user/

# 2. 啟動服務
systemctl --user daemon-reload
systemctl --user enable qwen-tts.service
systemctl --user start qwen-tts.service

# 3. 檢查狀態
systemctl --user status qwen-tts.service
```

## 手動啟動 (測試用)

```bash
source qwen-tts-env/bin/activate
export MODEL_PATH=./qwen3-tts-0.6b
export PORT=8001
python ~/.openclaw/workspace/scripts/qwen_tts_server.py
```

## 測試 API

```bash
curl http://10.0.0.200:8001/health
```

## 從 OpenClaw 調用

在瑄之神對話中使用：
- 直接對我說「生成語音：你好」之類的指令
- 或使用 exec 工具呼叫腳本
