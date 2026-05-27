---
name: opendesign
description: OpenDesign 项目的完整上下文。涵盖：Ubuntu 22.04 Linux AppImage 编译、自定义品牌（名称 OpenDesign + 官方图标）、安装路径、更新/启动脚本、常见问题排查。当用户提到 OpenDesign、open-design、open design、nexu-io、AppImage 编译、设计工具桌面应用时触发。
---

# OpenDesign 项目完整上下文

## 项目概述

- **仓库**: https://github.com/nexu-io/open-design
- **说明**: 开源 AI 前端设计工具，替代 Anthropic Claude Design。本地优先，支持 71+ 品牌设计系统。
- **技术栈**: Node.js ~24 + pnpm@10.33.2 + Electron + Next.js 16

## 本地目录结构

```
~/work/cli/OpenDesign/
├── open-design/                    # git clone 的源码仓库（只读，仅用于 git pull）
│   ├── .tmp/tools-pack/            # 编译产物（已 gitignore，不影响 git pull）
│   │   └── out/linux/namespaces/default/builder/
│   │       └── OpenDesign-default.AppImage    # 编译出的 AppImage
│   ├── tools/pack/src/linux.ts     # 已修改：PRODUCT_NAME → "OpenDesign"
│   ├── tools/pack/resources/linux/
│   │   ├── icon.png                # 已替换：官方 SVG 定制图标
│   │   └── open-design.desktop.template  # 已修改：菜单显示名称
│   └── apps/desktop/src/main/runtime.ts  # Electron 窗口标题
├── assets/                         # 自定义品牌资源（git 仓库外，不受 git pull 影响）
│   ├── icon.svg                    # 图标 SVG 源文件
│   └── icon.png                    # 图标 PNG 备份
├── update-and-build.sh             # 一键更新+编译脚本
└── run.sh                          # 启动脚本
```

## 运行时文件路径

| 文件 | 路径 |
|------|------|
| AppImage（安装版） | `~/.local/bin/OpenDesign.default.AppImage` |
| 预提取目录（秒启动） | `~/.local/share/OpenDesign/app/squashfs-root/` |
| 桌面入口 | `~/.local/share/applications/open-design-default.desktop` |
| 应用图标（多尺寸） | `~/.local/share/icons/hicolor/{16-512}x{16-512}/apps/open-design-default.png` |
| IPC Socket | `/tmp/open-design/ipc/default/desktop.sock` |

## 品牌修改详情

### 应用名称：Open Design → OpenDesign（无空格）

修改了 3 个位置：
- `tools/pack/src/linux.ts` 第 32-33 行：`PRODUCT_NAME = "OpenDesign"`、`APP_IMAGE_PRODUCT_NAME = "OpenDesign"`
- `tools/pack/resources/linux/open-design.desktop.template`：Name/GenericName/Comment/StartupWMClass
- `apps/desktop/src/main/runtime.ts`：Electron 窗口 `<title>` 和 `title` 属性

### 图标：基于 open-design.ai 官方 favicon.svg 制作

- 源文件：`https://open-design.ai/favicon.svg`
- 设计：深色圆角背景(#1a1814→#14110b) + 奶油色椭圆环(#efe7d2) + 珊瑚红斜线(#ed6f5c)
- 安装后 9 种尺寸全覆盖（16/24/32/48/64/96/128/256/512px）
- 源文件备份在 `assets/icon.svg`（不受 git pull 影响）

## 关键环境依赖

- **Node.js**: v24.15.0（通过 nvm 安装，设为 default）
  ```bash
  source ~/.nvm/nvm.sh && nvm use 24
  ```
- **pnpm**: 10.33.2（通过 corepack 管理）
  ```bash
  corepack enable
  ```
- **编译工具**: ImageMagick (`convert`)、gtk-update-icon-cache、update-desktop-database

## 日常操作命令

### 更新 + 重新编译（远程仓库有更新时执行）

```bash
cd ~/work/cli/OpenDesign
./update-and-build.sh
```

此脚本自动完成：git pull → 恢复品牌配置 → 安装依赖 → 重建 tools-pack → 编译 AppImage → 安装 → 预提取 → 配置菜单和图标 → 刷新桌面数据库

### 启动应用

```bash
cd ~/work/cli/OpenDesign
./run.sh
```

或从 GNOME 应用程序菜单搜索 "OpenDesign"。

### 仅编译（不更新）

```bash
source ~/.nvm/nvm.sh && nvm use 24 && corepack enable
cd ~/work/cli/OpenDesign/open-design
pnpm --filter @open-design/tools-pack build
pnpm tools-pack linux build --to appimage
pnpm tools-pack linux install
```

## 已知问题及解决方案

### 1. 应用打不开（EADDRINUSE 错误）

**原因**: 上次异常退出后 `/tmp/open-design/ipc/default/desktop.sock` 残留。

**解决**:
```bash
pkill -f "squashfs-root/OpenDesign" 2>/dev/null
rm -rf /tmp/open-design/ipc
```
`run.sh` 和桌面入口的 Exec 行已内置此清理逻辑。

### 2. 菜单名称没变

**原因**: GNOME Shell 缓存 `.desktop` 文件，不会自动刷新。

**解决**: 
- X11: `Alt+F2` → 输入 `r` → 回车
- Wayland: `Alt+F2` + `r` 不可用（Shell 就是合成器本身）。替代方案：
  1. 注销重新登录（最可靠）
  2. 终端执行：`killall -3 gnome-shell`（发送 SIGQUIT，部分版本支持）
  3. GNOME 45+ 可在系统菜单（右上角面板）→ 按住 Alt 键，挂起按钮会变成"重启 Shell"

### 3. 第一次启动很慢

**原因**: `--appimage-extract-and-run` 需解压 ~200MB 到 `/tmp/`，耗时 20-30 秒。

**解决**: 已预提取到 `~/.local/share/OpenDesign/app/squashfs-root/`，启动方式改为直接运行 AppRun。

### 4. Electron sandbox/GPU 错误

在无 GPU 或 SSH 环境下启动时可能出现：
- `GPU process launch failed`
- `zygote communication failed`
- `VAAPI version too old`

这些是非关键警告，在正常桌面环境下不会出现。`--no-sandbox` 已添加在启动参数中。

### 5. git pull 后品牌配置被覆盖

`update-and-build.sh` 会自动处理：
- 用 `sed` 把名称改回 "OpenDesign"
- 从 `assets/icon.*` 恢复自定义图标
- 重建 `tools-pack` 包使名称生效

## 编译流程说明

1. `pnpm --filter @open-design/tools-pack build` — 用 esbuild 把 `src/linux.ts` + `src/mac/constants.ts` 等打包到 `dist/index.mjs`
2. `pnpm tools-pack linux build --to appimage` — 完整构建流程：
   - 编译所有 workspace 包（contracts → sidecar-proto → sidecar → platform → daemon → web → desktop → packaged）
   - 收集 tarball 并组装 Electron app
   - 用 electron-builder 打包成 AppImage
   - 输出到 `.tmp/tools-pack/out/linux/namespaces/default/builder/`
3. `pnpm tools-pack linux install` — 复制 AppImage 到 `~/.local/bin/`，生成 desktop 文件

## 重要注意事项

- **不要使用根目录的 `pnpm build` 或 `pnpm test`**，此项目要求包级命令
- **不要推送代码到远程**，我们只是消费者
- **`node_modules/` 和 `.tmp/` 已 gitignore**，不会影响 `git pull`
- **修改的源文件只有 3 个**（linux.ts、desktop.template、icon.png），冲突概率低
- **tools-pack 的 esbuild 产物**（`dist/index.mjs`）中，linux 代码使用独立的 `PRODUCT_NAME3` 变量（esbuild 自动重命名避免冲突）
