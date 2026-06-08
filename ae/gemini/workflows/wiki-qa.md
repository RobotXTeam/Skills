# Wiki QA 工作流

## 目的

评估 Seeed reCamera wiki 页面的可复现性。

目标不仅仅是"让 demo 运行"。目标是评估 wiki：

- 如果 wiki 按原样运行，wiki 是优秀的。
- 如果按原样失败但在合理修复后工作，wiki 可用但需要改进。
- 如果在严重调试后仍无法复现，wiki 是失败/糟糕级别的可复现性。

总是分离：

- wiki 说了什么；
- 直接遵循时发生了什么；
- 需要什么修复；
- 最终预期输出是否复现；
- 证据路径；
- wiki 写作/可复现性评分。

不要用自定义渲染器代码替换 wiki/仓库视觉效果。对于视觉 demo，使用官方 wiki/repo/Drive 接收器脚本并录制它们的实际输出。

## 标准 QA 工作流

1. 运行环境预检脚本。
2. 读取用户请求的 wiki/页面文本（如果提供或在线）。对于已蒸馏的页面，使用能力清单。
3. 首先尝试 wiki 的步骤 as written。记录 exact 命令和 exact 失败。
4. 如果涉及 C++ 摄像头访问：
   - 停止摄像头占用服务；
   - 使用当前 seeed USB IP；
   - 使用 `sudo`；
   - 设置 `LD_LIBRARY_PATH=/mnt/system/lib:/mnt/system/usr/lib:/mnt/system/usr/lib/3rd`。
5. 如果涉及 Python/OpenCV UDP 接收器：
   - 使用来自 wiki/repo/Drive 的官方接收器脚本；
   - 在 `seeed` 上运行；
   - SSH/headless 时使用 Xvfb；
   - 通过 `ffmpeg x11grab` 录制实际窗口。
6. 仅在记录直接 wiki 失败后应用修复。
7. 收集证据：发送器日志、接收器日志、视频/截图/帧、HTTP 输出、产物和 exact 命令行。
8. 摄像头 demo 后恢复服务或重启 reCamera。
9. 输出报告和评分。

## 引用

- 知识库：`knowhubs/reCamera_KnowHub/capability-map.md`
- 环境配置：`environments/seeed-recamera/`
- 报告模板：`templates/wiki-report.md`
