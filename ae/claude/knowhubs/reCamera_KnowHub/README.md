# reCamera Knowledge Hub

这是 reCamera 设备的知识库，包含所有与 reCamera 相关的技术知识、最佳实践和已知问题。

## 知识来源

本知识库蒸馏自 Seeed 官方 wiki 仓库 `Seeed-Studio/wiki-documents/sites/en/docs/Edge/reCamera`（分支 `docusaurus-version`）。原始 wiki markdown 不纳入本知识库；遇到新增或变更的 wiki 页面，直接读该页面，再套用本库蒸馏出的工作流。Node-RED demo 目前还不是可运行配方；C++ 与系统知识已完成蒸馏。

## 目录结构

- `capability-map.md` - 能力清单，从 reCamera wiki 蒸馏的结构化知识
- `cpp-runtime.md` - C++ 摄像头运行时基线
- `model-conversion.md` - 自定义模型转换和 NPU demo 方法论
- `receiver-recording.md` - 官方接收端录制方法
- `device-ops.md` - 设备操作知识（访问、SSH/SCP、服务、隧道截图、模型、证据）
- `live-osd-display.md` - 实时 OSD 显示三件套（推流/弹窗/中继）
- `project-layout.md` - reCamera C++ demo 项目放置和目录规范

## 使用方法

在 AE Agent 的工作流中，通过相对路径引用此知识库：

```
knowhubs/reCamera_KnowHub/capability-map.md
```

## 扩展

当需要添加新的知识时，按类别创建新的 Markdown 文件，并更新此 README。
