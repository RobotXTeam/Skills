# Demo 成功记录

此文件记录每次完整执行 Demo 输出工作流（0-18 全部步骤）并成功完成的 demo。

## 成功标准

**只有完成以下 0-18 全部步骤，才算成功，才能写入此文件：**

0. 检查历史记录
1. 搜索知识库
2. 规划部署步骤
3. 准备固定评测输入
4. 在 seeed NVIDIA 主机运行官方 Python baseline
5. 部署到 reCamera
6. reCamera 使用同一输入运行推理
7. 自动对齐评分与质量门判断
8. 效果问题修复循环（如需要）
9. 多模态检验（baseline/recamera/评分报告）
10. 录制视频流和图片
11. 多模态检验（最终证据视频/图片）
12. 用户审核通过
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
