---
name: OpenASR
description: Use when the user invokes /openasr or asks to deploy, configure, test, or manage system-level offline voice input on Steven's Linux desktop. Current production shape is systemd-managed F8 hotkey + D-Bus ASR service + independent Qt OSD, with GNOME Shell extension disabled.
---

# OpenASR - System-Level Offline Voice Input

Current project root:

`/home/steven/work/cli/OpenASR/`

Keep all generated OpenASR files, screenshots, logs, prototypes, and test artifacts under this project directory. Do not scatter new OpenASR files under `/tmp`, `$HOME`, or unrelated workspaces except for runtime system locations that are required by systemd/D-Bus.

## Current Production Shape

Do **not** rely on the GNOME Shell extension for the live workflow. It is disabled because Shell JS caching and clipboard/text injection paths caused repeated stale behavior.

Current runtime path:

```text
User presses F8
  -> openasr-hotkey.service reads /dev/input/event*
  -> scripts/toggle-recording.sh calls org.speech2text.Service.ToggleRecording
  -> speech2text.service records/transcribes through dbus-service/service.py
  -> text injection uses Ctrl+Shift+V plain-text paste
  -> openasr-osd.service shows independent Qt OSD
```

Esc cancellation path:

```text
User presses Esc
  -> openasr-esc-cancel.service reads /dev/input/event*
  -> CancelRecording if state is recording or transcribing
```

## Active Components

| Component | Path | Runtime status |
|---|---|---|
| ASR D-Bus service | `dbus-service/service.py` | `speech2text.service` |
| Audio recorder | `dbus-service/audio_recorder.py` | Used by service |
| Text injection | `dbus-service/text_injector.py` | Uses clipboard + Ctrl+Shift+V |
| F8 hotkey listener | `scripts/openasr-hotkey.py` | `openasr-hotkey.service` |
| Esc cancel listener | `scripts/openasr-esc-cancel.py` | `openasr-esc-cancel.service` |
| Qt OSD | `scripts/openasr-qt-osd.py` | `openasr-osd.service` |
| GNOME extension | `gnome-extension/` | Keep disabled |

## Important Current Decisions

- Hotkey is **F8**, not F2/F3. F2/F3 collided with desktop/browser behavior or produced confusing duplicate paths.
- Esc must cancel immediately during recording or transcribing and must not emit recognition output.
- GNOME extension `speech2text@local` should remain disabled.
- `~/.local/share/dbus-1/services/org.speech2text.service` was disabled because it spawned orphan D-Bus service processes. Keep D-Bus ownership under `speech2text.service`; there must be exactly one `dbus-service/service.py` process.
- OSD is independent Qt, not GNOME Shell UI. It is a small black/white oval near the lower center.
- Microphone percentage-fill is currently disabled by user request. Recording UI shows a static 100% white microphone and full bar.
- Transcribing UI must look different from recording UI. Use the search/processing icon path in `openasr-qt-osd.py`, not the microphone.
- Text injection should use **Ctrl+Shift+V**, not plain Ctrl+V, so Codex CLI does not interpret the paste as an image paste and print `Failed to paste image: no image on clipboard`.
- Clipboard-based paste is still needed for reliable Chinese text injection on Wayland. Direct `ydotool type` was tested and produced unreliable Chinese/partial text.

## Verification Contract

For OpenASR work, completion means code changes **plus real functional testing**. Do not report success after only editing files or restarting services.

Minimum checks after changes:

```bash
export XDG_RUNTIME_DIR=/run/user/$(id -u)
export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus

gdbus call --session --dest org.speech2text.Service \
  --object-path /org/speech2text/Service \
  --method org.speech2text.Service.GetState

systemctl --user --no-pager is-active \
  speech2text.service openasr-hotkey.service openasr-esc-cancel.service openasr-osd.service

ps -ef | rg 'dbus-service/service.py' | rg -v rg | wc -l

gnome-extensions info speech2text@local 2>/dev/null | rg 'State' || true
```

Expected steady state:

- `GetState` returns `idle`
- all four user services are `active`
- process count for `dbus-service/service.py` is `1`
- GNOME extension state is `DISABLED`

## End-to-End Tests

Use `/dev/uinput` synthetic key events for repeatable testing when physical key presses are not practical. The tested path must go through `openasr-hotkey.service`, not only direct D-Bus calls.

Expected F8 flow:

- first F8: `idle -> recording`
- second F8: `recording -> transcribing` or `recording -> idle` if no audio data
- final state returns to `idle`
- no `TRANSCRIBE_FAIL`, `WORKER_ERROR`, or `RECORDER_ERROR`

Expected Esc flow:

- start recording
- Esc logs `cancelled ('recording',)` or cancels transcribing
- final state returns to `idle`
- no transcription result is injected after cancel

Qt OSD visual checks:

- recording: black/white oval, static full microphone, full bar, text `正在录音`
- transcribing: different search/processing icon, not microphone, text `正在识别`
- no flashing/breathing animation
- no left-top positioning regression

Text injection checks:

- confirm successful recognition logs `Transcription: ...`
- confirm successful injection logs `Injected transcription into focused input`
- use a temporary focused input window for tests when possible; output always goes to the current focused input
- avoid testing injection while Codex CLI is focused unless explicitly intended

## Runtime Commands

```bash
# Restart current stack
systemctl --user restart speech2text.service openasr-hotkey.service openasr-esc-cancel.service openasr-osd.service

# Keep GNOME extension disabled
gnome-extensions disable speech2text@local 2>/dev/null || true

# Inspect logs
journalctl --user -u speech2text.service -u openasr-hotkey.service -u openasr-esc-cancel.service -u openasr-osd.service --since '10 minutes ago' --no-pager

# Check D-Bus owner
busctl --user status org.speech2text.Service
```

## Artifact Policy

Store OpenASR generated artifacts here:

```text
/home/steven/work/cli/OpenASR/artifacts/
  debug-screenshots/
  debug-logs/
```

Do not leave OpenASR screenshots or debug logs in `/tmp`; move them under the project artifacts directory before finishing.
