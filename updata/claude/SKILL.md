---
name: updata
description: Synchronize Steven's Codex, Gemini, and Claude skills through the GitHub-backed Skills repository. Use when the user asks to update, sync, pull, push, compare, repair, or propagate skills across the local CLI skill folders and the local Skills Git repo, especially for two-computer workflows where one machine may have newer skills than the other.
---

# Updata

## Overview

Keep the local `Skills` Git repository as the GitHub-backed exchange point for:

1. **CLI skills** — compare whole skill directories across Codex, Gemini, Claude, and the repo; copy the more complete version to the older/missing side, then commit and push repo-side updates.
2. **SSH config** — sync `~/.ssh/config` with the repo's `config` file using the same newer-wins logic.

## Paths

- Codex: `~/.codex/skills`
- Gemini: `~/.gemini/skills`
- Claude: `~/.claude/skills`

Discover the repo path instead of assuming a fixed absolute path. Steven's machines may use different checkout locations, such as:

- `/home/steven/agent/Skills`
- `/home/steven/cli/Skills`
- `/home/steven/work/cli/Skills`

Repo discovery order:

1. If the current working directory is inside a Git repo whose remote URL contains `RobotXTeam/Skills`, use that repo root.
2. Check the known locations above and use the first one that exists and has `.git`.
3. If still not found, search likely parent directories:

```bash
find /home/steven -maxdepth 5 -type d -name Skills 2>/dev/null
```

For each candidate, verify it is the intended repo:

```bash
git -C "$candidate" remote -v
```

Only treat a directory as the sync repo when its remote contains `RobotXTeam/Skills` or the user explicitly confirms it.

The repo stores skills as:

```text
SkillName/
  codex/
    SKILL.md
    ...
  gemini/
    SKILL.md
    ...
  claude/
    SKILL.md
    ...
```

Treat skill names case-insensitively when matching local folders to repo folders. Preserve existing repo casing when writing repo files.

## Workflow

1. Inspect repo state:

```bash
cd "$SKILLS_REPO"
git status --short
git remote -v
git branch --show-current
```

2. Pull the latest cloud version before comparing:

```bash
git pull --rebase --autostash
```

If pull fails because of conflicts, stop and report the conflicting files. Do not overwrite conflicted content blindly.

3. Discover skill directories:

```bash
find /home/steven/.codex/skills /home/steven/.gemini/skills /home/steven/.claude/skills -maxdepth 2 -type f -name 'SKILL.md' 2>/dev/null | sort
find "$SKILLS_REPO" -maxdepth 3 -type f -name 'SKILL.md' | sort
```

Ignore Codex system skills and local backup folders:

- `~/.codex/skills/.system`
- `~/.codex/skills-backups`
- any `.git`, `__pycache__`, `.sync-backups`, or generated cache folder

4. Compare whole skill directories, not only `SKILL.md`. Include files such as:

- `references/`
- `scripts/`
- `agents/`
- `assets/`

Use these heuristics:

- If one side is missing, copy from the existing side.
- If both exist and directory digests match, do nothing.
- If both exist and differ, prefer the more complete directory.
- Score completeness by non-whitespace character count, then byte count, then file count.
- If scores are equal, prefer the newer modification time.
- If the result is ambiguous or destructive, report the candidates and ask before copying.

5. Before replacing any existing directory, create a timestamped backup:

```bash
mkdir -p "$SKILLS_REPO/.sync-backups/YYYYMMDD-HHMMSS"
```

Keep backup paths mirroring the original absolute path where practical.

6. Copy repo-to-local when the repo version is newer or local is missing. Copy local-to-repo when the local CLI version is newer or repo is missing.

Use `rsync -a --delete` or remove-and-copy after backup. Preserve whole directories and nested files.

7. If repo files changed, commit and push only the touched skill paths:

```bash
git status --short
git add -- SkillName/tool
git commit -m "Sync local CLI skills"
git push
```

Do not use `git add .` if unrelated files are dirty.

## SSH Config Sync

After syncing skills, also sync the SSH config file.

### Paths

- Repo: `$SKILLS_REPO/config`
- Local: `~/.ssh/config`

### Comparison

Use non-whitespace character count to determine which is newer:

```bash
repo_chars=$(tr -d '[:space:]' < "$SKILLS_REPO/config" | wc -c)
local_chars=$(tr -d '[:space:]' < ~/.ssh/config | wc -c)
```

- If one side is missing, copy from the existing side.
- If both exist and character counts match, do nothing.
- If both exist and differ, the side with more non-whitespace characters is considered newer.
- If counts are equal, prefer the newer modification time.
- If the result is ambiguous, report both paths and ask before copying.

### Sync

- If repo is newer: `cp "$SKILLS_REPO/config" ~/.ssh/config`
- If local is newer: `cp ~/.ssh/config "$SKILLS_REPO/config"` then `git add config && git commit && git push` (as part of the same commit as any skill changes)

## Excluded Skills

Do NOT sync these directories — they are third-party or generated, not Steven's own skills:

- `code-review/`
- `create-project/`
- `doc-writer/`
- `frontend-design/`
- `.agents/`
- `.codex/`
- `.system/` (Codex system skills)
- `skills-backups/`

Skip these in all comparison, copy, and commit steps.

## Reporting

End with:

- skills copied from local tools to repo
- skills copied from repo to local tools
- skipped identical skills
- backup directory, if any
- whether commit and push succeeded

Mention any conflicts or ambiguous comparisons with exact paths.
