---
name: ae
description: "AE Agent for Seeed reCamera: wiki QA evaluation, technical support for售后邮件/问题询盘, demo deployment and wiki generation. Trigger when the user mentions reCamera wiki validation, technical support, demo deployment, or asks to evaluate/score a reCamera wiki, diagnose reCamera issues, or deploy projects to reCamera."
---

# AE Agent

## Purpose

AE Agent 是一个完整的自动化工程代理，具有三大核心能力：

1. **Wiki QA（Wiki 评价）**：评估 wiki 页面的可复现性
2. **Technical Support（技术支持）**：处理售后邮件/问题询盘，诊断问题并提供解决方案
3. **Demo Output（Demo 输出）**：根据知识库部署项目到设备并生成 Wiki 文档

## Workflow Selection

根据用户输入自动选择工作流：

- Wiki 相关关键词（wiki、评价、评分、复现性）→ Wiki QA 工作流
- 问题相关关键词（问题、故障、错误、售后、询盘）→ 技术支持工作流
- 部署相关关键词（部署、demo、项目、想法）→ Demo 输出工作流

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

- `templates/wiki-report.md` - Wiki QA 报告模板
- `templates/tech-support-reply.md` - 技术支持回复模板
- `templates/demo-wiki.md` - Demo Wiki 模板

## Cloud Asset Publishing

Demo 输出工作流中，模型文件、完整证据图片和证据视频不提交到 GitHub 仓库，必须通过 Steven 本机已经登录的 rclone Google Drive remote 发布：

- Remote：`agent:`
- Wiki 根目录公开链接：`https://drive.google.com/drive/folders/1GOQUMCel7fapbJCWzEEynDIvIt-6Wf5p?usp=drive_link`
- 云端目录：`agent:reCamera_Shared/Wiki/<demo_name>/model/`
- 证据图片目录：`agent:reCamera_Shared/Wiki/<demo_name>/evidence/image/`
- 证据视频目录：`agent:reCamera_Shared/Wiki/<demo_name>/evidence/video/`
- 对外文档默认写法：贴 Wiki 根目录公开链接，并写清楚子路径 `/reCamera_Shared/Wiki/<demo_name>/model/`、`/reCamera_Shared/Wiki/<demo_name>/evidence/image/`、`/reCamera_Shared/Wiki/<demo_name>/evidence/video/`。
- 对外直达链接：可选。只有需要直达子目录时才分别使用 `rclone link` 为 `model/`、`evidence/image/`、`evidence/video/` 生成公开链接，默认不要设置过期时间。遇到 Google Drive API rate limit 时不要反复重试，直接使用 Wiki 根目录公开链接加子路径。

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
rclone copy <local-model-dir> agent:reCamera_Shared/Wiki/<demo_name>/model/ --progress
rclone lsf agent:reCamera_Shared/Wiki/<demo_name>/model/

rclone copy <local-evidence-image-dir> agent:reCamera_Shared/Wiki/<demo_name>/evidence/image/ --progress
rclone lsf agent:reCamera_Shared/Wiki/<demo_name>/evidence/image/

rclone copy <local-evidence-video-dir> agent:reCamera_Shared/Wiki/<demo_name>/evidence/video/ --progress
rclone lsf agent:reCamera_Shared/Wiki/<demo_name>/evidence/video/
```

`curl` 应返回可公开打开的 HTTP 响应（例如 200 或 Google Drive 的公开页面跳转）。验证通过后，README 和 Wiki 必须同时贴出 Wiki 根目录公开链接和三个精确子路径；模型部分列出需要下载的模型文件名，证据部分列出关键证据文件名。不要只写 `<path-to-model>` 占位。

## Workflows

工作流文件定义了具体的执行流程：

- `workflows/wiki-qa.md` - Wiki QA 工作流
- `workflows/tech-support.md` - 技术支持工作流
- `workflows/demo-output.md` - Demo 输出工作流

## Usage

### Wiki QA

当用户要求评估 wiki 页面时：
1. 读取 `workflows/wiki-qa.md`
2. 引用 `knowhubs/reCamera_KnowHub/capability-map.md`
3. 使用 `environments/seeed-recamera/` 连接设备
4. 按照工作流执行评估
5. 使用 `templates/wiki-report.md` 生成报告

### Technical Support

当用户提供问题描述时：
1. 读取 `workflows/tech-support.md`
2. 搜索 `knowhubs/reCamera_KnowHub/` 寻找类似问题
3. 使用 `environments/seeed-recamera/` 连接设备复现问题
4. 诊断根因并提出解决方案
5. 使用 `templates/tech-support-reply.md` 生成回复

### Demo Output

当用户提供项目想法时：
1. 读取 `workflows/demo-output.md`
2. 搜索 `knowhubs/reCamera_KnowHub/` 寻找相关能力
3. 使用 `environments/seeed-recamera/` 部署项目到设备
4. 验证输出并录制视频
5. 使用 `templates/demo-wiki.md` 生成 Wiki 文档

## Extension

要添加新设备支持：
1. 在 `knowhubs/` 下创建新的知识库目录（如 `knowhubs/newDevice_KnowHub/`）
2. 在 `environments/` 下创建新的环境配置目录（如 `environments/new-host-device/`）
3. 更新此 SKILL.md 的 Knowledge Hubs 和 Environments 部分
