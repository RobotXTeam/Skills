# reCamera Skill 重构总结

## 重构完成时间

2026-06-08

## 重构目标

将原有的 recamera skill（单体 SKILL.md 文件，486 行）重构为一个完整的 AE Agent，支持：
1. Wiki 评价（原有功能）
2. 技术支持：处理售后邮件/问题询盘
3. Demo 输出：根据知识库部署开源项目并生成 Wiki

同时解耦：
- 知识库 → `reCamera_KnowHub`
- 部署环境 → `Deployment_environment`

## 新目录结构

```
/home/steven/.claude/skills/ae/
├── SKILL.md                          # AE Agent 主入口（精简）
├── workflows/
│   ├── wiki-qa.md                    # Wiki 评价工作流
│   ├── tech-support.md               # 技术支持工作流
│   └── demo-output.md                # Demo 输出工作流
├── knowhubs/
│   └── reCamera_KnowHub/
│       ├── README.md                 # 知识库说明
│       ├── capability-map.md         # 能力清单（原 Distilled Wiki Capability Map）
│       ├── cpp-runtime.md            # C++ 运行时基线（原第6节）
│       ├── model-conversion.md       # 模型转换方法论（原第7节）
│       ├── receiver-recording.md     # 接收端录制（原第8节）
│       ├── device-ops.md             # 设备操作知识
│       └── known-reports.md          # 已知报告
├── environments/
│   └── seeed-recamera/
│       ├── README.md                 # 环境说明
│       ├── network.md                # 网络配置
│       ├── credentials.md            # 凭据信息
│       ├── toolchain.md              # 工具链配置
│       └── scripts/                  # 辅助脚本
│           ├── preflight.sh
│           ├── recamera_ssh.sh
│           ├── recamera_scp_to.sh
│           └── seeed_usb_ip.sh
├── templates/
│   ├── wiki-report.md                # Wiki QA 报告模板
│   ├── tech-support-reply.md         # 技术支持回复模板
│   └── demo-wiki.md                  # Demo Wiki 模板
├── references/                       # 参考文档
└── agents/                           # Agent 配置
```

## 文件拆分详情

### 1. 知识库（knowhubs/reCamera_KnowHub/）

- **capability-map.md**：从原 SKILL.md 第10节（Distilled Wiki Capability Map）提取
- **cpp-runtime.md**：从原 SKILL.md 第6节（C++ Camera Runtime Baseline）提取
- **model-conversion.md**：从原 SKILL.md 第7节（Custom Model Conversion And NPU Demo Methodology）提取
- **receiver-recording.md**：从原 SKILL.md 第8节（Official Receiver Recording）提取
- **device-ops.md**：从原 references/overview.md 和 references/device-ops.md 整合
- **known-reports.md**：从原 SKILL.md 第11节（Known Reports）提取

### 2. 环境配置（environments/seeed-recamera/）

- **network.md**：从原 SKILL.md 第3节（Fixed Environment）提取网络配置
- **credentials.md**：从原 SKILL.md 第3节提取凭据信息
- **toolchain.md**：从原 SKILL.md 第3节提取工具链配置
- **scripts/**：从原 scripts/ 目录复制

### 3. 工作流（workflows/）

- **wiki-qa.md**：从原 SKILL.md 第5节（Standard QA Workflow）提取
- **tech-support.md**：新建，定义技术支持工作流程
- **demo-output.md**：新建，定义 Demo 输出工作流程

### 4. 模板（templates/）

- **wiki-report.md**：从原 SKILL.md 第9节（Scoring Rubric）和 Report Template 提取
- **tech-support-reply.md**：新建，技术支持回复模板
- **demo-wiki.md**：新建，Demo Wiki 模板

## 路径更新

所有文件中的路径引用已更新：
- 原 `/home/steven/.codex/skills/recamera/scripts/` → 新 `/home/steven/.claude/skills/ae/environments/seeed-recamera/scripts/`
- 原 SKILL.md 中的相对路径 → 新的相对路径

## 扩展性设计

### 添加新设备支持

1. 在 `knowhubs/` 下创建新的知识库目录（如 `knowhubs/newDevice_KnowHub/`）
2. 在 `environments/` 下创建新的环境配置目录（如 `environments/new-host-device/`）
3. 更新 SKILL.md 的 Knowledge Hubs 和 Environments 部分

### 添加新工作流

1. 在 `workflows/` 下创建新的工作流文件
2. 在 SKILL.md 的 Workflow Selection 部分添加触发条件

## 验证方法

1. 测试 Wiki QA 工作流：运行 `/ae` 触发 wiki 评价
2. 测试技术支持工作流：输入一个问题描述，验证输出
3. 测试 Demo 输出工作流：给一个简单的项目想法，验证部署和 Wiki 生成
4. 验证知识库引用：确认所有工作流能正确引用知识库
5. 验证环境解耦：确认环境配置可以独立替换

## 注意事项

- 原 `/home/steven/.codex/skills/recamera/` 目录未删除，保留作为备份
- 所有脚本文件已复制到新位置，可独立运行
- 知识库文件已翻译为中文，便于理解
- 工作流文件已添加详细的引用路径
