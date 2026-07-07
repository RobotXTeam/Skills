# reCamera Skill 结构说明

## 最后更新

2026-06-26

## 功能

AE Agent 专注于一个功能：**Demo Output** - 根据知识库部署项目到 reCamera 设备，验证部署成功，录制运行效果，并生成 Wiki 文档。

## 目录结构

```
/home/steven/.claude/skills/ae/
├── SKILL.md                          # AE Agent 主入口
├── workflows/
│   └── demo-output.md                # Demo 输出工作流
├── knowhubs/
│   └── reCamera_KnowHub/
│       ├── README.md                 # 知识库说明
│       ├── capability-map.md         # 能力清单
│       ├── cpp-runtime.md            # C++ 运行时基线
│       ├── model-conversion.md       # 模型转换方法论
│       ├── receiver-recording.md     # 接收端录制
│       └── project-layout.md         # 项目结构规范
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
└── templates/
    └── demo-wiki.md                  # Demo Wiki 模板
```

## 开发环境

- **开发主机**：seeed（SSH 连接）
- **仓库位置**：`seeed:/home/seeed/sscma-example-sg200x`
- **工作目录**：`seeed:~/reCamera_demo/<demo_name>/`
- **目标设备**：reCamera（通过 seeed 连接 `192.168.42.1`）

## 工作流程

1. 搜索知识库（capability-map.md）
2. 规划部署步骤
3. 在 seeed 上编译和部署
4. 在 reCamera 上运行和验证
5. 录制视频和图片
6. 用户审核
7. 上传云端资产（Google Drive）
8. 推送到 GitHub
9. 干净克隆验证
10. 生成最终 Wiki

## 关键规范

- **编译位置**：seeed 主机
- **GitHub 仓库**：`RobotXTeam/sscma-example-sg200x`
- **云端存储**：`agent:reCamera_Shared/Wiki/<demo_name>/`
- **公开链接**：`https://drive.google.com/drive/folders/1GOQUMCel7fapbJCWzEEynDIvIt-6Wf5p?usp=drive_link`
- **YOLO 阈值**：不固定默认值，按固定评测输入、baseline 对齐结果和最终视频效果调参，优先用相对较低置信度保证检出效果
