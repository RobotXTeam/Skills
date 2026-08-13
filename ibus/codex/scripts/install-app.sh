#!/usr/bin/env bash
set -euo pipefail

ibus_skill_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ibus_skill_runtime="$ibus_skill_dir/assets/runtime"
ibus_skill_stamp="$(date +%Y%m%d-%H%M%S)"
ibus_skill_backup="$HOME/.local/state/ibus-skill/app-install-$ibus_skill_stamp"
mkdir -p "$ibus_skill_backup"

ibus_skill_fix_target="$HOME/.local/bin/ibus-pinyin-display-fix"
ibus_skill_guard_target="$HOME/.local/bin/stable-ui-font-guard"
ibus_skill_app_target="$HOME/.local/share/applications/ibus-pinyin-display-fix.desktop"
ibus_skill_autostart_target="$HOME/.config/autostart/stable-ui-font-guard.desktop"
ibus_skill_font_target="$HOME/.config/fontconfig/conf.d/60-steven-stable-ui-fonts.conf"
ibus_skill_reload_uuid="safe-shell-reload@steven.local"
ibus_skill_reload_source="$ibus_skill_runtime/$ibus_skill_reload_uuid"
ibus_skill_reload_target="$HOME/.local/share/gnome-shell/extensions/$ibus_skill_reload_uuid"

for ibus_skill_target in \
  "$ibus_skill_fix_target" \
  "$ibus_skill_guard_target" \
  "$ibus_skill_app_target" \
  "$ibus_skill_autostart_target" \
  "$ibus_skill_font_target" \
  "$ibus_skill_reload_target"; do
  if [ -e "$ibus_skill_target" ]; then
    cp -a "$ibus_skill_target" "$ibus_skill_backup/$(basename "$ibus_skill_target")"
  fi
done

mkdir -p \
  "$HOME/.local/bin" \
  "$HOME/.local/share/applications" \
  "$ibus_skill_reload_target" \
  "$HOME/.config/autostart" \
  "$HOME/.config/fontconfig/conf.d"

install -m 0755 "$ibus_skill_runtime/ibus-pinyin-display-fix" "$ibus_skill_fix_target"
install -m 0755 "$ibus_skill_runtime/stable-ui-font-guard" "$ibus_skill_guard_target"
install -m 0644 "$ibus_skill_runtime/60-steven-stable-ui-fonts.conf" "$ibus_skill_font_target"
install -m 0644 "$ibus_skill_reload_source/metadata.json" "$ibus_skill_reload_target/metadata.json"
install -m 0644 "$ibus_skill_reload_source/extension.js" "$ibus_skill_reload_target/extension.js"

ibus_skill_tmp_app="$(mktemp)"
ibus_skill_tmp_autostart="$(mktemp)"
trap 'rm -f "$ibus_skill_tmp_app" "$ibus_skill_tmp_autostart"' EXIT
sed "s|@FIX_SCRIPT@|$ibus_skill_fix_target|g" \
  "$ibus_skill_runtime/ibus-pinyin-display-fix.desktop.in" >"$ibus_skill_tmp_app"
sed "s|@FONT_GUARD@|$ibus_skill_guard_target|g" \
  "$ibus_skill_runtime/stable-ui-font-guard.desktop.in" >"$ibus_skill_tmp_autostart"
install -m 0644 "$ibus_skill_tmp_app" "$ibus_skill_app_target"
install -m 0644 "$ibus_skill_tmp_autostart" "$ibus_skill_autostart_target"

fc-cache -r >/dev/null 2>&1 || true
command -v update-desktop-database >/dev/null 2>&1 \
  && update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
if command -v gnome-extensions >/dev/null 2>&1; then
  if gnome-extensions info "$ibus_skill_reload_uuid" >/dev/null 2>&1; then
    gnome-extensions enable "$ibus_skill_reload_uuid"
  else
    printf 'extension_pending_shell_reload=%s\n' "$ibus_skill_reload_uuid"
  fi
fi

printf 'installed_app=%s\n' "$ibus_skill_app_target"
printf 'backup=%s\n' "$ibus_skill_backup"
