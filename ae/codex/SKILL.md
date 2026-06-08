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
