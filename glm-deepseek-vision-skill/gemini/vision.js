#!/usr/bin/env node
/**
 * GLM/DeepSeek 外挂识图脚本。
 *
 * 用法:
 *   node vision.js <图片路径> [问题]
 *   node vision.js --url <图片链接> [问题]
 *   node vision.js --latest [问题]
 *   node vision.js --clipboard [问题]
 */

"use strict";

const fs = require("fs");
const path = require("path");
const https = require("https");
const http = require("http");
const os = require("os");
const { execFileSync, spawnSync } = require("child_process");

function loadEnvFile(file) {
  let text = "";
  try { text = fs.readFileSync(file, "utf8"); } catch { return; }
  for (const line of text.split(/\r?\n/)) {
    const match = line.match(/^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$/);
    if (!match || process.env[match[1]] !== undefined) continue;
    let value = match[2];
    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }
    process.env[match[1]] = value;
  }
}

loadEnvFile(path.resolve(__dirname, ".env"));

const BASE_URL = process.env.DASHSCOPE_BASE_URL || "https://dashscope.aliyuncs.com/compatible-mode/v1";
const API_KEY = process.env.DASHSCOPE_API_KEY || "";
const MODEL = process.env.VISION_MODEL || "";
const CLAUDE_PROJECTS_DIR = process.env.CLAUDE_PROJECTS_DIR || path.join(os.homedir(), ".claude", "projects");
const REQUEST_TIMEOUT_MS = Number(process.env.VISION_TIMEOUT_MS) || 90000;
const MAX_TOKENS = Number(process.env.VISION_MAX_TOKENS) || 20000;
const COMPRESS_THRESHOLD = Number(process.env.VISION_COMPRESS_THRESHOLD) || 650 * 1024;
const MAX_SESSION_FILES = 40;
const IMAGE_EXT_RE = /\.(?:png|jpe?g|webp|gif|bmp)$/i;

function parseArgs() {
  const argv = process.argv.slice(2);
  let imageSource = "";
  let prompt = "";
  let isUrl = false;
  let useClipboard = false;
  let useLatest = false;
  let sessionFile = "";
  let noFallback = false;

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--clipboard") {
      useClipboard = true;
    } else if (arg === "--latest") {
      useLatest = true;
    } else if (arg === "--session" && argv[i + 1]) {
      sessionFile = argv[++i];
      useLatest = true;
    } else if (arg === "--no-fallback") {
      noFallback = true;
    } else if (arg === "--url" && argv[i + 1]) {
      isUrl = true;
      imageSource = argv[++i];
    } else if (!imageSource && !useClipboard && !useLatest && !arg.startsWith("--")) {
      imageSource = arg;
    } else if (!arg.startsWith("--")) {
      prompt = prompt ? `${prompt} ${arg}` : arg;
    }
  }

  if (/^https?:\/\//i.test(imageSource)) isUrl = true;
  if (!prompt) prompt = "请用中文简要描述图片，只说实际看到的内容。";
  return { imageSource, prompt, isUrl, useClipboard, useLatest, sessionFile, noFallback };
}

function tempImagePath(prefix, ext = "png") {
  return path.join(os.tmpdir(), `${prefix}-${process.pid}-${Date.now()}-${Math.random().toString(16).slice(2)}.${ext}`);
}

function getTextParts(content) {
  if (typeof content === "string") return [content];
  if (!Array.isArray(content)) return [];
  return content.filter((part) => part && part.type === "text" && typeof part.text === "string").map((part) => part.text);
}

function findExistingImagePath(text) {
  if (!text) return null;
  const candidates = [];
  const sourceMatch = text.match(/\[Image:\s*source:\s*([^\]]+)\]/i);
  if (sourceMatch) candidates.push(sourceMatch[1].trim());
  const absoluteMatches = text.match(/(?:\/[\w\-.\u0080-\uFFFF ]+)+\.(?:png|jpe?g|webp|gif|bmp)/gi) || [];
  candidates.push(...absoluteMatches);
  for (const candidate of candidates) {
    try {
      if (fs.statSync(candidate).isFile()) return candidate;
    } catch {}
  }
  return null;
}

function findBase64Image(content) {
  if (!Array.isArray(content)) return null;
  for (const part of content) {
    if (!part || typeof part !== "object") continue;
    if (part.type === "image" && part.source?.type === "base64" && part.source.data) {
      return { mime: part.source.media_type || "image/png", data: part.source.data };
    }
    const dataUrl = part.image_url?.url || part.image_url;
    if (typeof dataUrl === "string") {
      const match = dataUrl.match(/^data:(image\/[^;]+);base64,(.+)$/s);
      if (match) return { mime: match[1], data: match[2] };
    }
  }
  return null;
}

function collectSessionFiles(root) {
  const files = [];
  function walk(dir) {
    let entries = [];
    try { entries = fs.readdirSync(dir, { withFileTypes: true }); } catch { return; }
    for (const entry of entries) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) walk(full);
      else if (entry.name.endsWith(".jsonl")) {
        try { files.push({ file: full, mtime: fs.statSync(full).mtimeMs }); } catch {}
      }
    }
  }
  walk(root);
  return files.sort((a, b) => b.mtime - a.mtime).slice(0, MAX_SESSION_FILES);
}

function readSession(file) {
  let raw = "";
  try { raw = fs.readFileSync(file, "utf8"); } catch { return null; }
  const records = [];
  for (const line of raw.split("\n")) {
    if (!line.trim()) continue;
    try { records.push(JSON.parse(line)); } catch {}
  }
  return { raw, records };
}

function isUserRecord(record) {
  return record?.message?.role === "user" || record?.type === "user";
}

function sessionMatchesCwd(records) {
  const cwd = process.cwd();
  return records.some((record) => record?.cwd === cwd || record?.message?.cwd === cwd);
}

function findLatestUserImage(sessionFile = "") {
  let sessions;
  if (sessionFile) {
    sessions = [{ file: path.resolve(sessionFile), mtime: 0 }];
  } else {
    sessions = collectSessionFiles(CLAUDE_PROJECTS_DIR);
  }

  const loaded = sessions.map((entry) => {
    const parsed = readSession(entry.file);
    return parsed ? { ...entry, ...parsed, cwdMatch: sessionMatchesCwd(parsed.records) } : null;
  }).filter(Boolean);
  const cwdMatches = loaded.filter((entry) => entry.cwdMatch);
  const ordered = cwdMatches.length ? cwdMatches : loaded;

  for (const session of ordered) {
    for (let i = session.records.length - 1; i >= 0; i--) {
      const record = session.records[i];
      if (!isUserRecord(record)) continue;
      const content = record.message?.content ?? record.content;
      for (const text of getTextParts(content)) {
        const local = findExistingImagePath(text);
        if (local) return { file: local, temporary: false, from: session.file };
      }
      const image = findBase64Image(content);
      if (!image) continue;
      const subtype = (image.mime.split("/")[1] || "png").replace("jpeg", "jpg");
      const out = tempImagePath("glm-deepseek-vision-latest", subtype);
      try {
        fs.writeFileSync(out, Buffer.from(image.data, "base64"), { mode: 0o600 });
        return { file: out, temporary: true, from: `${session.file}（从 Claude 会话 base64 恢复）` };
      } catch {}
    }
  }
  return null;
}

function tryClipboardCommand(command, args, outPath) {
  const result = spawnSync(command, args, { encoding: null, maxBuffer: 32 * 1024 * 1024 });
  if (result.error || result.status !== 0 || !result.stdout?.length) return false;
  fs.writeFileSync(outPath, result.stdout, { mode: 0o600 });
  return true;
}

function readClipboardImage() {
  const outPath = tempImagePath("vision-clipboard", "png");
  if (process.platform === "darwin") {
    execFileSync("/usr/bin/swift", [path.join(__dirname, "clipboard.swift"), outPath], { stdio: "pipe" });
    return outPath;
  }
  if (process.platform === "win32") {
    execFileSync("powershell", [
      "-NoProfile", "-NonInteractive", "-Sta", "-ExecutionPolicy", "Bypass",
      "-File", path.join(__dirname, "clipboard.ps1"), "-OutFile", outPath,
    ], { stdio: "pipe", windowsHide: true });
    return outPath;
  }
  if (process.platform === "linux") {
    if (tryClipboardCommand("wl-paste", ["--no-newline", "--type", "image/png"], outPath)) return outPath;
    if (tryClipboardCommand("xclip", ["-selection", "clipboard", "-t", "image/png", "-o"], outPath)) return outPath;
    if (tryClipboardCommand("xsel", ["--clipboard", "--output"], outPath)) return outPath;
    throw new Error("Linux 剪贴板没有可读取的图片，且未找到 wl-paste/xclip/xsel；请使用 --latest 或提供图片路径");
  }
  throw new Error(`剪贴板读取暂不支持当前平台: ${process.platform}`);
}

function runImageMagick(source, outPath, size, quality) {
  const args = [source, "-auto-orient", "-resize", `${size}x${size}>`, "-background", "white", "-alpha", "remove", "-alpha", "off", "-strip", "-quality", String(quality), outPath];
  try {
    execFileSync("magick", args, { stdio: "pipe" });
    return true;
  } catch (err) {
    if (err?.code !== "ENOENT") {
      try { fs.unlinkSync(outPath); } catch {}
    }
  }
  try {
    execFileSync("convert", args, { stdio: "pipe" });
    return true;
  } catch {
    return false;
  }
}

function runFfmpeg(source, outPath, size, quality) {
  try {
    execFileSync("ffmpeg", [
      "-y", "-loglevel", "error", "-i", source,
      "-vf", `scale=${size}:${size}:force_original_aspect_ratio=decrease`,
      "-frames:v", "1", "-q:v", String(Math.max(2, Math.round((100 - quality) / 4))), outPath,
    ], { stdio: "pipe" });
    return true;
  } catch {
    return false;
  }
}

function prepareLocalImage(source) {
  const resolved = path.resolve(source);
  if (!fs.existsSync(resolved)) throw new Error(`文件不存在: ${resolved}`);
  const originalSize = fs.statSync(resolved).size;
  if (originalSize <= COMPRESS_THRESHOLD) return { file: resolved, temporary: false };

  const outPath = tempImagePath("glm-deepseek-vision-compressed", "jpg");
  const presets = [[1600, 82], [1280, 76], [1024, 70]];
  let converted = false;
  for (const [size, quality] of presets) {
    converted = runImageMagick(resolved, outPath, size, quality) || runFfmpeg(resolved, outPath, size, quality);
    if (!converted) break;
    if (fs.statSync(outPath).size <= COMPRESS_THRESHOLD) break;
  }
  if (!converted) {
    console.error(`（图片 ${(originalSize / 1048576).toFixed(1)}MB，未找到可用的 ImageMagick/ffmpeg，按原图发送）`);
    return { file: resolved, temporary: false };
  }
  const compressedSize = fs.statSync(outPath).size;
  console.error(`（图片已自动压缩：${(originalSize / 1048576).toFixed(1)}MB → ${(compressedSize / 1024).toFixed(0)}KB）`);
  return { file: outPath, temporary: true };
}

function imageToDataUrl(file) {
  const ext = path.extname(file).toLowerCase().replace(".", "");
  const mimeMap = { jpg: "jpeg", jpeg: "jpeg", png: "png", gif: "gif", webp: "webp", bmp: "bmp" };
  return `data:image/${mimeMap[ext] || "jpeg"};base64,${fs.readFileSync(file).toString("base64")}`;
}

function request(payload) {
  const url = new URL(BASE_URL.replace(/\/?$/, "/") + "chat/completions");
  const body = JSON.stringify(payload);
  const transport = url.protocol === "https:" ? https : http;
  return new Promise((resolve, reject) => {
    const req = transport.request(url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${API_KEY}`,
        "Content-Type": "application/json",
        "Content-Length": Buffer.byteLength(body),
      },
    }, (res) => {
      let data = "";
      res.on("data", (chunk) => { data += chunk; });
      res.on("end", () => {
        if (res.statusCode >= 400) return reject(new Error(`API ${res.statusCode}: ${data.slice(0, 300)}`));
        try {
          const message = JSON.parse(data)?.choices?.[0]?.message;
          resolve(message?.content || message?.reasoning_content || message?.reasoning || data);
        } catch {
          resolve(data);
        }
      });
    });
    req.setTimeout(REQUEST_TIMEOUT_MS, () => req.destroy(new Error(`请求超时（${REQUEST_TIMEOUT_MS}ms）`)));
    req.on("error", reject);
    req.write(body);
    req.end();
  });
}

function showUsage() {
  console.error("用法: node vision.js <图片路径> [问题]");
  console.error("      node vision.js --url <图片链接> [问题]");
  console.error("      node vision.js --latest [问题]");
  console.error("      node vision.js --clipboard [问题]");
}

async function main() {
  if (!API_KEY || API_KEY === "sk-xxx" || !MODEL || MODEL === "xxx") {
    console.error("请在脚本同目录 .env 中配置 DASHSCOPE_API_KEY、VISION_MODEL 和 DASHSCOPE_BASE_URL。");
    process.exit(1);
  }

  const args = parseArgs();
  const temporaryFiles = [];
  let source = args.imageSource;
  let isUrl = args.isUrl;

  try {
    if (args.useClipboard) {
      if (source || args.useLatest) throw new Error("--clipboard 不能和图片路径、--url 或 --latest 同时使用");
      source = readClipboardImage();
      temporaryFiles.push(source);
      console.error("（已读取系统剪贴板图片）");
    } else if (args.useLatest || !source || (!isUrl && !fs.existsSync(path.resolve(source)))) {
      const latest = findLatestUserImage(args.sessionFile);
      if (latest) {
        source = latest.file;
        isUrl = false;
        if (latest.temporary) temporaryFiles.push(latest.file);
        console.error(`（已恢复当前 Claude 会话的最新图片；来源：${latest.from}）`);
      } else if (!args.noFallback) {
        try {
          source = readClipboardImage();
          temporaryFiles.push(source);
          console.error("（Claude 会话中未找到图片，已回退读取系统剪贴板）");
        } catch (clipboardError) {
          throw new Error(`Claude 会话中未找到图片；${clipboardError.message}`);
        }
      } else if (!source) {
        showUsage();
        process.exit(1);
      }
    }

    if (!source) {
      showUsage();
      process.exit(1);
    }

    let imageUrl = source;
    if (!isUrl) {
      const prepared = prepareLocalImage(source);
      if (prepared.temporary) temporaryFiles.push(prepared.file);
      imageUrl = imageToDataUrl(prepared.file);
    }

    const result = await request({
      model: MODEL,
      messages: [{ role: "user", content: [
        { type: "text", text: args.prompt },
        { type: "image_url", image_url: { url: imageUrl } },
      ] }],
      stream: false,
      max_tokens: MAX_TOKENS,
    });
    console.log(result);
  } catch (err) {
    console.error("识图失败:", err.message);
    process.exitCode = 1;
  } finally {
    for (const file of new Set(temporaryFiles)) {
      try { fs.unlinkSync(file); } catch {}
    }
  }
}

main();
