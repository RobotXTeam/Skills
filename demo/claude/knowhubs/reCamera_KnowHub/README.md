# reCamera Knowledge Hub

这是 reCamera 设备的知识库，包含与 reCamera 相关的技术知识、最佳实践和已知问题。

## 目录结构

- `overview.md` - reCamera 概览（Wiki 范围、设备访问、OS/服务、模型、开发根目录、证据期望）
- `device-ops.md` - 设备操作（SSH/scp、UDP 接收端 IP、隧道截图）
- `cpp-runtime.md` - C++ 运行时与编译基线（交叉编译、部署、停服务、LD_LIBRARY_PATH、重启）
- `capability-map.md` - wiki 能力蒸馏清单（每个能力做什么、怎么验证、命令模板）
- `demo-records.md` - demo 历史经验记录（随 skill 分发的跑过 demo 结论汇总）
- `project-layout.md` - demo 项目目录规范和完整性契约
- `model-conversion.md` - 自定义模型转换和 NPU demo 方法论
- `receiver-recording.md` - 接收端录制方法

## 使用方法

在本 skill 的工作流中通过相对路径引用此知识库：

```
knowhubs/reCamera_KnowHub/capability-map.md
```

## 扩展

需要添加新知识时，按类别创建新的 Markdown 文件，并更新此 README。
