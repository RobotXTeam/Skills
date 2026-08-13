# Demo 成功记录

> 2026-08-13 起部署主机迁移至 seeed0（ae-seeed0 skill），此前记录产生于旧部署主机（seeed）。迁移后的新记录写入旧主机名一律指 seeed0。

此文件记录每次完整执行 Demo 输出工作流（0-18 全部步骤）并成功完成的 demo。

## 成功标准

**只有完成以下 0-18 全部步骤，才算成功，才能写入此文件：**

0. 检查历史记录
1. 搜索知识库
2. 规划部署步骤
3. 识别模型数据集并准备共享缓存
4. 准备固定评测输入
5. 在 seeed0 主机运行官方 Python baseline（seeed0 无 NVIDIA GPU，仅 CPU 推理，大模型/大输入很慢；评测输入应精简，必要时与用户确认改用其它 GPU 主机跑 baseline）
6. 部署到 reCamera
7. reCamera 使用同一输入运行推理
8. 自动对齐评分与质量门判断
9. 效果问题修复循环（如需要）
10. 多模态检验
11. 录制视频流和图片（含 11.0 本机实时 OSD 显示）
12. 用户审核
13. 生成 Wiki 草稿文档
14. 上传运行包、模型和证据到 Google Drive
15. 推送到 GitHub
16. GitHub 干净克隆验证闭环通过
17. 最终写定 Wiki
18. 更新成功记录

**以下情况不算成功，不写入此文件：**
- 用户中途停止（未完成全部 0-18 步）
- 某一步失败后未继续
- 质量门未通过
- 用户未审核通过
- GitHub 验证闭环未通过

## 记录格式

每个成功 demo 记录以下信息：

```markdown
### <demo_name> (<date>)
- 状态：✅ 成功
- GitHub commit：<short_hash>
- Google Drive 路径：`agent:reCamera_Shared/Wiki/<demo_name>/`
- 模型文件：<model_files>
- 特殊依赖：<dependencies or "无">
- 编译问题：<problem and solution or "无">
- 验证结果：<verification_summary>
- 关键经验：<lessons_learned or "无">
```

---

## 成功记录

### rtmp_yolo (2026-06-29)
- 状态：✅ 成功
- GitHub commit：5bc7f07
- Google Drive 路径：`agent:reCamera_Shared/Wiki/rtmp_yolo/`
- 模型文件：yolo11n_detection_cv181x_int8.cvimodel
- 特殊依赖：无
- 编译问题：无
- 验证结果：通过
- 关键经验：阈值 0.60, 使用 ffmpeg copy 直推流无重编码, rtmp验证通过

### onvif_yolo (2026-06-29)
- 状态：✅ 成功
- GitHub commit：5bc7f07
- Google Drive 路径：`agent:reCamera_Shared/Wiki/onvif_yolo/`
- 模型文件：yolo11n_detection_cv181x_int8.cvimodel
- 特殊依赖：无
- 编译问题：无
- 验证结果：通过
- 关键经验：阈值 0.60, RGN/OSD硬件叠加画框验证通过

### gb28181_yolo (2026-06-29)
- 状态：✅ 成功
- GitHub commit：5bc7f07
- Google Drive 路径：`agent:reCamera_Shared/Wiki/gb28181_yolo/`
- 模型文件：yolo11n_detection_cv181x_int8.cvimodel
- 特殊依赖：eXosip2, osip2 (SIP库)
- 编译问题：无
- 验证结果：通过
- 关键经验：阈值 0.60, 国标 GB28181 推流验证通过

### human_falling_detection (2026-08-06)
- 状态：✅ 成功
- GitHub commit：39d9f62
- Google Drive 路径：`agent:reCamera_Shared/Wiki/human_falling_detection/`
- 模型文件：yolo11n_pose_cv181x_bf16.cvimodel, tsstg_30x14_cv181x_bf16.cvimodel
- 特殊依赖：PC 预览需 Python3 + Tkinter + PIL（中文 OSD 字体 Noto Sans CJK SC）
- 编译问题：INT8 姿态关键点抖动被 TSSTG 放大 → 换 BF16 姿态；seeed 代理整仓克隆 EOF → 稀疏部分克隆（--filter=blob:none + sparse-checkout）完成验证
- 验证结果：质量门通过（存在 F1 0.990、IoU 0.926、动作 top-1 一致 1.00、Fall Down recall 1.0）；GitHub 干净克隆→构建 RISC-V musl ELF→部署→运行→证据闭环通过；用户跌倒视频端到端绿→红（首判 frame 192）
- 关键经验：判定跟开源 argmax 无阈值（--fall-bias 0.15 默认更灵敏、~0.05 噪声底门控）；跌倒整屏变红；OSD PC 端叠加保原生 720p 画质且全中文；PC 跨网段时用 seeed USB + SSH 隧道 UDP 桥 fallback
