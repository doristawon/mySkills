#!/usr/bin/env node
const http = require('http');
const fs = require('fs');
const path = require('path');
const os = require('os');
const { spawn, execSync } = require('child_process');

const PORT = Number(process.env.AG_PROXY_PORT || 4010);
const API_KEY = process.env.AG_PROXY_API_KEY || '';
const GEMINI_API_KEY = process.env.GEMINI_API_KEY || process.env.AG_PROXY_GEMINI_API_KEY || '';

const BACKEND_CMD = process.env.AG_PROXY_BACKEND_CMD || 'bash /home/chris93/.openclaw/workspace/tools/antigravity-proxy/adapters/mock_adapter.sh';
const BACKEND_CLAUDE_CMD = process.env.AG_PROXY_BACKEND_CLAUDE_CMD || '';

const IMAGE_MODEL_DEFAULT = process.env.AG_PROXY_IMAGE_MODEL || 'gemini-2.5-flash-image';
const IMAGE_PLANNER_MODEL = process.env.AG_PROXY_IMAGE_PLANNER_MODEL || 'gemini-3.1-pro-preview';
const MULTIMODAL_MODEL_DEFAULT = process.env.AG_PROXY_MULTIMODAL_MODEL || 'gemini-2.5-pro';

const MODEL_MAP = (() => {
  try { return JSON.parse(process.env.AG_PROXY_MODEL_MAP || '{}'); } catch { return {}; }
})();

function send(res, code, obj) {
  res.writeHead(code, { 'Content-Type': 'application/json; charset=utf-8' });
  res.end(JSON.stringify(obj));
}
function unauthorized(res) { send(res, 401, { error: { message: 'Unauthorized', type: 'auth_error' } }); }
function checkAuth(req, res) {
  if (!API_KEY) return true;
  const auth = req.headers['authorization'] || '';
  if (!auth.startsWith('Bearer ')) return unauthorized(res), false;
  const token = auth.slice('Bearer '.length).trim();
  if (token !== API_KEY) return unauthorized(res), false;
  return true;
}
function readBody(req) {
  return new Promise((resolve, reject) => {
    let data = '';
    req.on('data', (chunk) => {
      data += chunk;
      if (data.length > 25 * 1024 * 1024) {
        reject(new Error('body too large'));
        req.destroy();
      }
    });
    req.on('end', () => resolve(data));
    req.on('error', reject);
  });
}

function messagesToPrompt(messages = []) {
  return messages.map((m) => `${m.role || 'user'}: ${typeof m.content === 'string' ? m.content : JSON.stringify(m.content)}`).join('\n');
}

function runBackend(payload, cmd) {
  return new Promise((resolve, reject) => {
    const child = spawn('bash', ['-lc', cmd], { stdio: ['pipe', 'pipe', 'pipe'] });
    let out = ''; let err = '';
    child.stdout.on('data', (d) => (out += d.toString()));
    child.stderr.on('data', (d) => (err += d.toString()));
    child.on('error', reject);
    child.on('close', (code) => {
      if (code !== 0) return reject(new Error(`backend_exit_${code}: ${err || out}`));
      try { resolve(JSON.parse(out)); }
      catch { reject(new Error(`backend_non_json: ${out.slice(0, 500)}`)); }
    });
    child.stdin.write(JSON.stringify(payload));
    child.stdin.end();
  });
}

async function geminiGenerateContent(model, contents, generationConfig = {}) {
  if (!GEMINI_API_KEY) throw new Error('GEMINI_API_KEY missing for multimodal/image routes');
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent?key=${encodeURIComponent(GEMINI_API_KEY)}`;
  const resp = await fetch(url, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ contents, generationConfig }),
  });
  const text = await resp.text();
  let data;
  try { data = JSON.parse(text); } catch { throw new Error(`gemini_non_json: ${text.slice(0, 300)}`); }
  if (!resp.ok) throw new Error(`gemini_http_${resp.status}: ${JSON.stringify(data).slice(0, 400)}`);
  return data;
}

function ensureDataFromItem(item) {
  if (!item) return null;
  if (item.dataBase64 && item.mimeType) return { mimeType: item.mimeType, data: item.dataBase64 };
  if (item.path && item.mimeType) {
    const b = fs.readFileSync(item.path);
    return { mimeType: item.mimeType, data: b.toString('base64') };
  }
  return null;
}

function ffmpegExists() {
  try { execSync('command -v ffmpeg >/dev/null 2>&1'); return true; } catch { return false; }
}

function extractVideoFramesBase64(videoPath, maxFrames = 4) {
  if (!ffmpegExists()) return [];
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'agpx-frames-'));
  const outPattern = path.join(tmp, 'f-%03d.jpg');
  try {
    execSync(`ffmpeg -y -i ${JSON.stringify(videoPath)} -vf fps=0.5 -frames:v ${maxFrames} ${JSON.stringify(outPattern)} >/dev/null 2>&1`);
    const files = fs.readdirSync(tmp).filter((f) => f.endsWith('.jpg')).sort();
    return files.map((f) => ({ mimeType: 'image/jpeg', data: fs.readFileSync(path.join(tmp, f)).toString('base64') }));
  } finally {
    try { fs.rmSync(tmp, { recursive: true, force: true }); } catch { }
  }
}

function parseGeminiText(data) {
  const cand = data?.candidates?.[0]?.content?.parts || [];
  return cand.filter((p) => typeof p.text === 'string').map((p) => p.text).join('\n').trim();
}

function parseGeminiImageBase64(data) {
  const parts = data?.candidates?.[0]?.content?.parts || [];
  const hit = parts.find((p) => p.inlineData?.data || p.inline_data?.data);
  if (!hit) return null;
  return (hit.inlineData?.data || hit.inline_data?.data || null);
}

const server = http.createServer(async (req, res) => {
  try {
    if (req.url === '/health') return send(res, 200, { ok: true, backend: BACKEND_CMD, imageModel: IMAGE_MODEL_DEFAULT });

    if (req.url === '/v1/models' && req.method === 'GET') {
      const baseIds = Object.keys(MODEL_MAP).length ? Object.keys(MODEL_MAP) : ['ag/gemini-3-flash', 'ag/gemini-3.1-pro'];
      const extra = ['ag/nano-banana-2', 'ag/media-understand-v1'];
      const ids = [...new Set([...baseIds, ...extra])];
      return send(res, 200, {
        object: 'list',
        data: ids.map((id) => ({ id, object: 'model', created: Math.floor(Date.now() / 1000), owned_by: 'antigravity-proxy' })),
      });
    }

    if (req.url === '/v1/chat/completions' && req.method === 'POST') {
      if (!checkAuth(req, res)) return;
      const body = JSON.parse((await readBody(req)) || '{}');
      const model = body.model || 'ag/gemini-3-flash';
      const mappedModel = MODEL_MAP[model] || model;
      const prompt = messagesToPrompt(body.messages || []);

      require('fs').appendFileSync('/tmp/agproxy-tools-debug.json', JSON.stringify({ model: model, tools: body.tools || [] }, null, 2) + '\n');

      // Clean up tools to prevent Gemini API 400 error (cannot combine built-in googleSearch and custom function declarations)
      // Gemini built-in tools appear under multiple names depending on the layer: googleSearch, google_search, web_search, google_web_search
      const GEMINI_BUILTIN_TOOLS = new Set(['googleSearch', 'google_search', 'web_search', 'google_web_search', 'codeExecution', 'code_execution']);
      if (body.tools && Array.isArray(body.tools)) {
        body.tools = body.tools.filter(t => {
          if (t.googleSearch || t.google_search || t.web_search || t.codeExecution || t.code_execution) return false;
          if (t.function && GEMINI_BUILTIN_TOOLS.has(t.function.name)) return false;
          return true;
        });
        if (body.tools.length === 0) {
          delete body.tools;
          delete body.tool_choice;
        }
      }

      const backendCmd = (BACKEND_CLAUDE_CMD && (model.includes('claude') || String(mappedModel).includes('claude'))) ? BACKEND_CLAUDE_CMD : BACKEND_CMD;
      let backendResp;

      // Ensure that models named agproxy/agmanager/... or agmanager/... bypass CLI
      const isDirectManager = model.includes('agmanager/') || String(mappedModel).includes('agmanager/');
      if (isDirectManager) {
        // Strip out 'agproxy/agmanager/' or 'agmanager/' to get the true manager model name
        let directModel = (mappedModel || model).replace(/^.*agmanager\//, '');

        // Map 3.1-pro to the actually supported high tier in the Manager
        if (directModel === 'gemini-3.1-pro') directModel = 'gemini-3.1-pro-high';

        console.log(`[AGProxy] Direct routing to Manager API for model: ${directModel}`);
        try {
          const fwdPayload = { model: directModel, messages: body.messages || [], temperature: body.temperature, max_tokens: body.max_tokens, stream: false };
          if (body.tools) fwdPayload.tools = body.tools;
          if (body.tool_choice) fwdPayload.tool_choice = body.tool_choice;

          const fwdResp = await fetch("http://127.0.0.1:8045/v1/chat/completions", {
            method: "POST",
            headers: { "Content-Type": "application/json", "Authorization": "Bearer sk-c7b22d91415946af9f0772ba40db8fec" },
            body: JSON.stringify(fwdPayload)
          });

          if (fwdResp.ok) {
            const fbData = await fwdResp.json();
            const fbChoice = fbData?.choices?.[0]?.message;
            if (fbChoice) {
              backendResp = { text: fbChoice.content || "", tool_calls: fbChoice.tool_calls, usage: fbData.usage || {} };
            } else {
              backendResp = { error: "manager_empty", detail: "Manager returned empty choice" };
            }
          } else {
            const errText = await fwdResp.text();
            console.error("[AGProxy] Manager direct route returned error status:", fwdResp.status, errText);
            backendResp = { error: "manager_http_error", detail: errText, status: fwdResp.status };
          }
        } catch (e) {
          backendResp = { error: "manager_network_error", detail: e.message };
        }
      } else {
        // Normal CLI or Claude Proxy execution
        backendResp = await runBackend({
          model: mappedModel,
          originalModel: model,
          prompt,
          messages: body.messages || [],
          temperature: body.temperature,
          max_tokens: body.max_tokens,
          tools: body.tools,
          tool_choice: body.tool_choice
        }, backendCmd);
      }

      // Fallback Strategy: If primary backend fails (especially quota), try Antigravity Manager
      if (backendResp && backendResp.error) {
        let sentDiscordAlert = false;
        const DISCORD_WEBHOOK = "https://discord.com/api/webhooks/1478799577082495290/FRcQGgbwJIWcrJqeqlEuG1bZXkx7kOhXxQHLVJN7I28AAC5vmj419buZQFxDzb3Yfu4p";

        const sendAlert = async (msg) => {
          try {
            await fetch(DISCORD_WEBHOOK, {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({ content: msg })
            });
          } catch (e) { console.error("Webhook failed:", e); }
        };

        if (!model.includes('claude') && !String(mappedModel).includes('claude')) {
          console.log(`[AGProxy] Primary backend failed with error: ${backendResp.error}. Falling back to Antigravity Manager API...`);
          sendAlert(`⚠️ **[AGProxy 警報]** \`${mappedModel}\` 本機端 CLI 發生錯誤 (\`${backendResp.error}\`)。\n正在嘗試 Fallback 到 Antigravity Manager... 🔄`);
          sentDiscordAlert = true;

          try {
            const fallbackPayload = { model: mappedModel, messages: body.messages || [], temperature: body.temperature, max_tokens: body.max_tokens, stream: false };
            if (body.tools) fallbackPayload.tools = body.tools;
            if (body.tool_choice) fallbackPayload.tool_choice = body.tool_choice;
            console.error(`[DEBUG_PAYLOAD] Sending to manager with tools: ${!!body.tools}`);
            const fbResp = await fetch("http://127.0.0.1:8045/v1/chat/completions", {
              method: "POST",
              headers: { "Content-Type": "application/json", "Authorization": "Bearer sk-c7b22d91415946af9f0772ba40db8fec" },
              body: JSON.stringify(fallbackPayload)
            });
            if (fbResp.ok) {
              const fbData = await fbResp.json();
              const fbChoice = fbData?.choices?.[0]?.message;
              if (fbChoice) {
                console.log(`[AGProxy] Fallback successful! Returning manager response. (Has tool_calls: ${!!fbChoice.tool_calls})`);
                sendAlert(`✅ **[AGProxy 成功]** Manager 備援接手成功！任務已繼續執行。`);
                backendResp = {
                  text: fbChoice.content || "",
                  tool_calls: fbChoice.tool_calls,
                  usage: fbData.usage || {}
                };
                delete backendResp.error;
                delete backendResp.status;
                delete backendResp.detail;
              }
            } else {
              console.error("[AGProxy] Manager fallback returned error status:", fbResp.status);
              sendAlert(`🚨 **[AGProxy 失敗]** Manager 備援也失敗了 (HTTP ${fbResp.status})。API 請求已完全中斷！`);
            }
          } catch (e) {
            console.error("[AGProxy] Manager fallback requested but failed entirely:", e);
            sendAlert(`🚨 **[AGProxy 崩潰]** 無法連線至 Manager，備援請求完全失敗：\`${e.message}\``);
          }
        }

        // If it's Claude or a model without fallback that fails, alert too
        if (backendResp && backendResp.error && !sentDiscordAlert) {
          sendAlert(`🚨 **[AGProxy 嚴重錯誤]** 模型 \`${mappedModel}\` 發生無法修復的錯誤：\`${backendResp.error}\`\n詳細資訊：\`${String(backendResp.detail).substring(0, 200)}\``);
        }
      }

      if (backendResp && backendResp.error) {
        const status = Number(backendResp.status || 502);
        return send(res, status, {
          error: {
            type: backendResp.error,
            message: backendResp.detail || 'backend error',
            hint: (backendResp.error === 'permission_error' || String(backendResp.detail || '').includes('OAuth authentication is currently not allowed'))
              ? 'Claude OAuth 已被組織限制或額度不足，請改用 claude-max provider / API key。'
              : undefined,
          },
          model,
        });
      }
      let text = backendResp.text || backendResp.output || '';
      const usage = backendResp.usage || { prompt_tokens: 0, completion_tokens: 0, total_tokens: 0 };
      const trimmed = String(text).trim();
      if (!trimmed || trimmed === 'NO_REPLY') {
        text = '收到，我在，正在處理。';
      }
      if (body.stream) {
        res.writeHead(200, {
          'Content-Type': 'text/event-stream',
          'Cache-Control': 'no-cache',
          'Connection': 'keep-alive',
        });
        const baseId = `chatcmpl-${Date.now()}`;
        const created = Math.floor(Date.now() / 1000);
        const chunk1 = {
          id: baseId,
          object: 'chat.completion.chunk',
          created,
          model,
          choices: [{ index: 0, delta: { role: 'assistant', content: text }, finish_reason: null }]
        };
        const chunk2 = {
          id: baseId,
          object: 'chat.completion.chunk',
          created,
          model,
          choices: [{ index: 0, delta: {}, finish_reason: 'stop' }],
          usage
        };
        res.write(`data: ${JSON.stringify(chunk1)}\n\n`);
        res.write(`data: ${JSON.stringify(chunk2)}\n\n`);
        res.write(`data: [DONE]\n\n`);
        return res.end();
      } else {
        return send(res, 200, {
          id: `chatcmpl-${Date.now()}`,
          object: 'chat.completion',
          created: Math.floor(Date.now() / 1000),
          model,
          choices: [{ index: 0, message: { role: 'assistant', content: text }, finish_reason: 'stop' }],
          usage,
        });
      }
    }

    // OpenAI-compatible image endpoint
    if (req.url === '/v1/images/generations' && req.method === 'POST') {
      if (!checkAuth(req, res)) return;
      const body = JSON.parse((await readBody(req)) || '{}');
      const userPrompt = body.prompt || '';
      const model = (MODEL_MAP[body.model] || body.model || IMAGE_MODEL_DEFAULT).replace(/^ag\//, '');
      const n = Math.max(1, Math.min(Number(body.n || 1), 2));
      const renderMode = String(body.render_mode || body.quality || 'pro').toLowerCase(); // quick | pro

      let finalPrompt = userPrompt;
      if (renderMode !== 'quick') {
        // Pro mode: use Gemini 3.1 Pro as planner to improve prompt composition before image generation.
        const plannerReq = [{ role: 'user', parts: [{ text: `你是頂級影像導演與提示詞工程師。\n請把以下需求改寫成高品質、可直接用於影像生成模型的單段英文提示詞。\n要求：保留原意、補充構圖/光線/材質/鏡頭語言/風格細節、避免暴力與侵權角色。\n只輸出最終提示詞，不要解釋。\n\n需求：${userPrompt}` }] }];
        const planned = await geminiGenerateContent(IMAGE_PLANNER_MODEL, plannerReq, {});
        const plannedText = parseGeminiText(planned).trim();
        if (plannedText) finalPrompt = plannedText;
      }

      const out = [];
      for (let i = 0; i < n; i++) {
        const data = await geminiGenerateContent(model, [{ role: 'user', parts: [{ text: finalPrompt }] }], { responseModalities: ['TEXT', 'IMAGE'] });
        const b64 = parseGeminiImageBase64(data);
        if (!b64) throw new Error('no_image_returned_from_model');
        out.push({ b64_json: b64 });
      }

      return send(res, 200, {
        created: Math.floor(Date.now() / 1000),
        data: out,
        meta: { render_mode: renderMode, planner_model: renderMode === 'quick' ? null : IMAGE_PLANNER_MODEL, image_model: model }
      });
    }

    // Unified multimodal analyze endpoint (image/video/audio)
    if (req.url === '/v1/media/analyze' && req.method === 'POST') {
      if (!checkAuth(req, res)) return;
      const body = JSON.parse((await readBody(req)) || '{}');
      const model = (MODEL_MAP[body.model] || body.model || MULTIMODAL_MODEL_DEFAULT).replace(/^ag\//, '');
      const prompt = body.prompt || '請描述你看到/聽到的重點，使用繁體中文。';
      const media = Array.isArray(body.media) ? body.media : [];

      const parts = [{ text: prompt }];
      for (const m of media) {
        if (m.type === 'text' && m.text) { parts.push({ text: m.text }); continue; }

        if (m.type === 'video' && m.path) {
          // pragmatically analyze key frames
          const frames = extractVideoFramesBase64(m.path, Number(body.maxFrames || 4));
          for (const fr of frames) parts.push({ inlineData: fr });
          continue;
        }

        if (m.type === 'video' && m.dataBase64 && m.mimeType) {
          parts.push({ inlineData: { mimeType: m.mimeType, data: m.dataBase64 } });
          continue;
        }

        if (m.type === 'audio' || m.type === 'image') {
          const d = ensureDataFromItem(m);
          if (d) parts.push({ inlineData: d });
          continue;
        }
      }

      const data = await geminiGenerateContent(model, [{ role: 'user', parts }], {});
      const text = parseGeminiText(data);
      return send(res, 200, {
        id: `media-${Date.now()}`,
        object: 'media.analysis',
        model,
        output_text: text,
        raw: body.includeRaw ? data : undefined,
      });
    }

    send(res, 404, { error: { message: 'Not Found' } });
  } catch (e) {
    send(res, 500, { error: { message: e.message || String(e), type: 'proxy_error' } });
  }
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`antigravity-proxy v2 listening on http://127.0.0.1:${PORT}`);
  console.log(`backend(default): ${BACKEND_CMD}`);
  if (BACKEND_CLAUDE_CMD) console.log(`backend(claude): ${BACKEND_CLAUDE_CMD}`);
  console.log(`imageModel: ${IMAGE_MODEL_DEFAULT}`);
});
