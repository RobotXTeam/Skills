#!/usr/bin/env bash
# zhongwen skill — apply or roll back the GTK_IM_MODULE=ibus fix (Class A).
#
# Apply (default):   im-config -n ibus
#   -> after the NEXT logout/login, GTK apps talk to ibus-daemon directly over
#      D-Bus, bypassing mutter's incomplete zwp_text_input_v1 bridge.
# Rollback:          fix.sh --rollback
#   -> im-config -n default, and restores the backed-up ~/.xinputrc.
#
# Takes effect ONLY after logout/login. Never touches the running session
# (restarting gnome-terminal-server or ibus-daemon now would kill every open
# terminal, including the one running Claude).
set -eu

STATE_DIR="$HOME/.local/state/zhongwen-skill"
mkdir -p "$STATE_DIR"

if [ "${1:-}" = "--rollback" ]; then
  im-config -n default
  latest_bak=$(ls -t "$STATE_DIR"/xinputrc.bak.* 2>/dev/null | head -1 || true)
  if [ -n "$latest_bak" ]; then
    if [ "$(cat "$latest_bak")" = "absent" ]; then
      rm -f ~/.xinputrc
      echo "removed ~/.xinputrc (there was none before the fix)"
    else
      cp "$latest_bak" ~/.xinputrc
      echo "restored ~/.xinputrc from $latest_bak"
    fi
  fi
  echo "Rolled back to session default. Takes effect after logout/login."
  exit 0
fi

# --- preflight: refuse if the fix cannot be delivered on this session ---
command -v im-config >/dev/null || { echo "ERROR: im-config not installed"; exit 1; }
if [ ! -r /etc/profile.d/im-config_wayland.sh ]; then
  echo "ERROR: /etc/profile.d/im-config_wayland.sh missing — im-config will NOT"
  echo "deliver GTK_IM_MODULE on this Wayland session."
  echo "Fallback: run the terminal through XWayland (GDK_BACKEND=x11) — see"
  echo "references/details.md."
  exit 1
fi
if ! grep -q 'GTK_IM_MODULE=ibus' /usr/share/im-config/data/21_ibus.rc 2>/dev/null; then
  echo "ERROR: im-config ibus profile does not set GTK_IM_MODULE=ibus — aborting."
  exit 1
fi
if [ "${XDG_SESSION_TYPE:-}" != "wayland" ]; then
  echo "NOTE: session is not Wayland (${XDG_SESSION_TYPE:-unset}). The fix is"
  echo "harmless but probably unnecessary — X11 sessions already use ibus directly."
fi

# --- backup ---
ts=$(date +%Y%m%d-%H%M%S)
if [ -r ~/.xinputrc ]; then
  cp ~/.xinputrc "$STATE_DIR/xinputrc.bak.$ts"
  echo "backed up ~/.xinputrc -> $STATE_DIR/xinputrc.bak.$ts"
else
  echo "absent" > "$STATE_DIR/xinputrc.bak.$ts"
  echo "no prior ~/.xinputrc (absence recorded in $STATE_DIR/xinputrc.bak.$ts)"
fi

# --- apply ---
im-config -n ibus
echo
echo "== new ~/.xinputrc =="
cat ~/.xinputrc

cat <<'EOF'

DONE. GTK_IM_MODULE=ibus will be set session-wide AFTER the next logout/login.
The current session is unchanged — do NOT restart gnome-terminal-server or
ibus-daemon now (it would kill every open terminal, including this one).

Interim workaround while still stuck: switch windows and back, or press
Super+Space twice in place.

Verify after re-login:
  echo $GTK_IM_MODULE     # should print: ibus
Then use Claude Code / the terminal normally and confirm Chinese input no
longer dies per-window.

Rollback anytime:  bash fix.sh --rollback   (+ logout/login)
EOF
