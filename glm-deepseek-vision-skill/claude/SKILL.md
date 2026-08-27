---
name: glm-deepseek-vision-skill
description: Analyze images ONLY when the active underlying model is DeepSeek or GLM (Zhipu), which have no native vision. Do NOT use this skill for any other model (Claude, Qwen, GPT, Gemini, etc. — they can see images natively or have their own mechanisms). For DeepSeek/GLM sessions, use whenever the user pastes or attaches an image, provides a local image path or URL, asks what an image contains, requests OCR or screenshot analysis, or the message contains an image placeholder without an accessible path. The bundled helper restores image attachments from local session records, compresses oversized images, sends them to the configured multimodal model, and returns text.
---

# Vision Helper

Use this skill ONLY when the active underlying model is DeepSeek or GLM (Zhipu). If the current model is anything else (Claude, Qwen, GPT, Gemini, etc.), do NOT use this skill — skip it entirely.

How to determine the active underlying model, in order:

1. Self-knowledge: DeepSeek knows it is DeepSeek; GLM knows it is 智谱清言/GLM. If you know your own identity with confidence, use that.
2. If unsure, resolve the mapping for YOUR tier only. The harness states which model/tier you are running as (e.g. opus/sonnet/haiku/fable, or a display name). Then read the `env` block of `~/.claude/settings.json` (and project `.claude/settings*.json`) and check ONLY the variable that maps your tier:
   - tier opus/sonnet/haiku/fable → `ANTHROPIC_DEFAULT_<TIER>_MODEL`
   - otherwise → the top-level `"model"` field or `ANTHROPIC_MODEL`
   Trigger only if THAT value contains `deepseek`, `glm`, `zhipu`, or `bigmodel`. A config that merely maps some OTHER tier (e.g. haiku or subagents) to DeepSeek does NOT mean the current session is DeepSeek.
3. If still undetermined, do NOT use this skill.

When the current model is DeepSeek or GLM, it does not support native image input. Make one helper call, then answer with its result.

For a pasted or attached image without a reliable path, recover the newest image from the current Claude session:

```bash
node /home/steven/.claude/skills/glm-deepseek-vision-skill/vision.js --latest "请用中文简要描述图片，只说实际看到的内容。"
```

For a local image:

```bash
node /home/steven/.claude/skills/glm-deepseek-vision-skill/vision.js "<absolute image path>" "请用中文简要描述图片，只说实际看到的内容。"
```

For an image URL:

```bash
node /home/steven/.claude/skills/glm-deepseek-vision-skill/vision.js --url "<image url>" "请用中文简要描述图片，只说实际看到的内容。"
```

Use the clipboard only when the user explicitly refers to an image currently copied to the clipboard and no Claude attachment exists:

```bash
node /home/steven/.claude/skills/glm-deepseek-vision-skill/vision.js --clipboard "请用中文简要描述图片，只说实际看到的内容。"
```

The helper supports common Linux clipboard tools (`wl-paste`, `xclip`, `xsel`), macOS and Windows. Claude session recovery does not require a clipboard utility.

Rules:

- Trigger ONLY when the active underlying model is DeepSeek or GLM (Zhipu). For every other model, do nothing vision-related with this skill.
- Always use the absolute path to `vision.js`.
- Use an absolute image path for local files, or `--url` for remote images.
- Use `--latest` for pasted/attached images with no reliable path. Do not search `/tmp` or reuse an arbitrary file from `~/.claude/image-cache`.
- Use Chinese for descriptions unless the user asks otherwise.
- Do not manually compress images; the helper compresses large local/session images automatically.
- Do not retry, inspect temporary files, or debug after a normal response. Retry only after an actual error and a concrete correction.
- Configuration lives in `.env` next to `vision.js` (`DASHSCOPE_API_KEY`, `VISION_MODEL`, `DASHSCOPE_BASE_URL`). The default output budget is 20,000 tokens; override it with `VISION_MAX_TOKENS` only when needed. Never print or commit the API key.
- If the API call fails, report the error to the user and ask them to check the key, model, or base URL.
