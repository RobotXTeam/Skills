# 诊断与修复依据

## 目录

- 症状与原因
- 已验证配置
- 禁止操作
- 包级修复条件
- 应用缓存

## 症状与原因

目标环境是 Ubuntu 22.04.5、GNOME Xorg、IBus 1.5.26、ibus-libpinyin 1.12.1。常见症状包括候选中文间歇性空白、通知中文乱码或空白，以及运行旧修复程序后短暂恢复。

已发现的配置冲突是：GNOME 和开机守护曾强制使用不包含中文字形的 Ubuntu 字体，而中文依赖 Fontconfig 回退；旧修复程序只重置 IBus 面板并反复重启守护进程，没有固定中文字体。修复策略是显式选用完整的 `Noto Sans CJK SC`，保留 Noto Color Emoji 回退，并只热重启 IBus。

## 已验证配置

| 项目 | 值 |
|---|---|
| GNOME 界面/文档字体 | `Noto Sans CJK SC 11` |
| GNOME 等宽字体 | `Noto Sans Mono CJK SC 13` |
| IBus 自定义字体 | 开启，`Noto Sans CJK SC 12` |
| IBus 字形语言 | `use-glyph-from-engine-lang=true` |
| 输入引擎 | `libpinyin` |
| 用户 Fontconfig | Noto CJK SC 优先，Ubuntu/WenQuanYi/Emoji 回退 |
| 当前用户偏好 | 横向候选、每页 10 个 |

布局只是当前用户偏好，不是字体修复条件。修复前读取并保存 `display-style`、`lookup-table-orientation`、`lookup-table-page-size`；修复后必须保持原值。

## 禁止操作

- 不执行注销、重启、GDM 重启或 `gnome-shell --replace`。
- 不执行 `dconf reset -f /desktop/ibus/panel/`。
- 不以“兼容性”为由擅自切换横向/纵向或候选数量。
- 不修改 GNOME 显示器缩放、分数缩放或屏幕方向。
- 不删除 libpinyin 用户词库。

## 包级修复条件

先运行：

```bash
dpkg -V fontconfig fonts-noto-cjk fonts-noto-cjk-extra ibus ibus-libpinyin
```

没有输出表示包内文件通过校验。仅当包缺失或校验失败时，才安装或重装对应包。字体包正常时不要用 APT 扩大修复范围。

## 应用缓存

GNOME Shell 和 IBus 会收到实时 GSettings/Dconf 变更。个别已经运行的应用可能保留旧 Pango/Fontconfig 缓存；只关闭并重新打开该应用，不注销系统。
