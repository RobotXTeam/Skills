#!/usr/bin/env bash
set -euo pipefail

ibus_skill_notify=false
ibus_skill_restart=true
while [ "$#" -gt 0 ]; do
  case "$1" in
    --notify) ibus_skill_notify=true ;;
    --no-restart) ibus_skill_restart=false ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

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
ibus_skill_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ibus_skill_runtime="$ibus_skill_dir/assets/runtime"
ibus_skill_stamp="$(date +%Y%m%d-%H%M%S)"
ibus_skill_backup="$HOME/.local/state/ibus-skill/$ibus_skill_stamp"
mkdir -p "$ibus_skill_backup"

for ibus_skill_cmd in gsettings dconf fc-cache fc-match ibus; do
  command -v "$ibus_skill_cmd" >/dev/null 2>&1 || {
    printf 'Missing required command: %s\n' "$ibus_skill_cmd" >&2
    exit 1
  }
done

fc-match 'Noto Sans CJK SC' -f '%{family[0]}\n' | grep -qx 'Noto Sans CJK SC' || {
  printf '%s\n' 'Noto Sans CJK SC is missing. Install fonts-noto-cjk before applying the fix.' >&2
  exit 1
}

dconf dump /org/gnome/desktop/interface/ >"$ibus_skill_backup/gnome-interface.dconf"
dconf dump /desktop/ibus/ >"$ibus_skill_backup/ibus.dconf"
dconf dump /com/github/libpinyin/ibus-libpinyin/ >"$ibus_skill_backup/libpinyin.dconf"

ibus_skill_font_target="$HOME/.config/fontconfig/conf.d/60-steven-stable-ui-fonts.conf"
mkdir -p "$(dirname "$ibus_skill_font_target")"
if [ -e "$ibus_skill_font_target" ]; then
  cp -a "$ibus_skill_font_target" "$ibus_skill_backup/"
fi

ibus_skill_display_style="$(gsettings get com.github.libpinyin.ibus-libpinyin.libpinyin display-style)"
ibus_skill_engine_orientation="$(gsettings get com.github.libpinyin.ibus-libpinyin.libpinyin lookup-table-orientation)"
ibus_skill_page_size="$(gsettings get com.github.libpinyin.ibus-libpinyin.libpinyin lookup-table-page-size)"
ibus_skill_panel_orientation="$(gsettings get org.freedesktop.ibus.panel lookup-table-orientation)"
ibus_skill_engine_before="$(ibus engine 2>/dev/null || true)"

install -m 0644 "$ibus_skill_runtime/60-steven-stable-ui-fonts.conf" "$ibus_skill_font_target"
gsettings set org.gnome.desktop.interface font-name 'Noto Sans CJK SC 11'
gsettings set org.gnome.desktop.interface document-font-name 'Noto Sans CJK SC 11'
gsettings set org.gnome.desktop.interface monospace-font-name 'Noto Sans Mono CJK SC 13'
gsettings set org.freedesktop.ibus.panel use-custom-font true
gsettings set org.freedesktop.ibus.panel custom-font 'Noto Sans CJK SC 12'
gsettings set org.freedesktop.ibus.panel use-glyph-from-engine-lang true
fc-cache -r >/dev/null

if $ibus_skill_restart; then
  # 不在这里使用 `ibus restart`：它会杀掉 GNOME 会话托管的 ibus-daemon，
  # 并拉起一个参数不匹配（-drx 而非 --panel disable --xim）、不受会话服务管理的
  # 孤儿 daemon，导致候选窗口与 GNOME 集成脱节、修复结果反复异常。
  # 只重启 GNOME 托管的 IBus 会话服务，不动桌面，也不注销系统。
  if systemctl --user is-active org.freedesktop.IBus.session.GNOME.service >/dev/null 2>&1; then
    systemctl --user restart org.freedesktop.IBus.session.GNOME.service >/dev/null 2>&1 || true
  else
    systemctl --user --no-block start org.freedesktop.IBus.session.GNOME.service >/dev/null 2>&1 || true
  fi
  sleep 2
  ibus_skill_resolve_address
  if [ -n "$ibus_skill_engine_before" ]; then
    ibus engine "$ibus_skill_engine_before" 2>/dev/null || true
  fi
fi

gsettings set com.github.libpinyin.ibus-libpinyin.libpinyin display-style "$ibus_skill_display_style"
gsettings set com.github.libpinyin.ibus-libpinyin.libpinyin lookup-table-orientation "$ibus_skill_engine_orientation"
gsettings set com.github.libpinyin.ibus-libpinyin.libpinyin lookup-table-page-size "$ibus_skill_page_size"
gsettings set org.freedesktop.ibus.panel lookup-table-orientation "$ibus_skill_panel_orientation"

if $ibus_skill_notify && command -v notify-send >/dev/null 2>&1; then
  notify-send '中文显示修复' '中文字体和 IBus 已热重载，候选布局保持不变。'
fi

printf 'backup=%s\n' "$ibus_skill_backup"
printf 'ui_font=%s\n' "$(gsettings get org.gnome.desktop.interface font-name)"
printf 'candidate_font=%s\n' "$(gsettings get org.freedesktop.ibus.panel custom-font)"
printf 'display_style=%s orientation=%s page_size=%s\n' \
  "$(gsettings get com.github.libpinyin.ibus-libpinyin.libpinyin display-style)" \
  "$(gsettings get com.github.libpinyin.ibus-libpinyin.libpinyin lookup-table-orientation)" \
  "$(gsettings get com.github.libpinyin.ibus-libpinyin.libpinyin lookup-table-page-size)"
