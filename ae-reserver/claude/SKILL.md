---
name: ae-reserver
description: "AE Agent for Seeed reCamera (deploy host: seeed-reserver): demo deployment and wiki generation. Trigger when the user mentions reCamera demo deployment, asks to deploy projects to reCamera, or generate wiki documentation for reCamera demos."
---

# AE Agent

## Essential Warning
必须明确一点，这个skill是要求把demo部署到reCamera上，不是本机，也不是seeed-reserver主机，一定是部署到reCamera上！！！

seeed-reserver 是部署工作所在的主机环境（Steven 本机 SSH 别名 `seeed-reserver`，登录用户 `seeed0`，LAN 192.168.2.194，Ubuntu 24.04.3 x86_64，无 NVIDIA GPU）。Python teacher baseline 在 seeed-reserver 上一律纯 CPU 推理：demo 以 CNN 为主，CPU 完全可以跑，不需要另外安排 GPU 主机；只是速度较慢，评测输入按正常规模准备即可，超大输入注意控制帧数避免等太久。

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
  - `device-ops.md` - 设备操作（访问、SSH/SCP、服务、隧道截图、模型、证据）
  - `project-layout.md` - demo 项目放置和目录规范
  - `live-osd-display.md` - 本机实时 OSD 显示（UDP 直推，用户审核一等能力）

## Environments

环境配置包含测试环境的连接信息：

- `environments/seeed-reserver-recamera/` - 当前测试环境（部署主机 seeed-reserver，192.168.2.194）
  - `network.md` - 网络配置
  - `credentials.md` - 凭据信息
  - `toolchain.md` - 工具链配置
  - `scripts/` - 辅助脚本（含实时 OSD 三件套：`udp_sender.py` 设备侧推流、`udp_viewer.py` 本机弹窗、`udp_relay.py` seeed-reserver 中继 fallback；详见 `knowhubs/reCamera_KnowHub/live-osd-display.md`；reCamera USB 动态 IP 用 `reserver_usb_ip.sh` 在 seeed-reserver 上探测，禁止硬编码 192.168.42.x 旧值）

## Templates

模板文件用于生成标准化输出：

- `templates/wiki-output.md` - Demo Wiki 模板

## Cloud Asset Publishing

模型文件、完整证据图片和证据视频不提交到 GitHub 仓库，必须通过 Steven 本机已登录的 rclone Google Drive remote 发布。固定常量：

- Remote：`agent:`（只配置在 Steven 本机，seeed-reserver 上没有）
- Wiki 根目录公开链接：`https://drive.google.com/drive/folders/1GOQUMCel7fapbJCWzEEynDIvIt-6Wf5p?usp=drive_link`
- 四个固定目录：`agent:reCamera_Shared/Wiki/<demo_name>/run/`、`.../model/`、`.../evidence/image/`、`.../evidence/video/`
- 对外文档默认写法：贴 Wiki 根目录公开链接并写清四个子路径；默认不为每个子目录生成独立直达链接（避免 Google Drive API rate limit）

**门禁**：上传必须在推送 GitHub 之前完成；上传后用 `curl -L -I` 验证根链接可公开访问，权限错误必须先修复再写文档。

执行命令（登录验证、reconnect、mkdir、带 `--filter` 的上传、访问验证）统一见 `environments/seeed-reserver-recamera/network.md` 的"云端资产发布"一节。

## GitHub Completeness Gate

所有推送到 `RobotXTeam/sscma-example-sg200x` 的 demo 必须是完整项目代码：外部用户 clone GitHub 后，再从 Google Drive 拉取 README/Wiki 声明的模型和运行库，应能编译出 reCamera 可执行程序并正常运行。不允许把 Steven/seeed-reserver 私有绝对路径下的文件当隐式依赖；公开构建命令使用 `$REPO_ROOT`、`$SDK_ROOT`、`$TOOLCHAIN_BIN` 等可迁移变量。

**每个 demo 必须有 `run/` 开箱即跑包**：用户拉 `run/` + `model/` 就能不编译、直接在 reCamera 跑通。规格见 `environments/seeed-reserver-recamera/development-policy.md`。

**门禁**：推送 GitHub 之后、最终写定 Wiki 之前，必须做干净克隆验证闭环——GitHub clone -> Drive assets -> build -> deploy -> run -> evidence 全链路通过才算完整；否则回到 `seeed-reserver:/home/seeed0/sscma-example-sg200x` 修改重推，重复验证直到通过。验证原则见 `environments/seeed-reserver-recamera/development-policy.md`（Post-Push Verification Gate）和 `knowhubs/reCamera_KnowHub/project-layout.md`（Post-Push Clean Verification）。

## Visual Quality Baseline Gate

视觉类 demo 不能只验证“跑通、无报错、模型能加载、有输出”，必须验证“效果接近开源项目在 NVIDIA/Python 链路下的预期输出”：

- 每个视觉类 demo 必须先确认评测输入可信度：优先查明模型训练/验证/测试使用的数据集，并从官方或开源数据集中构造固定评测输入；只有找不到可靠数据集时，才使用自备视频或 reCamera 原始录制视频。
- 数据集统一缓存到 seeed-reserver 的 `~/reCamera_demo/datasets/`（即机械盘工作产物根目录 `/media/seeed/新加卷/reCamera/reCamera_demo/datasets/`），COCO、DOTA、VOC、ICDAR、ImageNet、KITTI 等常用数据集必须复用共享缓存，避免每个 demo 重复下载。
- 固定评测输入优先使用模型原始验证集/测试集中的视频或连续帧；找不到连续帧时，使用同一数据集中的代表性图片生成 30-120 帧测试视频，同时保留图片输入。
- 每个视觉类 demo 必须准备固定评测输入，包含本地图片或本地视频；实时摄像头 demo 也要先录制原始视频作为补充输入，但不能默认替代模型数据集评测。
- 必须在 seeed-reserver 主机上运行开源项目官方 Python 示例或官方推荐推理脚本，生成 teacher baseline：`baseline.jsonl`、可视化帧和 `baseline.mp4`。seeed-reserver 无 NVIDIA GPU，baseline 一律纯 CPU 推理：demo 以 CNN 为主，CPU 完全可以跑，无需 GPU 主机；CPU 推理较慢，超大输入适当控制帧数即可。
- 必须让 reCamera 使用同一批输入运行推理，生成 `recamera.jsonl`、可视化帧和 `recamera.mp4`。
- 必须对 `baseline.jsonl` 和 `recamera.jsonl` 做帧级对齐评分，生成 `eval/qa_report.md` 和失败样本。
- 默认质量门：检测类 `F1 >= 0.60` 且关键类别 `recall >= 0.60`；OCR/分类/分割等类型按 workflow 定义可解释指标，默认目标不低于 `0.60`。
- 如果 seeed-reserver CPU/Python baseline 在当前固定输入上本身效果很差，必须先更换或补充更可信的评测输入，不能直接用低可信 baseline 判定 reCamera 失败。
- 评分未通过时，不能录制最终证据、生成 Wiki 草稿、上传资产、推送 GitHub 或写成功记录；必须优先修复输入预处理、后处理、label map、阈值、NMS、坐标还原、模型转换精度等问题。



执行 demo 输出时必须先验证 rclone 登录状态（`rclone listremotes` + `rclone lsd agent:reCamera_Shared/Wiki --max-depth 1`）。登录/重连规则、上传命令和访问验证统一见 `environments/seeed-reserver-recamera/network.md` 的"云端资产发布"一节，全部在 Steven 本机执行。

**安全**：不要把 rclone token、配置文件内容或任何密钥写入 wiki、README、GitHub 仓库或报告。

## Workflows

工作流文件定义了具体的执行流程：

- `workflows/demo-output.md` - Demo 输出工作流

## Success Records

成功记录文件记录每次完整执行 Demo 输出工作流（0-19 全部步骤）并成功完成的 demo：

- `knowhubs/reCamera_KnowHub/success-records.md` - Demo 成功记录

**重要**：只有完成全部 0-19 步（从检查历史记录、质量基准评测到最终写定 Wiki）才能写入成功记录。用户中途停止、某一步失败、质量门未通过、或 GitHub 验证闭环未通过，都不算成功，不写入记录。

## Usage

### Demo Output

当用户提供项目想法时：
1. 读取 `workflows/demo-output.md`
2. 搜索 `knowhubs/reCamera_KnowHub/` 寻找相关能力
3. 查明模型训练/验证数据集并复用本地数据集缓存，构造可信固定评测输入
4. 在 seeed-reserver 主机运行官方 Python baseline（纯 CPU 推理；demo 以 CNN 为主，CPU 完全可跑，无需 GPU 主机）
5. 使用 `environments/seeed-reserver-recamera/` 部署项目到 reCamera，并用同一输入运行推理
6. 对齐 baseline/reCamera 结果，质量门通过后录制证据并生成 Wiki 文档

## 默认参数偏好

- **YOLO 检测置信度阈值不要固定为某个值**。所有 reCamera YOLO demo（onvif_yolo / rtmp_yolo / gb28181_yolo 等）应根据固定评测输入、baseline 对齐结果和最终视频效果调参，优先使用相对较低的置信度起步以保证目标能被检出，再用 NMS、类别过滤和多模态复核控制误检。文档和脚本不要写死置信度数值；必须写清楚本 demo 实测采用的 threshold、选择原因、效果截图/视频和质量报告结论。示例写法：`run_rtmp.sh <url> <threshold> 2`、`rtmp_yolo <model> <url> <threshold> 2`、`onvif_yolo <model> <threshold> ...`。

## Extension

要添加新设备支持：
1. 在 `knowhubs/` 下创建新的知识库目录（如 `knowhubs/newDevice_KnowHub/`）
2. 在 `environments/` 下创建新的环境配置目录（如 `environments/new-host-device/`）
3. 更新此 SKILL.md 的 Knowledge Hubs 和 Environments 部分
