# Root cause, evidence, and full details

## Architecture: how Chinese input reaches a GTK app on GNOME Wayland

Two possible transports:

1. **Bridge (default when `GTK_IM_MODULE` is unset)**: app (GtkIMContextWayland)
   → mutter `zwp_text_input_v1` → gnome-shell IBusManager → ibus-daemon →
   engine (libpinyin). GNOME 42's text-input-v1 support landed via mutter
   MR !3751 and is explicitly *incomplete* ("This is not a complete
   text-input-v1 implementation, some are ignored because we don't have
   equivalence in input method implementation").
2. **Direct (when `GTK_IM_MODULE=ibus`)**: app (GtkIMContextIBus from the
   ibus-gtk3 package) → D-Bus → ibus-daemon. Bypasses mutter's bridge entirely.
   This is the mature path X11 sessions have always used.

## Failure signature (Class A — stale bridge)

- IME works at session start, then **one window** (typically gnome-terminal,
  most noticed inside long-running TUI apps like Claude Code) stops getting
  IME: the candidate window never appears, keys arrive as raw English.
- **Other windows input Chinese normally at the same time** → ibus-daemon and
  the libpinyin engine are healthy; the failure is per-surface, not global.
- **Leaving the window and returning (focus-out/focus-in) restores input** →
  the bridge's per-window text-input focus state was stale and resyncs on
  refocus. This "switch away and back fixes it" pattern is the hallmark.
- Engine switching (Super+Space) does not help while stale: key events for
  that surface no longer route through IBus at all, so neither the switch
  hotkey nor libpinyin's Shift toggle reaches the engine.

Why long TUI sessions trigger it most: sustained keyboard focus on one
surface plus heavy terminal churn (fullscreen redraws, OSC title updates,
mouse-reporting toggles) — the conditions under which the incomplete bridge
loses track of the surface's text-input state. The TUI app itself (e.g.
Claude Code) is NOT at fault: IME operates at the GTK/mutter layer before
bytes ever reach the app; a refocus fixing it without restarting the app
proves the app is downstream of the failure.

## Evidence collected on the original machine (Qiang, 2026-09-06)

- Ubuntu 22.04.5, GNOME Shell 42.9-0ubuntu2.3, gnome-terminal 3.44.0,
  VTE 0.68.0, ibus 1.5.26, ibus-libpinyin 1.12.1, ibus-gtk3 installed,
  native Wayland session (`WAYLAND_DISPLAY=wayland-0`,
  `XDG_SESSION_TYPE=wayland`, `GNOME_TERMINAL_SCREEN` set → not tmux, not
  XWayland).
- `GTK_IM_MODULE` **empty**; `QT_IM_MODULE=ibus`; `XMODIFIERS=@im=ibus`;
  gsetting `org.gnome.desktop.interface gtk-im-module` = `''` → GTK apps were
  on the buggy bridge path.
- ibus-daemon (systemd user unit, `sh -c /usr/bin/ibus-daemon --panel disable
  $([ x11 ] && echo --xim)`), ibus-x11, ibus-portal, ibus-dconf,
  ibus-extension-gtk3, ibus-engine-libpinyin, ibus-engine-simple all alive
  continuously since boot; `ibus engine` = libpinyin.
- Input sources `[('ibus','libpinyin'), ('xkb','cn')]`; switch bindings
  `<Super>space` / `<Shift><Super>space` (+ XF86Keyboard) with **no
  conflicting bindings**; `xkb-options` = `@as []` (no second XKB switching
  layer); ibus hotkey triggers dconf key unset.
- Journal clean apart from a benign boot race ("Unable to connect to ibus:
  连接被拒绝" one second before systemd started the daemon) and benign
  windowsNavigator/ubuntu-dock warnings "Overwriting existing binding of
  keysym 31–39" (keysym 31..39 = digits 1..9 → duplicate Super+1..9 app
  hotkey registration; unrelated to IME).

## Ruled-out suspects (and how to rule them out)

| Suspect | Verdict | How to check |
|---|---|---|
| Custom hotkey daemon (openasr-hotkey.py, WhisperCN bridge) | harmless | Read the source: passive `os.open(path, O_RDONLY)` on `/dev/input/event*`, no `EVIOCGRAB`, no uinput → cannot swallow or alter keys |
| ibus-daemon/engine crashed or hung | ruled out | `ps -eo pid,etimes,cmd | grep ibus` — all alive since boot; other windows input Chinese during the failure |
| Missing/corrupt packages, fonts, locale | ruled out | ibus skill's diagnose.sh: dpkg -V clean, Noto Sans CJK SC resolves, LANG=zh_CN.UTF-8 |
| Keybinding conflict on Super+Space | ruled out | `gsettings list-recursively | grep -F '<Super>space'` — only the two intended bindings |
| XKB group-switch layer fighting GNOME sources | ruled out | `xkb-options` empty |
| GNOME extension interference | unlikely | enabled extension list has no keyboard/IME extensions |
| tmux / XWayland terminal weirdness | ruled out | env shows native Wayland gnome-terminal, no TMUX var |

## Fix mechanics

`im-config -n ibus` writes `~/.xinputrc` containing `run_im ibus`. On Ubuntu
Wayland sessions `/etc/profile.d/im-config_wayland.sh` sources
`/etc/X11/Xsession.d/70im-config_launch`, which reads `~/.xinputrc` and
sources `/usr/share/im-config/data/21_ibus.rc` → sets `GTK_IM_MODULE=ibus`,
`QT_IM_MODULE=ibus`, `XMODIFIERS=@im=ibus` session-wide. Requires
logout/login. Verify afterwards: `echo $GTK_IM_MODULE` in a fresh terminal
prints `ibus`.

Known cosmetic side effect: some GTK apps may log harmless IBus warnings
(ibus issue #2418). Rollback: `im-config -n default` (or restore the backup
under `~/.local/state/zhongwen-skill/`) + re-login.

## Fallback if the im-config path is unavailable

Run the terminal through XWayland: launch with `GDK_BACKEND=x11` (edit the
gnome-terminal .desktop `Exec=` or use an alias). The X11 ibus path
(`XMODIFIERS=@im=ibus` + ibus-gtk3) is mature and unaffected by the Wayland
bridge bug. Cost: the terminal renders via XWayland.

## Long-term

Ubuntu 24.04 / GNOME 46 substantially improves the Wayland input stack
(text-input handling and IBus integration); the bridge-staleness bug class is
much rarer there. If the machine is ever upgraded, re-run diagnose.sh and
consider rolling the fix back if desired.

## Upstream sources

- mutter MR !3751 "Implement basic text-input-v1 support" (explicitly
  incomplete) — https://gitlab.gnome.org/GNOME/mutter/-/merge_requests/3751
- Launchpad #2018216 "Ibus not working on gnome-terminal" (same per-window
  pattern, sleep as trigger instead of TUI churn) —
  https://bugs.launchpad.net/bugs/2018216
- ibus #2418 "Setting GTK_IM_MODULE to ibus on GNOME/Wayland may cause too
  many warnings" — https://github.com/ibus/ibus/issues/2418
- ibus #2638 "Cannot switch input method without GTK_IM_MODULE" —
  https://github.com/ibus/ibus/issues/2638
- gnome-session #166 (direction of IM module env vars on Wayland) —
  https://gitlab.gnome.org/GNOME/gnome-session/-/issues/166

## State on Qiang (original machine)

- 2026-09-06: `im-config -n ibus` applied through this workflow;
  `~/.xinputrc` written (`run_im ibus`); **pending user re-login
  verification**. Session memory note:
  `~/.claude/projects/-home-steven/memory/ibus-wayland-im-loss.md`.
- Relationship to the `ibus` skill: that one repairs Chinese *rendering*
  (fontconfig/Noto CJK/candidate-window font & layout). This one repairs
  Chinese *input transport*. Complementary — when in doubt, run the ibus
  skill's diagnose.sh for the rendering-side health check first.
