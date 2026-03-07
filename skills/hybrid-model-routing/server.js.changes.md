// AGProxy server.js — Backup 2026-03-06
// Key changes:
// 1. Bug Fix (line ~378): canned response no longer injected when tool_calls are present
//    if ((!trimmed || trimmed === 'NO_REPLY') && !backendResp.tool_calls)
// 2. Smart routing (lines ~228-284): ag/* Gemini + tools → Manager; ag/* Gemini no tools → CLI
// 3. Debug logging (lines ~193-194): added console.log for Manager response tool_calls detection
//
// See full diff at:
//   ~/.openclaw/workspace/tools/antigravity-proxy/server.js
