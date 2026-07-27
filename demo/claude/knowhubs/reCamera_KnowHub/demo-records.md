# Demo 历史经验记录

本文件是跨 demo 的历史经验汇总，**随 skill 分发**。每次跑完一个 demo（成功或失败）都把结论追加到这里；下次开新 demo 时在 workflow step 0 读本文件参考，避免重复踩坑。

详细的能力和验证方法见 `capability-map.md`；本文件只记"跑过的 demo 结论"。

## 记录格式

每跑完一个 demo，按以下格式追加一条到文末"已有记录"段：

```markdown
### <demo_name> (<date>)
- 状态：✅ 成功 / ❌ 失败
- 模型文件：<model_files>
- 特殊依赖：<dependencies or “无”>
- 编译问题：<problem and solution or “无”>
- 验证结果：<verification_summary>
- 关键经验：<lessons_learned or “无”>
```

## 已有记录

### UDP_Face_Analysis (2026-06-05)
- 状态：✅ 成功（修复后通过，评分 6/10）
- 模型文件：`yolo-face_mixfp16.cvimodel`、`age_gender_race_bf16.cvimodel`、`emotion_bf16.cvimodel`
- 特殊依赖：无
- 编译问题：无
- 验证结果：UDP 视频帧成功接收，人脸 + 年龄/性别/种族/情绪输出正常
- 关键经验：wiki 缺 `sudo` 和 `LD_LIBRARY_PATH` 说明；`yolo-face_mixfp16` 模型需用 `single` 非 `multi`；远距离/侧面面部场景用 `single 0.5 1` 更稳定

### yolo_benchmark (2026-06-05)
- 状态：✅ 成功（修复后通过，评分 7/10）
- 模型文件：`yolo11n_detection_cv181x_int8.cvimodel`
- 特殊依赖：外部资产 `recamera_benchmark`、`yolo_udp.py`
- 编译问题：无
- 验证结果：检测耗时约 49-58 ms，符合 wiki 50 ms / 20 FPS 的声明
- 关键经验：`recamera_benchmark` 硬编码 UDP 端口 `5001`，接收端必须监听 5001；Linux/headless 接收器不能用 `cv2.imshow`，需 save-frame 接收器；接收端 IP 在 reCamera 重启/USB 重连后必须重新检查
