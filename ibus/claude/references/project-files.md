# 项目文件与部署映射

## 目录

- Skill 文件
- 本机部署位置
- 备份
- 验证

## Skill 文件

| 文件 | 用途 |
|---|---|
| `assets/runtime/ibus-pinyin-display-fix` | Zenity 桌面修复应用主体 |
| `assets/runtime/ibus-pinyin-display-fix.desktop.in` | 应用启动器模板 |
| `assets/runtime/stable-ui-font-guard` | 登录后字体一致性守护 |
| `assets/runtime/stable-ui-font-guard.desktop.in` | 自动启动模板 |
| `assets/runtime/60-steven-stable-ui-fonts.conf` | Fontconfig 中文/Emoji 回退链 |
| `scripts/diagnose.sh` | 只读诊断 |
| `scripts/apply-fix.sh` | 无注销热修复 |
| `scripts/install-app.sh` | 安装或更新桌面应用 |

## 本机部署位置

| Skill 资源 | 本机路径 |
|---|---|
| 修复应用 | `~/.local/bin/ibus-pinyin-display-fix` |
| 应用启动器 | `~/.local/share/applications/ibus-pinyin-display-fix.desktop` |
| 字体守护 | `~/.local/bin/stable-ui-font-guard` |
| 自动启动 | `~/.config/autostart/stable-ui-font-guard.desktop` |
| 字体规则 | `~/.config/fontconfig/conf.d/60-steven-stable-ui-fonts.conf` |
| 应用运行记录 | `~/.local/state/ibus-pinyin-display-fix/` |

## 备份

Skill 脚本在修改前把 Dconf 和现有文件备份到：

```text
~/.local/state/ibus-skill/YYYYMMDD-HHMMSS/
~/.local/state/ibus-skill/app-install-YYYYMMDD-HHMMSS/
```

## 验证

```bash
bash -n scripts/diagnose.sh scripts/apply-fix.sh scripts/install-app.sh
fc-match 'sans-serif:lang=zh-cn'
fc-match ':charset=1f514'
gsettings get org.gnome.desktop.interface font-name
gsettings get org.freedesktop.ibus.panel custom-font
gsettings get org.freedesktop.ibus.panel use-glyph-from-engine-lang
ibus engine
```

先把 `.desktop.in` 模板中的 `@FIX_SCRIPT@` 和 `@FONT_GUARD@` 替换成绝对路径，再用 `desktop-file-validate` 检查生成文件。模板本身不应直接部署。
