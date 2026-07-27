---
name: demo
description: "Deploy projects to reCamera, verify deployment, record results, and generate wiki documentation. Trigger when the user mentions reCamera demo deployment, asks to deploy projects to reCamera, or generate wiki documentation for reCamera demos."
---

# Demo

## Essential Warning
必须明确一点，这个skill是要求把demo部署到reCamera上

## Purpose
本 skill 用于根据知识库部署项目到 reCamera 设备，验证部署成功，录制运行效果。

## 执行入口

当此 skill 被调用时，必须：

1. **读取 ARGUMENTS**：位于 SKILL.md 末尾，包含用户的输入
2. **确认工作流**：此 skill 仅支持 Demo Output 工作流
3. **执行工作流**：严格按照 `workflows/demo-output.md` 步骤执行

## Knowledge Hubs

知识库包含设备特定的技术知识：

- `knowhubs/reCamera_KnowHub/` - reCamera 设备知识库
  - `overview.md` - reCamera 概览
  - `device-ops.md` - 设备操作
  - `cpp-runtime.md` - C++ 运行时与编译基线
  - `capability-map.md` - 能力清单
  - `demo-records.md` - demo 历史经验记录
  - `project-layout.md` - 项目目录规范和完整性契约
  - `model-conversion.md` - 模型转换方法论
  - `receiver-recording.md` - 接收端录制方法

## Workflows

工作流文件定义了具体的执行流程：

- `workflows/demo-output.md` - Demo 输出工作流（0-13 步）

## Visual Quality Baseline Gate

视觉类 demo 不能只验证"跑通、无报错、模型能加载、有输出"，必须验证"效果接近开源项目在 NVIDIA/Python 链路下的预期输出"：

- 每个视觉类 demo 必须先确认评测输入可信度：优先查明模型训练/验证/测试使用的数据集，并从官方或开源数据集中构造固定评测输入；只有找不到可靠数据集时，才使用自备视频或 reCamera 原始录制视频。
- 数据集统一缓存到 `~/reCamera_demo/datasets/`，COCO、DOTA、VOC、ICDAR、ImageNet、KITTI 等常用数据集必须复用本地缓存，避免每个 demo 重复下载。
- 固定评测输入优先使用模型原始验证集/测试集中的视频或连续帧；找不到连续帧时，使用同一数据集中的代表性图片生成 30-120 帧测试视频，同时保留图片输入。
- 每个视觉类 demo 必须准备固定评测输入，包含本地图片或本地视频；实时摄像头 demo 也要先录制原始视频作为补充输入，但不能默认替代模型数据集评测。
- 必须在带有 NVIDIA GPU 的 Linux 主机上运行开源项目官方 Python 示例或官方推荐推理脚本，生成 teacher baseline：`baseline.jsonl`、可视化帧和 `baseline.mp4`。
- 必须让 reCamera 使用同一批输入运行推理，生成 `recamera.jsonl`、可视化帧和 `recamera.mp4`。
- 必须对 `baseline.jsonl` 和 `recamera.jsonl` 做帧级对齐评分，生成 `eval/qa_report.md` 和失败样本。
- 默认质量门：检测类 `F1 >= 0.60` 且关键类别 `recall >= 0.60`；OCR/分类/分割等类型按 workflow 定义可解释指标，默认目标不低于 `0.60`。
- 如果 baseline 在当前固定输入上本身效果很差，必须先更换或补充更可信的评测输入，不能直接用低可信 baseline 判定 reCamera 失败。
- 评分未通过时，不能录制最终证据、生成 Wiki 草稿；必须优先修复输入预处理、后处理、label map、阈值、NMS、坐标还原、模型转换精度等问题。

## Usage

### Demo Output

当用户提供项目想法时：
1. 读取 `workflows/demo-output.md`
2. 搜索 `knowhubs/reCamera_KnowHub/` 寻找相关能力
3. 查明模型训练/验证数据集并复用本地数据集缓存，构造可信固定评测输入
4. 在带 NVIDIA GPU 的主机运行官方 Python baseline
5. 部署项目到 reCamera，并用同一输入运行推理
6. 对齐 baseline/reCamera 结果，通过质量门


## Extension

要添加新设备支持：
1. 在 `knowhubs/` 下创建新的知识库目录（如 `knowhubs/newDevice_KnowHub/`）
2. 更新此 SKILL.md 的 Knowledge Hubs 部分
