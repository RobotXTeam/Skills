#!/usr/bin/env bash
# zhongwen skill — read-only diagnosis of Chinese IME functional failures
# on GNOME Wayland + IBus. Makes no changes. Safe to run anytime.
set -u

say() { printf '\n== %s ==\n' "$*"; }

say "Session and versions"
echo "host=$(hostnamectl hostname 2>/dev/null || hostname)"
echo "session_type=${XDG_SESSION_TYPE:-?} desktop=${XDG_CURRENT_DESKTOP:-?}"
gnome-shell --version 2>/dev/null
dpkg -l gnome-shell mutter gnome-terminal libvte-2.91-0 ibus ibus-libpinyin ibus-gtk3 2>/dev/null | awk '/^ii/{print $2"="$3}'
echo "NOTE: GNOME<=43 + empty GTK_IM_MODULE on Wayland => apps use the incomplete"
echo "      mutter text-input-v1 bridge (the Class A bug path)."

say "IM environment (the key signal)"
echo "GTK_IM_MODULE=[${GTK_IM_MODULE:-}]   # empty => Wayland bridge path (buggy); 'ibus' => direct D-Bus (fixed)"
echo "QT_IM_MODULE=[${QT_IM_MODULE:-}]"
echo "XMODIFIERS=[${XMODIFIERS:-}]"
echo "gsetting gtk-im-module=$(gsettings get org.gnome.desktop.interface gtk-im-module 2>/dev/null)"
if [ -r ~/.xinputrc ]; then echo "~/.xinputrc exists:"; cat ~/.xinputrc; else echo "~/.xinputrc: absent (im-config default)"; fi
[ -r /etc/profile.d/im-config_wayland.sh ] && echo "im-config wayland hook: present" || echo "im-config wayland hook: MISSING (fix.sh cannot work; use fallback)"
grep -q 'GTK_IM_MODULE=ibus' /usr/share/im-config/data/21_ibus.rc 2>/dev/null \
  && echo "im-config ibus profile sets GTK_IM_MODULE=ibus: yes" \
  || echo "im-config ibus profile sets GTK_IM_MODULE=ibus: NO (fix.sh cannot work)"

say "Input sources and switch bindings"
gsettings get org.gnome.desktop.input-sources sources 2>/dev/null
gsettings get org.gnome.desktop.input-sources per-window 2>/dev/null
gsettings get org.gnome.desktop.input-sources xkb-options 2>/dev/null
gsettings get org.gnome.desktop.wm.keybindings switch-input-source 2>/dev/null
gsettings get org.gnome.desktop.wm.keybindings switch-input-source-backward 2>/dev/null
echo "current ibus engine: $(ibus engine 2>&1)"
echo "conflicting <Super>space bindings:"
gsettings list-recursively 2>/dev/null | grep -F '<Super>space' || echo "  (none found)"

say "IBus processes (should all be alive for the whole session)"
ps -eo pid,etimes,cmd | grep -iE 'ibus' | grep -v grep || echo "NO IBUS PROCESSES — Class B (IME dead everywhere)"

say "libpinyin CN/EN switch settings (defaults = Shift toggles)"
dconf dump /com/github/libpinyin/ibus-libpinyin/ 2>/dev/null | grep -iE 'switch|english|shift|mode' || echo "(no custom switch keys — using defaults)"

say "Keyboard daemons that could swallow keys (verify before blaming)"
ps -eo pid,etimes,cmd | grep -iE 'keyd|input-remapper|interception|evremap|ydotool|hotkey|whisper|kanata|kmonad' | grep -v grep || echo "  (none)"
echo "REMINDER: passive O_RDONLY reads of /dev/input are harmless."
echo "          Only EVIOCGRAB / uinput injection can interfere — read the source."

say "Journal: ibus / input errors this boot"
journalctl --user -b --no-pager 2>/dev/null | grep -iE 'ibus|libpinyin|text.?input' | tail -20 || echo "  (no journal access or no entries)"

say "GNOME extensions (any keyboard-related ones?)"
gnome-extensions list --enabled 2>/dev/null || echo "  (n/a)"

cat <<'EOF'

== How to classify ==
Class A (this skill's fix): per-window IME loss, other apps fine, refocus fixes,
  GTK_IM_MODULE empty, GNOME<=43 Wayland, ibus processes healthy.
Class B: IME dead in ALL windows, or ibus processes missing/hung -> inspect
  journal, consider `ibus restart` WITH user consent.
Class C: input works but glyphs/candidate window render wrong -> use ibus skill.
EOF
