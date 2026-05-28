---
name: Weekly
description: Use when the user invokes /weekly or asks to process a local weekly meeting recording or transcript into a project memory update. This skill supports common audio/video/transcript formats, transcribes or extracts text as needed, reads project memory from memory/project_context.md and memory/summaries, compares the new meeting against prior project state, writes a Markdown output document under /home/steven/weekly/输出, outputs only action-oriented project-state deltas, and updates memory/summaries/YYYY-MM-DD.md plus memory/summaries/latest.md.
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
/weekly ./meeting.m4a me
```

If the final argument is `me`, run in speaker-aware mode and summarize only the user's own relevant project-state deltas for sections 1 and 2, using other speakers only as context.

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

## Speaker-Aware Mode

Default `/weekly <media>` behavior summarizes the whole meeting as project-state deltas. If the user invokes `/weekly <media> me`, or asks to "只记录我的部分", "只记录 Steven/我的发言", "识别我的声音", or similar, use speaker-aware mode:

- Whisper alone transcribes speech content but does not identify speakers. Speaker-aware mode requires an additional speaker diarization step or an explicit user-provided/self-labeled speaker segment.
- Current known `weekly` environment has `openai-whisper`, CPU `torch`, `torchaudio` CPU wheel, `speechbrain`, `soundfile`, and `scikit-learn`.
- The local speaker clustering helper is `/home/steven/weekly/tools/diarize_me.py`.
- Steven's default reference voice sample is `/home/steven/weekly/录音/张强声音.m4a` (about 14.4 seconds). Use it automatically for `/weekly <media> me` when present.
- The helper uses SpeechBrain ECAPA speaker embeddings plus sklearn clustering. It does not require a Hugging Face token, but it downloads the public `speechbrain/spkrec-ecapa-voxceleb` model into `/home/steven/.cache/speechbrain/spkrec-ecapa-voxceleb` on first use.
- If the environment has `ALL_PROXY=socks://...`, run the helper with normalized proxy variables, for example:

```bash
ALL_PROXY=socks5://127.0.0.1:7897/ all_proxy=socks5://127.0.0.1:7897/ \
  /home/steven/miniconda3/envs/weekly/bin/python /home/steven/weekly/tools/diarize_me.py <media> \
  --me-audio /home/steven/weekly/录音/张强声音.m4a --output <workdir>/diarization.json
```

- `--me-range START-END` is a timestamp range known to contain the user's voice. It maps that speaker cluster to `me`.
- `--me-audio <file>` is a reference audio file containing the user's voice. Prefer Steven's default reference file when it exists.
- Without `--me-audio`, `--me-range`, or another reference sample, the helper can cluster speakers but cannot know which cluster is the user.
- Treat diarization as speaker clustering first (`Speaker 1`, `Speaker 2`, etc.), not reliable real-name identification.
- To identify "my voice", prefer one of these inputs:
  - A short reference audio sample from the user.
  - A timestamp range in the meeting where only the user is speaking.
  - A manual confirmation after showing a tiny, non-sensitive paraphrased sample from each speaker cluster.
- If no reliable reference is available, do not pretend to know which speaker is the user. Ask for a reference sample or a timestamp range.
- When speaker-aware mode is active:
  - Use the user's identified speaker cluster as the primary source for sections 1 and 2.
  - Focus specifically on the user's product-manager responsibilities: product judgment, prioritization, launch/on-shelf work, GTM/content/Wiki/demo planning, customer/user insight, competitive positioning, validation/acceptance, cross-functional follow-up, risk boundaries, and roadmap implications.
  - Use other speakers only as context for decisions, constraints, deadlines, corrections, and dependencies.
  - Do not include action items stated only by other speakers unless they directly assign work to the user, require PM follow-up, or materially change the user's project state.
  - Mention uncertainty only if it materially affects confidence, such as overlapping speech or weak speaker separation.
  - The output document must still use the same three top-level sections. Do not add a "speaker notes" section.

Implementation preference:

- Use `/home/steven/weekly/tools/diarize_me.py` first for `/weekly <media> me`.
- If `/home/steven/weekly/录音/张强声音.m4a` exists, use it with `--me-audio` for `/weekly <media> me`.
- If the default reference file is missing and the user has not provided a known voice range, ask for one timestamp range where only they are speaking, then rerun with `--me-range`.
- For long recordings, prefer a coarse pass for summary filtering to keep runtime reasonable, for example `--window 3.0 --hop 6.0 --energy-percentile 50`. Use finer settings only when precision is necessary.
- Use diarization segments to filter/weight timestamped transcript turns. Include turns overlapping `me` segments as primary evidence. Use non-`me` segments only for context.
- Do not install heavier diarization stacks silently. Ask before adding tools requiring Hugging Face tokens or private model authorization.

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

## Output Document Path

Always write the user-facing Markdown output document to:

```text
/home/steven/weekly/输出/YYYY-MM-DD.md
```

Rules:

- Create `/home/steven/weekly/输出` if it does not exist.
- Use the current local date for `YYYY-MM-DD`.
- If the file already exists for today, update it instead of creating numbered duplicates unless the user explicitly asks for multiple output documents.
- The output document content must be the same three-section summary written to `memory/summaries/YYYY-MM-DD.md` and `memory/summaries/latest.md`.
- The output directory is for user-facing deliverables; `memory/summaries` remains the project-memory store.

For `/weekly <media> me`, write the user-facing Markdown output document to:

```text
/home/steven/weekly/输出/YYYY-MM-DD-me.md
```

Speaker-aware `me` output rules:

- Do not overwrite `/home/steven/weekly/输出/YYYY-MM-DD.md` unless the user explicitly asks to replace the full-meeting document.
- Do not update `memory/summaries/latest.md` from a `me`-only derivative summary unless the user explicitly asks; `latest.md` should usually remain the full project-memory state.
- The `me` document must still contain exactly the same three top-level sections as the normal output.
- It should be a PM-focused derivative summary, not a full meeting memory baseline.

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
   - For normal mode:
     - Create or update `/home/steven/weekly/输出/YYYY-MM-DD.md` as the required user-facing output document.
     - Create `memory/summaries/YYYY-MM-DD.md` using the current local date.
     - Overwrite `memory/summaries/latest.md` with the same content.
     - All three written files must contain exactly the same three top-level sections required for output.
     - If a file for today already exists, update it instead of creating numbered duplicates unless the user explicitly asks for multiple summaries.
     - Verify that `/home/steven/weekly/输出/YYYY-MM-DD.md`, `memory/summaries/YYYY-MM-DD.md`, and `memory/summaries/latest.md` exist after writing and contain the same content.
     - In the final response, explicitly tell the user the output document path and memory sync paths that were written.
   - For speaker-aware `me` mode:
     - Create or update `/home/steven/weekly/输出/YYYY-MM-DD-me.md`.
     - Do not overwrite `memory/summaries/latest.md` or the normal full-meeting output unless explicitly requested.
     - Keep the same three top-level sections required for output.
     - In the final response, explicitly tell the user the `me` output document path and mention that the full-meeting memory was not overwritten.

## Output Contract

For normal mode, the final response must first state the written document path, then contain only these three sections, in this exact order:

```markdown
文档已输出：/home/steven/weekly/输出/YYYY-MM-DD.md
同步更新：memory/summaries/YYYY-MM-DD.md
同步更新：memory/summaries/latest.md

### 1. 状态演进记录

- **已完成**：...
- **下一步**：...

### 2. 核心决策与边界

- **决策确认**：...（本周定了什么、废弃了什么）
- **职责/资源边界**：...（谁负责什么，哪些资源已锁定/缺失）

### 3. 盲点发现与思维拓展 (AI 补位)

- **隐性风险与逻辑盲点**：...（挖掘讨论中的逻辑跳跃、未经验证的假设或被忽视的连锁反应）
- **未被触及的机会与路径**：...（基于现状联想会议未涉及的、能产生 1+1>2 效果的新方向）
- **给 PM 的深度追问**：...（替 PM 向团队或 PM 自身提出挑战性问题，如极端情况下的备选方案）
```

Do not omit the document path lines. Use paths relative to the workspace when clear; use absolute paths if the workspace is ambiguous.

The written Markdown document must contain exactly these three sections, in this exact order:

```markdown
### 1. 状态演进记录

- **已完成**：...
- **下一步**：...

### 2. 核心决策与边界

- **决策确认**：...
- **职责/资源边界**：...

### 3. 盲点发现与思维拓展 (AI 补位)

- **隐性风险与逻辑盲点**：...
- **未被触及的机会与路径**：...
- **给 PM 的深度追问**：...
```

For `/weekly <media> me`, the final response must first state:

```markdown
文档已输出：/home/steven/weekly/输出/YYYY-MM-DD-me.md
未覆盖：memory/summaries/latest.md
```

Then include the same three sections from the `me` document.

Rules:

- Be concise, structured, and action-oriented.
- Emphasize changes since the previous meeting, not raw content.
- Use concrete action items with owners/deadlines when the transcript provides them.
- If owner/deadline is absent, write the action clearly without inventing facts.
- **深度补位**：在第 3 部分中，AI 必须展现出超出字面意思的分析能力，识别出参会者可能潜意识忽略的问题或技术细节。
- Do not output transcript excerpts, full meeting notes, or chronological recap.
- Do not add extra sections; fold important info into the three allowed sections.

## Memory Summary Style

Each bullet should be a project-state fact, not a conversational sentence.

Good:

- `完成前端导入流程的错误提示收敛，当前剩余问题集中在大文件解析超时。`
- `下次会议前验证付费团队场景下的权限边界，并补齐失败态文案。`

Avoid:

- `会上大家讨论了导入流程。`
- `张三说可能要看看权限问题。`
