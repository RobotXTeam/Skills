---
name: zhongwen
description: Diagnose and fix Chinese input method (中文输入法) functional failures on Linux GNOME desktops — cannot type Chinese in a terminal or Claude Code, IME intermittently stops working in one window while other apps are fine, English-only input until switching windows and back, input-source switch shortcut (Super+Space) seemingly dead, IBus/libpinyin switching problems on Wayland. Use whenever the user mentions 中文输入法, 打不出中文, 输入不了中文, 切换不了输入法, IME, ibus, or "can't type Chinese" in a Linux desktop context. For missing Chinese glyphs or broken candidate-window rendering, use the ibus skill instead.
---

# 中文输入法功能失灵诊断与修复 (zhongwen)

Fix the bug class where Chinese input *functionally* fails in one window (most
often gnome-terminal / Claude Code) on GNOME Wayland + IBus: the candidate
window never appears, keys come out as raw English, other applications still
input Chinese fine, and switching windows away and back temporarily restores it.

Root cause (GNOME ≤ 42/43, e.g. Ubuntu 22.04): with `GTK_IM_MODULE` unset, GTK
apps route IME through mutter's `zwp_text_input_v1` bridge to gnome-shell's
embedded IBus. That bridge is officially incomplete and its per-window IM focus
state intermittently goes stale, so that window's keys bypass IBus entirely.
The fix makes GTK apps talk to ibus-daemon directly over D-Bus.

See [references/details.md](references/details.md) for the full architecture
writeup, collected evidence, ruled-out suspects, and upstream sources.

## Workflow

1. Run the read-only diagnosis:

   ```bash
   bash scripts/diagnose.sh
   ```

2. Classify the failure from the output:

   - **Class A — stale Wayland bridge (this skill's fix)**: failure is
     per-window; other apps input Chinese normally at the same time; refocus
     temporarily fixes it; `GTK_IM_MODULE` is empty on a Wayland session with
     GNOME ≤ 43.
   - **Class B — IME dead everywhere**: no window can input Chinese → inspect
     ibus-daemon/engine processes and the journal first; a hot `ibus restart`
     may be needed — ask the user before doing it (it affects the live session).
   - **Class C — rendering problem** (tofu glyphs, wrong candidate font,
     misplaced candidate window) → hand off to the `ibus` skill.

3. For Class A, confirm the fix path exists (fix.sh checks these itself and
   aborts with a fallback pointer if not):
   - `/etc/profile.d/im-config_wayland.sh` present (Ubuntu Wayland hook)
   - `/usr/share/im-config/data/21_ibus.rc` sets `GTK_IM_MODULE=ibus`

4. Apply the fix (with user consent — it only takes effect after re-login):

   ```bash
   bash scripts/fix.sh
   ```

   It backs up `~/.xinputrc` to `~/.local/state/zhongwen-skill/`, runs
   `im-config -n ibus`, and prints verification steps.

5. Verify after the user's next logout/login:
   - `echo $GTK_IM_MODULE` in a fresh terminal prints `ibus`
   - Chinese input in the terminal/Claude Code stays stable (no more
     window-refocus trick needed)

6. Rollback if the user wants it (restores session default and the previous
   `~/.xinputrc`):

   ```bash
   bash scripts/fix.sh --rollback
   ```

## Safety rules

- Never log out, reboot, or restart gnome-shell/GDM yourself; the fix arms at
  the user's next login.
- Never kill or restart `gnome-terminal-server` or `ibus-daemon` while the
  user's terminals (including the current Claude session) run inside them.
- Never change input sources, switch keybindings, `per-window`, xkb-options,
  or libpinyin settings unless the user explicitly asks — this skill fixes the
  transport layer only, and preserves the user's switching habits.
- Back up `~/.xinputrc` before mutation (fix.sh does this automatically).
- When diagnose.sh flags a keyboard daemon (keyd, input-remapper, custom
  hotkey scripts), read its source before blaming it: passive `O_RDONLY`
  reads of /dev/input are harmless; only `EVIOCGRAB`/uinput injection can
  actually swallow or alter keys.

## Interim workarounds (before re-login)

When input dies in a window: switch to another window and back, or press
`Super+Space` twice in place (switch engine away and back) — both force the
bridge to resync that surface's text-input state.
