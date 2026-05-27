---
name: Weekly
description: Use when the user invokes /weekly or asks to process a local weekly meeting recording or transcript into a project memory update. This skill supports common audio/video/transcript formats, transcribes or extracts text as needed, reads project memory from memory/project_context.md and memory/summaries, compares the new meeting against prior project state, outputs only action-oriented project-state deltas, and updates memory/summaries/YYYY-MM-DD.md plus memory/summaries/latest.md.
---

# Weekly Project Memory Agent

This skill is a project memory updater, not a meeting-summary tool. Treat each meeting as a state transition for a continuously evolving project model.

## Invocation

Expected user shapes:

```text
/weekly ./meeting.mp3
/weekly ./meeting.m4a
/weekly ./meeting.mp4
/weekly ./meeting.txt
```

Accept local meeting media or transcript files:

- Audio: `.mp3`, `.m4a`, `.wav`, `.aac`, `.flac`, `.ogg`, `.opus`, `.wma`, `.amr`.
- Video: `.mp4`, `.mov`, `.mkv`, `.webm`, `.avi`, `.m4v`.
- Existing transcripts: `.txt`, `.md`, `.srt`, `.vtt`.

For unsupported extensions, inspect the file type with `file` and use `ffmpeg`/Whisper if it is a readable media container.

## Local Transcription Environment

On Steven's workstation, use the prepared local environment:

- Conda env: `weekly`
- Python: `/home/steven/miniconda3/envs/weekly/bin/python`
- Whisper command wrapper: `/home/steven/.local/bin/whisper`
- Real Whisper binary: `/home/steven/miniconda3/envs/weekly/bin/whisper`
- FFmpeg: `/usr/bin/ffmpeg`
- Runtime: CPU only at last setup check (`torch.cuda.is_available() == False`)

Do not create a new conda environment unless this one is broken. The `whisper` command is already on PATH and points directly to the `weekly` env binary.

Default transcription command for this machine:

```bash
whisper <media> --model small --language Chinese --output_format txt --output_dir <workdir> --fp16 False
```

Notes:

- First use of a Whisper model downloads the model into `/home/steven/.cache/whisper`.
- CPU transcription can be slow for long meetings; prefer `small` as the default balance.
- Use `base` or `tiny` only for quick rough checks.
- Use `medium` only when accuracy is more important than runtime.
- If a model cache checksum warning appears, delete the bad cached `.pt` file under `/home/steven/.cache/whisper` and rerun.

## Memory Paths

Resolve the memory root in this order:

1. `./memory` in the current working directory, if it contains `project_context.md` or `summaries/`.
2. `/home/steven/weekly/memory`, if present.
3. Ask only if neither exists.

Required files to read:

- `memory/project_context.md`: project background, PRD, and user's role.
- `memory/summaries/latest.md`: previous meeting state.
- `memory/summaries/*.md`: historical meeting records for long-term trend context.

If a required file is empty or missing, create/read it as an empty baseline and mention the gap only if it materially limits confidence.

## Strict Workflow

1. **Extract or transcribe meeting text**
   - For `.txt`/`.md`/`.srt`/`.vtt`, read the file directly as the transcript source.
   - For audio files, use a local Whisper-capable command if available. Prefer, in order:
     - `whisper <media> --model small --language Chinese --output_format txt --output_dir <workdir> --fp16 False`
     - Use `--model medium` only when accuracy is more important than runtime and the machine has enough GPU/CPU time.
     - `python -m whisper <media> ...`
     - an existing repo/local transcription command, if the workspace provides one.
   - For video files, prefer direct Whisper input if supported. If Whisper fails or is slow on the container, extract audio first:
     - `ffmpeg -i <video> -vn -ac 1 -ar 16000 <workdir>/meeting_audio.wav`
     - Then run Whisper on `meeting_audio.wav`.
   - If language is uncertain, use auto-detection rather than forcing Chinese.
   - Keep transcript as an internal working artifact. Do not output the full transcript.

2. **Load project memory**
   - Read `project_context.md`.
   - Read `summaries/latest.md`.
   - Read all historical summaries under `summaries/`, sorted by date/name.
   - Use history to understand continuity, repeated risks, stale tasks, and product direction changes.

3. **Understand the meeting as a state update**
   - Extract only project-state changes, decisions, completed work, blocked or delayed tasks, new risks, changed assumptions, product/PM insights, and next actions.
   - Do not preserve conversation order unless it matters to state change.

4. **Compare against previous state**
   - Identify what changed since `latest.md`.
   - Mark tasks as completed, carried over, delayed, blocked, newly created, or changed in scope.
   - Detect product-understanding changes, user/requirement changes, technical/architecture judgment changes, and PM-level implications.

5. **Write memory updates**
   - Create `memory/summaries/YYYY-MM-DD.md` using the current local date.
   - Overwrite `memory/summaries/latest.md` with the same content.
   - The written summary must contain exactly the same three top-level sections required for output.
   - If a file for today already exists, update it instead of creating numbered duplicates unless the user explicitly asks for multiple summaries.

## Output Contract

The final response must contain only these three sections, in this exact order:

```markdown
### 1. 本次会议后完成的工作

- ...

### 2. 下次会议前需要完成的工作

- ...

### 3. 产品 / 项目管理洞察

- 产品理解变化：...
- 用户或需求认知变化：...
- 技术或架构判断变化：...
- PM 层面的启发：...
```

Rules:

- Be concise, structured, and action-oriented.
- Emphasize changes since the previous meeting, not raw content.
- Use concrete action items with owners/deadlines when the transcript provides them.
- If owner/deadline is absent, write the action clearly without inventing facts.
- Do not output transcript excerpts, full meeting notes, or chronological recap.
- Do not add extra sections such as "摘要", "风险", "决定", or "附录"; fold important risks and decisions into the three allowed sections.

## Memory Summary Style

Each bullet should be a project-state fact, not a conversational sentence.

Good:

- `完成前端导入流程的错误提示收敛，当前剩余问题集中在大文件解析超时。`
- `下次会议前验证付费团队场景下的权限边界，并补齐失败态文案。`

Avoid:

- `会上大家讨论了导入流程。`
- `张三说可能要看看权限问题。`
