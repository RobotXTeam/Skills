#!/usr/bin/env bash
set -uo pipefail

ibus_skill_resolve_address() {
  local ibus_skill_machine ibus_skill_display ibus_skill_file
  ibus_skill_machine="$(cat /etc/machine-id 2>/dev/null || true)"
  ibus_skill_display="${DISPLAY:-:0}"
  ibus_skill_display="${ibus_skill_display##*:}"
  ibus_skill_display="${ibus_skill_display%%.*}"
  ibus_skill_file="$HOME/.config/ibus/bus/${ibus_skill_machine}-unix-${ibus_skill_display}"
  if [ -r "$ibus_skill_file" ]; then
    IBUS_ADDRESS="$(sed -n 's/^IBUS_ADDRESS=//p' "$ibus_skill_file")"
    export IBUS_ADDRESS
  fi
}

ibus_skill_resolve_address

printf '%s\n' '== OS and session =='
cat /etc/os-release 2>/dev/null | sed -n '1,12p'
printf 'session_type=%s desktop=%s display=%s\n' "${XDG_SESSION_TYPE:-unknown}" "${XDG_CURRENT_DESKTOP:-unknown}" "${DISPLAY:-unknown}"

printf '%s\n' '== Locale =='
locale 2>&1
printf '%s\n' '-- /etc/default/locale'
sed -n '1,80p' /etc/default/locale 2>/dev/null || true

printf '%s\n' '== Packages =='
dpkg -l fontconfig fonts-noto-cjk fonts-noto-cjk-extra ibus ibus-gtk3 ibus-libpinyin 2>/dev/null | awk '$1 ~ /^(ii|hi|rc|un)/ {print}'
printf '%s\n' '-- package verification'
dpkg -V fontconfig fonts-noto-cjk fonts-noto-cjk-extra ibus ibus-libpinyin 2>&1 || true

printf '%s\n' '== Font resolution =='
for ibus_skill_query in \
  'sans-serif:lang=zh-cn' \
  'serif:lang=zh-cn' \
  'Noto Sans CJK SC' \
  'Ubuntu:lang=zh-cn:charset=4e2d' \
  ':charset=1f514'; do
  printf '%-38s -> ' "$ibus_skill_query"
  fc-match "$ibus_skill_query" -f '%{family[0]} | %{style[0]} | %{file}\n' 2>&1 || true
done
printf '%s\n' '-- user fontconfig'
find "$HOME/.config/fontconfig" -maxdepth 3 -type f -print 2>/dev/null | sort

printf '%s\n' '== GNOME and IBus settings =='
for ibus_skill_setting in \
  'org.gnome.desktop.interface font-name' \
  'org.gnome.desktop.interface document-font-name' \
  'org.gnome.desktop.interface monospace-font-name' \
  'org.freedesktop.ibus.panel use-custom-font' \
  'org.freedesktop.ibus.panel custom-font' \
  'org.freedesktop.ibus.panel use-glyph-from-engine-lang' \
  'org.freedesktop.ibus.panel lookup-table-orientation' \
  'com.github.libpinyin.ibus-libpinyin.libpinyin display-style' \
  'com.github.libpinyin.ibus-libpinyin.libpinyin lookup-table-orientation' \
  'com.github.libpinyin.ibus-libpinyin.libpinyin lookup-table-page-size'; do
  set -- $ibus_skill_setting
  printf '%s %s = ' "$1" "$2"
  gsettings get "$1" "$2" 2>&1 || true
done
printf 'input_sources='; gsettings get org.gnome.desktop.input-sources sources 2>&1 || true
printf 'engine='; ibus engine 2>&1 || true
printf 'ibus_version='; ibus version 2>&1 || true

printf '%s\n' '== Recent related journal =='
journalctl --user --since '30 minutes ago' --no-pager 2>/dev/null \
  | rg -i 'ibus|font|pango|glyph|locale|gnome-shell' \
  | tail -n 120 || true
