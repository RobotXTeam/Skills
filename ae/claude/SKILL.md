---
name: ae
description: "AE Agent for Seeed reCamera: demo deployment and wiki generation. Trigger when the user mentions reCamera demo deployment, asks to deploy projects to reCamera, or generate wiki documentation for reCamera demos."
---

# AE Agent

## Essential Warning
必须明确一点，这个skill是要求把demo部署到reCamera上，不是本机，也不是seeed主机，一定是部署到reCamera上！！！

## Purpose
AE Agent 是一个自动化工程代理，用于根据知识库部署项目到 reCamera 设备，验证部署成功，录制运行效果，并生成 Wiki 文档。


## 执行入口

当此 skill 被调用时，必须：

1. **读取 ARGUMENTS**：位于 SKILL.md 末尾，包含用户的输入
2. **确认工作流**：此 skill 仅支持 Demo Output 工作流
3. **执行工作流**：严格按照 `workflows/demo-output.md` 步骤执行

## Knowledge Hubs

知识库包含设备特定的技术知识：

- `knowhubs/reCamera_KnowHub/` - reCamera 设备知识库
  - `capability-map.md` - 能力清单
  - `cpp-runtime.md` - C++ 运行时基线
  - `model-conversion.md` - 模型转换方法论
  - `receiver-recording.md` - 接收端录制方法

## Environments

环境配置包含测试环境的连接信息：

- `environments/seeed-recamera/` - 当前测试环境
  - `network.md` - 网络配置
  - `credentials.md` - 凭据信息
  - `toolchain.md` - 工具链配置
  - `scripts/` - 辅助脚本

## Templates

模板文件用于生成标准化输出：

- `templates/demo-wiki.md` - Demo Wiki 模板

## Cloud Asset Publishing

Demo 输出工作流中，模型文件、完整证据图片和证据视频不提交到 GitHub 仓库，必须通过 Steven 本机已经登录的 rclone Google Drive remote 发布：

- Remote：`agent:`
- Wiki 根目录公开链接：`https://drive.google.com/drive/folders/1GOQUMCel7fapbJCWzEEynDIvIt-6Wf5p?usp=drive_link`
- 运行包目录：`agent:reCamera_Shared/Wiki/<demo_name>/run/`
- 模型目录：`agent:reCamera_Shared/Wiki/<demo_name>/model/`
- 证据图片目录：`agent:reCamera_Shared/Wiki/<demo_name>/evidence/image/`
- 证据视频目录：`agent:reCamera_Shared/Wiki/<demo_name>/evidence/video/`
- 对外文档默认写法：贴 Wiki 根目录公开链接，并写清楚子路径 `/reCamera_Shared/Wiki/<demo_name>/run/`、`/reCamera_Shared/Wiki/<demo_name>/model/`、`/reCamera_Shared/Wiki/<demo_name>/evidence/image/`、`/reCamera_Shared/Wiki/<demo_name>/evidence/video/`。
- 对外直达链接：可选。只有需要直达子目录时才分别使用 `rclone link` 为 `run/`、`model/`、`evidence/image/`、`evidence/video/` 生成公开链接，默认不要设置过期时间。遇到 Google Drive API rate limit 时不要反复重试，直接使用 Wiki 根目录公开链接加子路径。

## GitHub Completeness Gate

所有推送到 `RobotXTeam/sscma-example-sg200x` 的 demo 代码必须是完整项目代码，不是只保存本机可运行的碎片：

- GitHub 仓库必须包含所有源码、构建脚本、CMake/Make 配置、README、部署脚本和少量关键证据，使外部用户 clone 后可以按文档编译出 reCamera 可执行程序。
- 大模型、完整证据图片/视频、运行时大库不放 GitHub；必须放到 Google Drive 的固定 `run/`、`model/`、`evidence/` 子目录，并在 README/Wiki 写清楚文件名和路径。
- 用户 clone GitHub 后，再从 Google Drive 拉取 README/Wiki 指定的模型和必要运行库，应能编译出完整可执行文件，并能部署到 reCamera 正常运行。
- 不能把只在 Steven 或 seeed 私有绝对路径下存在的文件当作隐式依赖；公开构建命令必须使用相对路径或 `$REPO_ROOT`、`$SDK_ROOT`、`$TOOLCHAIN_BIN`、`$DEMO_DIR` 等可迁移变量。

推送 GitHub 之后、最终发布/写定 Wiki 之前，必须做一次 GitHub 干净克隆验证闭环：

1. 在固定测试线/干净验证目录中从 GitHub 拉取最新 `main`，确认 commit 是刚推送的版本。
2. 按公开 README/Wiki 的构建命令编译 demo，确认产物是 reCamera 可运行的 RISC-V musl ELF。
3. 从 Google Drive 拉取该 demo 声明的 `run/`、`model/` 和必要运行库。
4. 将干净克隆编译出的可执行程序和 Drive 资产部署到 reCamera，按公开运行命令启动并采集验收证据。
5. 只有 GitHub clone -> Drive assets -> build -> deploy -> run -> evidence 全链路通过，才算一次完整的 demo GitHub 推送；否则回到 `seeed:/home/seeed/sscma-example-sg200x` 修改、重新提交推送，并重复验证直到通过。

### run/ 开箱即跑包（核心要求）

Google Drive 是给用户拉运行所需文件的地方。**每个 demo 必须有 `run/` 文件夹，让用户拉下来配合 `model/` 就能直接在 reCamera 上跑通，无需编译、不出 Google Drive 就能拿齐运行所需的一切。** `run/` 内容：

- **reCamera 可执行程序**（交叉编译好的 RISC-V ELF，如 `onvif_yolo`、`gb28181_client`、`ppocr-reader`）。一般一个可执行文件即可。
- **`README.md`**：精简的开箱即跑说明——下载哪些文件（含 `../model/` 的模型）、放到设备什么目录、停哪些服务、完整运行命令（threshold 使用实测效果最好的值，优先从相对较低置信度起步调参）、怎么验收。面向"拉下来简单看一下就能跑"的用户。
- **运行时依赖**：仅当系统库不够时才放。例如 GB28181 需要的 SIP 库 `lib/libeXosip2.so.* libosip2.so.* libosipparser2.so.*`；一键脚本如 `run_rtmp.sh` / `run_on_device.sh`。普通 demo 设备自带 `/mnt/system/lib` 等即可，无需额外库。
- 可执行文件不要 strip 也行，但要确认是设备架构（`file` 应显示 `RISC-V ... ld-musl-riscv64*`）。
- 模型仍放 `model/`，不要重复塞进 `run/`；README 指引用户把两者放到设备同一目录。

## Visual Quality Baseline Gate

视觉类 demo 不能只验证“跑通、无报错、模型能加载、有输出”，必须验证“效果接近开源项目在 NVIDIA/Python 链路下的预期输出”：

- 每个视觉类 demo 必须准备固定评测输入，包含本地图片或本地视频；实时摄像头 demo 也要先录制原始视频作为固定输入。
- 必须在 seeed NVIDIA 主机上运行开源项目官方 Python 示例或官方推荐推理脚本，生成 teacher baseline：`baseline.jsonl`、可视化帧和 `baseline.mp4`。
- 必须让 reCamera 使用同一批输入运行推理，生成 `recamera.jsonl`、可视化帧和 `recamera.mp4`。
- 必须对 `baseline.jsonl` 和 `recamera.jsonl` 做帧级对齐评分，生成 `eval/qa_report.md` 和失败样本。
- 默认质量门：检测类 `F1 >= 0.70` 且关键类别 `recall >= 0.70`；OCR/分类/分割等类型按 workflow 定义可解释指标，默认目标不低于 `0.70`。
- 评分未通过时，不能录制最终证据、生成 Wiki 草稿、上传资产、推送 GitHub 或写成功记录；必须优先修复输入预处理、后处理、label map、阈值、NMS、坐标还原、模型转换精度等问题。



执行 demo 输出时必须先验证 rclone 登录状态：

```bash
rclone listremotes
rclone lsd agent:reCamera_Shared/Wiki --max-depth 1
```

登录/重连规则：

- 如果 `agent:` 存在但访问失败，先在 Steven 本机执行 `rclone config reconnect agent:` 重新走 OAuth 授权。
- 如果 `agent:` 不存在，在 Steven 本机执行 `rclone config` 新建 Google Drive remote，名称必须为 `agent`，scope 使用 `drive`。
- 配置文件位于 `~/.config/rclone/rclone.conf`，正常应包含可自动续期的 `refresh_token`。
- 不要把 rclone token、配置文件内容或任何密钥写入 wiki、README、GitHub 仓库或报告。

云端资产上传完成后必须验证用户可访问。默认验证 Wiki 根目录公开链接即可：

```bash
WIKI_ROOT_LINK="https://drive.google.com/drive/folders/1GOQUMCel7fapbJCWzEEynDIvIt-6Wf5p?usp=drive_link"
curl -L -I "$WIKI_ROOT_LINK"
```

上传命令：

```bash
rclone copy <local-run-dir> agent:reCamera_Shared/Wiki/<demo_name>/run/ --progress
rclone lsf -R agent:reCamera_Shared/Wiki/<demo_name>/run/

rclone copy <local-model-dir> agent:reCamera_Shared/Wiki/<demo_name>/model/ --progress
rclone lsf agent:reCamera_Shared/Wiki/<demo_name>/model/

rclone copy <local-evidence-image-dir> agent:reCamera_Shared/Wiki/<demo_name>/evidence/image/ --progress
rclone lsf agent:reCamera_Shared/Wiki/<demo_name>/evidence/image/

rclone copy <local-evidence-video-dir> agent:reCamera_Shared/Wiki/<demo_name>/evidence/video/ --progress
rclone lsf agent:reCamera_Shared/Wiki/<demo_name>/evidence/video/
```

`curl` 应返回可公开打开的 HTTP 响应（例如 200 或 Google Drive 的公开页面跳转）。验证通过后，README 和 Wiki 必须同时贴出 Wiki 根目录公开链接和精确子路径（`run/`、`model/`、`evidence/image/`、`evidence/video/`）；运行包部分列出可执行文件名和 `run/README.md`，模型部分列出需要下载的模型文件名，证据部分列出关键证据文件名。不要只写 `<path-to-model>` 占位。`run/` 必须能让用户拉下来直接跑通。

## Workflows

工作流文件定义了具体的执行流程：

- `workflows/demo-output.md` - Demo 输出工作流

## Success Records

成功记录文件记录每次完整执行 Demo 输出工作流（0-18 全部步骤）并成功完成的 demo：

- `success-records.md` - Demo 成功记录

**重要**：只有完成全部 0-18 步（从检查历史记录、质量基准评测到最终写定 Wiki）才能写入成功记录。用户中途停止、某一步失败、质量门未通过、或 GitHub 验证闭环未通过，都不算成功，不写入记录。

## Usage

### Demo Output

当用户提供项目想法时：
1. 读取 `workflows/demo-output.md`
2. 搜索 `knowhubs/reCamera_KnowHub/` 寻找相关能力
3. 准备固定评测输入，在 seeed NVIDIA 主机运行官方 Python baseline
4. 使用 `environments/seeed-recamera/` 部署项目到 reCamera，并用同一输入运行推理
5. 对齐 baseline/reCamera 结果，质量门通过后录制证据并生成 Wiki 文档

## 默认参数偏好

- **YOLO 检测置信度阈值不要固定为某个值**。所有 reCamera YOLO demo（onvif_yolo / rtmp_yolo / gb28181_yolo 等）应根据固定评测输入、baseline 对齐结果和最终视频效果调参，优先使用相对较低的置信度起步以保证目标能被检出，再用 NMS、类别过滤和多模态复核控制误检。文档和脚本不要写死置信度数值；必须写清楚本 demo 实测采用的 threshold、选择原因、效果截图/视频和质量报告结论。示例写法：`run_rtmp.sh <url> <threshold> 2`、`rtmp_yolo <model> <url> <threshold> 2`、`onvif_yolo <model> <threshold> ...`。

## Extension

要添加新设备支持：
1. 在 `knowhubs/` 下创建新的知识库目录（如 `knowhubs/newDevice_KnowHub/`）
2. 在 `environments/` 下创建新的环境配置目录（如 `environments/new-host-device/`）
3. 更新此 SKILL.md 的 Knowledge Hubs 和 Environments 部分
