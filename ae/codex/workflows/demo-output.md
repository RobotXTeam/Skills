# Demo 输出工作流

## 目的

根据想法或开源项目，使用知识库部署到设备上，验证部署成功，录制运行效果，生成 Wiki 文档。

## 输入

- 项目想法或开源项目 URL
- 目标设备（reCamera）

## 目录结构

### 本机环境

```
~/work/reCamera_demo/                    ← 工作根目录
├── <demo_name>/                         ← 如 ppocr_v4、depth_anything
│   ├── DEPLOY_REPORT.md                 ← 部署报告
│   ├── <demo_name>_Demo_Wiki.md         ← Wiki 文档
│   ├── models/                          ← 模型文件（不提交）
│   ├── calib/                           ← 校准数据（不提交）
│   └── evidence/
│       ├── image/                       ← 证据图片（关键帧提交，完整图片上传 Google Drive）
│       │   ├── frame_0000.png
│       │   └── ...
│       └── video/                       ← 证据视频（不提交，上传 Google Drive）
│           └── demo.mp4
│
├── export_*.py                          ← 导出脚本
└── *.mlir, *.npz                        ← 中间产物（不提交）

/home/seeed/sscma-example-sg200x/solutions/sesg-project/<demo_name>/  ← 仓库目录
├── CMakeLists.txt                       ← ✅ 提交
├── README.md                            ← ✅ 提交
├── main/*.cpp, *.h                      ← ✅ 提交
├── *.py                                 ← ✅ 提交
├── wiki/                                ← ✅ 提交
│   ├── <demo_name>_Demo_Wiki.md
│   └── DEPLOY_REPORT.md
├── evidence/                            ← ✅ 提交少量关键截图
│   └── frame_*.png                      ← 只提交关键帧（5-10 张）
└── model/                               ← ❌ .gitignore 忽略；模型发布到 Google Drive
```

### 云端资产发布目录

所有 demo 的运行包、模型、完整证据图片、证据视频统一上传到 Steven 已登录的 rclone Google Drive remote：

```text
agent:reCamera_Shared/Wiki/<demo_name>/run/
agent:reCamera_Shared/Wiki/<demo_name>/model/
agent:reCamera_Shared/Wiki/<demo_name>/evidence/image/
agent:reCamera_Shared/Wiki/<demo_name>/evidence/video/
```

`run/` 是**开箱即跑包**：放交叉编译好的 reCamera 可执行程序 + `run/README.md` + 必要运行时依赖（一般一个可执行文件即可；GB28181 类需带 SIP `.so` 库和一键脚本）。用户拉 `run/` + `model/` 就能不出 Google Drive、不编译、直接在 reCamera 跑通。

公开 Wiki 根目录链接固定为：

```text
https://drive.google.com/drive/folders/1GOQUMCel7fapbJCWzEEynDIvIt-6Wf5p?usp=drive_link
```

公开文档中可写成：

```text
/reCamera_Shared/Wiki/<demo_name>/run/
/reCamera_Shared/Wiki/<demo_name>/model/
/reCamera_Shared/Wiki/<demo_name>/evidence/image/
/reCamera_Shared/Wiki/<demo_name>/evidence/video/
```

README 和 Wiki 默认贴固定 Wiki 根目录链接，并写清楚以上子路径，让用户按 demo 名称进入对应文件夹。只有需要直达子目录时才额外尝试 `rclone link`；如果遇到 Google Drive API rate limit，不要反复重试直达链接。

### seeed 设备环境

```
~/reCamera_demo/                         ← 工作根目录
├── <demo_name>/                         ← 如 ppocr_v4、depth_anything
│   ├── DEPLOY_REPORT.md
│   ├── <demo_name>_Demo_Wiki.md
│   ├── models/
│   └── evidence/
│       ├── image/
│       └── video/

/home/seeed/sscma-example-sg200x/solutions/sesg-project/<demo_name>/  ← 仓库目录
```

## 工作流程

### 1. 搜索知识库

在 `knowhubs/reCamera_KnowHub/` 中搜索相关能力：
- 搜索 `capability-map.md` 中的类似项目
- 搜索 `model-conversion.md` 中的模型转换方法
- 搜索 `cpp-runtime.md` 中的运行时配置

### 2. 规划部署步骤

基于搜索结果规划部署步骤：
- 获取代码/模型
- 环境准备
- 编译/构建
- 部署到设备
- 运行和验证

### 3. 部署到设备

执行部署步骤：
- 使用环境配置连接到设备
- 按照规划的步骤操作
- 记录每个步骤的结果

### 4. 验证输出

验证部署是否成功：
- 截图查看输出内容
- 检查日志文件
- 验证功能是否正常

### 5. 录制视频流

录制设备的运行效果：
- 使用主机拉取设备的视频流
- 录制视频窗口
- 传回本机

### 6. 用户审核

在本机打开视频，由用户审核：
- 内容是否正确
- 效果是否通过
- 是否需要调整

### 7. 生成 Wiki 文档

如果用户审核通过，生成 Wiki 文档：
- 使用模板 `templates/demo-wiki.md`
- 按照现有 wiki 蒸馏格式
- 可以调用 AI 生成图片
- 使用效果图片和视频
- 写完传回本机

### 8. 上传运行包、模型和证据到 Google Drive

在推送 GitHub 前，把本 demo 的**运行包(run/)**、模型、完整证据图片、证据视频发布到 Google Drive。`run/` 让用户拉下来直接在 reCamera 跑通：

```bash
# 在 Steven 本机执行，使用已登录的 rclone remote
rclone listremotes
rclone lsd agent:reCamera_Shared/Wiki --max-depth 1

# 准备 run/ 开箱即跑包（本机目录，例如 <demo>/run/）：
#   - reCamera 可执行程序（交叉编译好的 RISC-V ELF，file 应显示 ld-musl-riscv64*）
#   - README.md（精简开箱即跑说明：下载哪些文件、放设备哪、停服务、运行命令 threshold 0.60、验收）
#   - 必要运行时依赖（普通 demo 无需；GB28181 类带 lib/*.so + 一键脚本）

# 创建目标目录
rclone mkdir agent:reCamera_Shared/Wiki/<demo_name>/run/
rclone mkdir agent:reCamera_Shared/Wiki/<demo_name>/model/
rclone mkdir agent:reCamera_Shared/Wiki/<demo_name>/evidence/image/
rclone mkdir agent:reCamera_Shared/Wiki/<demo_name>/evidence/video/

# 上传 run/ 开箱即跑包（可执行程序 + README + 运行时依赖，整目录上传）
rclone copy <local-run-dir> agent:reCamera_Shared/Wiki/<demo_name>/run/ --progress
rclone lsf -R agent:reCamera_Shared/Wiki/<demo_name>/run/

# 上传模型
rclone copy <local-model-dir> agent:reCamera_Shared/Wiki/<demo_name>/model/ \
  --filter "+ *.cvimodel" \
  --filter "+ *.onnx" \
  --filter "+ *.pth" \
  --filter "+ *.pt" \
  --filter "+ *.json" \
  --filter "+ *.txt" \
  --filter "- *" \
  --progress

# 上传完整证据图片
rclone copy <local-evidence-image-dir> agent:reCamera_Shared/Wiki/<demo_name>/evidence/image/ \
  --filter "+ *.png" \
  --filter "+ *.jpg" \
  --filter "+ *.jpeg" \
  --filter "+ *.webp" \
  --filter "+ *.gif" \
  --filter "- *" \
  --progress

# 上传证据视频
rclone copy <local-evidence-video-dir> agent:reCamera_Shared/Wiki/<demo_name>/evidence/video/ \
  --filter "+ *.mp4" \
  --filter "+ *.mov" \
  --filter "+ *.mkv" \
  --filter "+ *.webm" \
  --filter "- *" \
  --progress

# 核对文件列表
rclone lsf -R agent:reCamera_Shared/Wiki/<demo_name>/run/
rclone lsf agent:reCamera_Shared/Wiki/<demo_name>/model/
rclone lsf agent:reCamera_Shared/Wiki/<demo_name>/evidence/image/
rclone lsf agent:reCamera_Shared/Wiki/<demo_name>/evidence/video/

# 用未认证 HTTP 请求确认用户能访问固定 Wiki 根目录
WIKI_ROOT_LINK="https://drive.google.com/drive/folders/1GOQUMCel7fapbJCWzEEynDIvIt-6Wf5p?usp=drive_link"
curl -L -I "$WIKI_ROOT_LINK"
```

要求：
- `agent:` 必须可访问；如果存在但访问失败，在 Steven 本机执行 `rclone config reconnect agent:` 重新授权。
- 如果 `agent:` 不存在，用 `rclone config` 新建 Google Drive remote，remote 名称固定为 `agent`，scope 使用 `drive`。
- 上传目录固定为 `agent:reCamera_Shared/Wiki/<demo_name>/run/`、`.../model/`、`.../evidence/image/`、`.../evidence/video/`，不要改放 GitHub Release 或 LFS。
- **每个 demo 必须有 `run/` 开箱即跑包**：用户拉 `run/` + `model/` 就能不出 Google Drive、不编译、直接在 reCamera 跑通。`run/` 含 reCamera 可执行程序 + `run/README.md` + 必要运行时依赖。
- 默认不要为每个 demo 子目录生成独立分享链接；使用固定 Wiki 根目录公开链接，减少 Google Drive API rate limit 风险。
- `curl -L -I "$WIKI_ROOT_LINK"` 至少能拿到公开 Google Drive 页面响应；如果返回权限错误，必须修复父目录分享权限后再写文档。
- README 和 Wiki 必须同时包含固定 Wiki 根目录链接、四个子路径（run/model/image/video）、`run/` 可执行文件名、模型文件清单、关键证据图片/视频文件清单。

### GitHub 仓库的目的与规范

明确此 GitHub 仓库的目的是**上传完整的项目代码并提供给外部用户，以便用户能够自行复刻 demo 与 wiki**。
因此，代码必须绝对完整，确保用户拿到手之后可以直接在相应的编译环境中编译出能够在 reCamera 上运行的可执行程序。在提交的代码、脚本以及说明文档中，**绝对不要包含本机部署的绝对路径**（例如 `/home/steven/...` 或 `/home/seeed/...`），**必须使用相对路径**或通用环境变量来代替。

### 9. 推送到 GitHub

用户确认 demo 和文档无误后，提交并推送到 GitHub：

```bash
# 在 seeed 上执行（仓库位于 /home/seeed/sscma-example-sg200x）
cd /home/seeed/sscma-example-sg200x

# 确保代理已配置（seeed 需要走 Clash 代理访问 GitHub）
git config --global http.proxy http://127.0.0.1:7890
git config --global https.proxy http://127.0.0.1:7890

# 拉取最新代码
git pull origin main

# 复制 wiki 和证据到仓库
mkdir -p solutions/sesg-project/<demo_name>/wiki
mkdir -p solutions/sesg-project/<demo_name>/evidence

# 复制 Wiki 文档
cp ~/reCamera_demo/<demo_name>/<demo_name>_Demo_Wiki.md solutions/sesg-project/<demo_name>/wiki/
cp ~/reCamera_demo/<demo_name>/DEPLOY_REPORT.md solutions/sesg-project/<demo_name>/wiki/

# 复制证据截图（只复制关键帧，1-3 张）
cp ~/reCamera_demo/<demo_name>/evidence/image/frame_0000.png solutions/sesg-project/<demo_name>/evidence/
cp ~/reCamera_demo/<demo_name>/evidence/image/frame_0005.png solutions/sesg-project/<demo_name>/evidence/

# 添加新 demo 文件（不要添加大模型文件）
git add solutions/sesg-project/<demo_name>/

# 提交
git commit -m "Add <demo_name> demo with wiki and evidence"

# 推送
git push origin main
```

**注意事项：**
- 不要提交 `.cvimodel`、`.onnx`、`.pth`、`.pt` 等大模型文件到 GitHub
- 大模型文件必须上传到 `agent:reCamera_Shared/Wiki/<demo_name>/model/`，README 和 Wiki 里写固定 Wiki 根目录公开链接和精确子路径
- 证据截图只复制关键帧（1-3 张）到 GitHub，完整证据图片上传到 `agent:reCamera_Shared/Wiki/<demo_name>/evidence/image/`
- 证据视频不提交到 GitHub，上传到 `agent:reCamera_Shared/Wiki/<demo_name>/evidence/video/`
- 提交前检查 `git status` 确认没有意外文件

## 推送到 GitHub 的内容

| 内容 | 路径 | 说明 |
|------|------|------|
| Wiki 文档 | `solutions/sesg-project/<demo>/wiki/<demo>_Demo_Wiki.md` | 公开文档 |
| 部署报告 | `solutions/sesg-project/<demo>/wiki/DEPLOY_REPORT.md` | 内部报告 |
| 证据截图 | `solutions/sesg-project/<demo>/evidence/frame_*.png` | 关键帧（1-3 张） |
| 源代码 | `solutions/sesg-project/<demo>/main/*.cpp` | C++ 代码 |
| 构建配置 | `solutions/sesg-project/<demo>/CMakeLists.txt` | CMake 配置 |
| Python 脚本 | `solutions/sesg-project/<demo>/*.py` | 接收器等 |
| README | `solutions/sesg-project/<demo>/README.md` | 项目说明 |

**不提交到 GitHub：**
- 完整证据图片，改上传到 `agent:reCamera_Shared/Wiki/<demo>/evidence/image/`
- 证据视频，改上传到 `agent:reCamera_Shared/Wiki/<demo>/evidence/video/`
- 模型文件（`.cvimodel`、`.onnx`、`.pth`、`.pt`），改上传到 `agent:reCamera_Shared/Wiki/<demo>/model/`
- 中间产物（`.mlir`、`.npz`）
- 校准数据（`calib/`）

面向外部读者的文档硬性要求：
- README、Wiki、demo 文档和项目源码中的注释/示例命令不要出现 Steven 本机绝对路径，例如 `/home/steven/...`、`/home/steven/work/...`、`/home/steven/下载/...`。
- 用相对路径、环境变量或占位路径替代，例如 `$REPO_ROOT`、`$SDK_ROOT`、`$TOOLCHAIN_BIN`、`$DEMO_DIR`、`<path-to-model>`。
- 如果真实命令依赖 Steven 环境，公开文档中使用可迁移的伪命令，并在内部报告另行记录真实路径。
- 默认不要把 `.cvimodel`、`.onnx`、`.pth`、`.pt` 等大模型文件、完整证据图片或证据视频提交或推送到 GitHub 仓库。必须分别上传到 `agent:reCamera_Shared/Wiki/<demo_name>/model/`、`agent:reCamera_Shared/Wiki/<demo_name>/evidence/image/`、`agent:reCamera_Shared/Wiki/<demo_name>/evidence/video/`，并在公开 README/Wiki 里写固定 Wiki 根目录公开链接、精确子路径和文件清单。不要使用 Release/LFS 作为默认方案，也不要只留下 `<path-to-model>` 占位。

## 输出

- 设备上部署成功的项目
- 少量关键证据截图 - 提交到 GitHub
- 完整证据图片和证据视频 - 上传到 Google Drive 并在 README/Wiki 贴公开链接
- Wiki 文档 - 提交到 GitHub
- 部署报告 - 提交到 GitHub

## 引用

- 知识库：`knowhubs/reCamera_KnowHub/`
- 环境配置：`environments/seeed-recamera/`
- Demo 模板：`templates/demo-wiki.md`
