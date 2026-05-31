#!/bin/bash
# Agent Reach Skill 同步脚本
# 将 Claude 版本同步到 Codex 和 Gemini

set -e

SRC="$HOME/.claude/skills/agent-reach"
CODEX="$HOME/.codex/skills/agent-reach"
GEMINI="$HOME/.gemini/skills/agent-reach"

for DST in "$CODEX" "$GEMINI"; do
  mkdir -p "$DST/references"
  cp "$SRC/SKILL.md" "$DST/"
  cp "$SRC/references/"*.md "$DST/references/"
  echo "✅ 已同步到 $DST"
done

echo "🎉 全部同步完成"
