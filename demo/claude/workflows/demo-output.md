# Demo 输出工作流

## 目的

根据想法或开源项目，使用知识库部署到设备上，验证部署成功。

## 输入

- 项目想法或开源项目 URL
- 目标设备（reCamera）


## 工作流程（必须强制要求逐步完成所有步骤，不能跳步）

### 0. 检查历史经验

在开始执行前，读 `knowhubs/reCamera_KnowHub/demo-records.md` 查是否有可参考的历史经验：

- 是否有类似 demo 的成功记录
- 是否有相同模型或相同类型 demo 的经验
- 是否有可复用的编译问题解决方案
- 是否有特殊依赖或配置的记录

也可搜 `capability-map.md` 各能力条目的“已知结果 / 发现的 wiki 问题”和 `model-conversion.md` 的“实践记录 / 已验证结果”，并扫本机 `~/reCamera_demo/*/DEPLOY_REPORT.md` 看本机跑过的 demo 部署报告。如果有相关记录，参考其经验，避免重复踩坑。

### 1. 搜索知识库

在 `knowhubs/reCamera_KnowHub/` 中搜索相关能力：
- 搜索 `capability-map.md` 中的类似项目
- 搜索 `model-conversion.md` 中的模型转换方法
- 搜索 `cpp-runtime.md` 中的运行时配置

### 2. 规划部署步骤

基于搜索结果和互联网知识规划部署步骤：
- 获取代码/模型
- 环境准备
- 编译/构建
- 部署到设备
- 运行和验证


### 3. 识别模型数据集并准备共享缓存

所有视觉类 demo 必须先确认评测输入可信度，不能默认使用随手找到的视频直接做质量门。

必须查找并记录：
- 模型来源：GitHub、Hugging Face、论文、README、model card、训练脚本、配置文件、dataset yaml。
- 训练/验证/测试数据集名称、版本、类别表和 license。
- 官方示例推荐的输入尺寸、前处理、后处理和评测指标。

数据集缓存位置固定为：

```text
~/reCamera_demo/datasets/
├── coco/
├── dota/
├── voc/
├── icdar/
├── imagenet/
├── kitti/
└── <dataset_name>/
```

要求：
- 优先使用模型原始训练/验证/测试数据集；例如 COCO、DOTA、VOC、ICDAR、ADE20K、ImageNet、KITTI 等。
- 下载前先检查共享缓存，已有数据集必须复用，不重复下载。
- 数据集下载来源必须是官方站点、项目 README 指定链接、Hugging Face dataset、Kaggle 官方镜像或可信开源镜像；下载命令和版本写入 `eval/input/manifest.json`。
- 优先寻找视频、连续帧、同一序列或同一场景样本，组成 5-10 秒连续测试视频。
- 找不到连续帧时，从同一数据集抽取 30-120 张代表性图片生成测试视频，同时保留原始图片输入。
- 样本必须覆盖正样本、负样本和边界样本；检测类要覆盖目标存在、无目标、遮挡、小目标、多目标、低光照或困难角度等情况。
- 如果无法确认模型数据集，必须在报告中标记为“非原始数据集评测”，并说明为什么当前输入仍可用于该 demo。

如果 baseline 在当前输入上本身效果明显不好，必须先回到本步骤更换或补充更可信的评测输入，不能直接用低可信 baseline 判定 reCamera 效果失败。

### 4. 准备固定评测输入

所有视觉类 demo 在部署验收前，必须先准备固定评测输入，不能只用实时摄像头做效果判断。输入保存在：

```text
~/reCamera_demo/<demo_name>/eval/input/
├── images/                  # 固定图片样本，可为空但视觉 demo 推荐保留
├── video/input.mp4          # 固定视频样本，可由 reCamera 先录制原始视频得到
└── manifest.json            # 输入清单、样本说明、正负样本和边界样本标注
```

要求：
- 同一批输入必须同时用于 baseline 主机 Python baseline 和 reCamera 推理。
- 输入必须优先来自第 3 步确认的模型原始训练/验证/测试数据集或可信开源数据集。
- `manifest.json` 必须记录数据集来源、版本、缓存路径、样本选择理由、类别映射、是否连续帧、是否由图片合成视频。
- 样本必须包含正样本、负样本和边界样本；例如检测类 demo 不能只放目标存在的画面，也要放无目标、遮挡、小目标、多人/多物、低光照等场景。
- 如果 demo 的核心卖点是实时摄像头，也要先录制一段原始输入视频作为补充样本；但除非找不到可靠数据集，实时录制视频不能替代模型数据集评测。
- 所有视觉类 demo 的代码都必须保留三种输入：reCamera 实时相机、本地视频、本地图片。

### 5. 在 baseline 主机运行官方 Python baseline

在 baseline 主机（一台带 NVIDIA GPU 的 Linux 主机）上使用开源项目官方 Python 示例或官方推荐推理脚本跑同一批固定输入，作为 teacher reference。这个结果不是绝对真值，但它代表原始模型在标准 NVIDIA/Python 链路下的预期效果。

输出保存在：

```text
~/reCamera_demo/<demo_name>/eval/baseline/
├── frames/                  # baseline 输入帧拷贝或抽帧
├── visualized/              # baseline 可视化结果帧
├── baseline.jsonl           # 每帧结构化结果
└── baseline.mp4             # baseline 可视化视频
```

要求：
- 优先运行官方 demo 原始代码；不要为了省事重写一个行为不一致的简化推理脚本。
- 必须记录 Python 环境、依赖版本、模型文件、运行命令和关键参数。
- `baseline.jsonl` 必须使用稳定结构保存每帧结果，便于与 reCamera 输出做自动对齐。
- 必须人工或多模态抽查 baseline 可视化视频和关键帧；如果 baseline 在可信数据集样本上仍明显不准，先检查官方脚本、模型权重、label map 和阈值，不能直接进入 reCamera 对齐。
- 检测类建议结构：

```json
{"frame": 12, "objects": [{"cls": "person", "conf": 0.91, "box": [120, 80, 260, 340]}]}
```

### 6. 部署到 reCamera

执行部署步骤：
- 连接到 reCamera 设备（默认 IP `192.168.42.1`）。
- 按照规划的步骤操作。
- 记录每个步骤的结果。
- 所有 demo 可执行程序在 reCamera 上运行时都要用 `sudo` 执行。
- 部署结果必须能处理第 4 步准备的本地图片和本地视频输入，不能只支持实时摄像头。

### 7. reCamera 使用同一输入运行推理

在 reCamera 上使用第 4 步同一批固定输入运行推理，并导出与 baseline 可对齐的结果。

输出保存在：

```text
~/reCamera_demo/<demo_name>/eval/recamera/
├── frames/                  # reCamera 输入帧拷贝或抽帧
├── visualized/              # reCamera 可视化结果帧
├── recamera.jsonl           # 每帧结构化结果
└── recamera.mp4             # reCamera 可视化视频
```

要求：
- reCamera 的图片/视频输入必须与 baseline 使用完全相同的文件。
- reCamera 输出 JSONL 字段要尽量与 `baseline.jsonl` 对齐；检测框坐标必须还原到原图坐标系。
- 必须保存日志、启动命令、模型路径、阈值、NMS、输入尺寸、label map 等关键参数。

### 8. 自动对齐评分与质量门判断

对 `baseline.jsonl` 和 `recamera.jsonl` 做帧级对齐评分，生成：

```text
~/reCamera_demo/<demo_name>/eval/qa_report.md
~/reCamera_demo/<demo_name>/eval/qa_report.json
~/reCamera_demo/<demo_name>/eval/failures/
```

默认质量门：
- 检测类：class match + IoU >= 0.5，计算 precision / recall / F1；默认要求 `F1 >= 0.60` 且关键类别 `recall >= 0.60`。
- OCR 类：文本相似度、字符准确率和关键字段命中率；默认要求核心文本相似度 `>= 0.60`。
- 分类类：top-1 或 top-5 一致率；默认要求 top-1 一致率 `>= 0.60`。
- 分割类：mIoU 或 mask overlap；默认要求核心区域指标 `>= 0.60`。
- 关键点/姿态类：关键点距离误差或 PCK；阈值必须在报告中说明。
- 深度/光流/生成类等难以直接结构化的 demo：必须定义可解释指标，并结合 baseline/reCamera 视频做多模态复核；不能只写“看起来正常”。

要求：
- `qa_report.md` 必须写清楚输入样本数、通过帧数、失败帧、主要失败原因和最终是否通过质量门。
- 评分未通过时，不能进入录制、用户审核或 Wiki 草稿，需先判断是否是评测输入或 baseline 不可信；如果输入可信，再检查代码、模型转换和后处理，直到评分通过为止。
- 如果某类 demo 无法自动评分，必须在报告中说明原因，并用固定输入的 baseline 视频、reCamera 视频和多模态分析替代；替代方案也必须给出明确通过/失败结论。

### 9. 效果问题修复循环

如果第 8 步质量门未通过，必须先修复效果问题，再重新执行第 3-8 步中受影响的步骤，直到通过或明确判定该 demo 不适合继续。

优先排查：
- 评测输入是否来自模型原始数据集或可信开源数据集，baseline 是否本身可靠。
- 输入尺寸、resize、letterbox 和坐标还原。
- RGB/BGR、归一化、均值方差、CHW/HWC、量化输入范围。
- label map 顺序、类别过滤、阈值、NMS、top-k。
- 模型转换精度、量化校准数据、后处理公式。
- reCamera C++ 后处理与官方 Python baseline 是否一致。

如果多次修复后仍无法达到默认质量门，必须停止发布流程，在 `~/reCamera_demo/<demo_name>/DEPLOY_REPORT.md` 记录失败原因和可复现证据，并在 `knowhubs/reCamera_KnowHub/demo-records.md` 追加一条失败记录（状态标 ❌ 失败），不写成功记录。

### 10. 多模态检验

使用多模态功能读取并对比以下材料：
- `eval/baseline/baseline.mp4`
- `eval/recamera/recamera.mp4`
- `eval/qa_report.md`
- `eval/failures/` 中的失败帧

判断输出是否与本 demo 的目标一致。这里验证的是“跑好”，不是仅仅“跑通”。如果输出内容和本 demo 要的结果不同，即使程序没有报错，也必须回到第 9 步修复。

### 11. 录制视频流和图片

录制设备的运行效果：
- 使用主机拉取设备的视频流。
- 录制视频窗口。
- 传回本机。
- 录制视频流和图片必须要有足够的证据，比如实时 OSD 检测框或者 OSD 数据在画面上，或者导出来在 baseline 主机上叠加。用户看到视频后应能直接理解这个 demo 的视觉效果。
- 最终证据视频应优先使用第 8 步质量门已通过的模型、阈值、NMS 和后处理参数。

### 12. 用户审核

在本机打开视频，由用户审核：
- 内容是否正确
- 效果是否通过
- 是否需要调整


### 13. 记录本次 demo 结论

**只有完成上述 0-12 全部步骤，才能执行此步骤。**

把本次结论写两处：

1. 追加到 `knowhubs/reCamera_KnowHub/demo-records.md`（跨 demo 的历史经验汇总，随 skill 分发；step 9 失败时也追加到这里）——下次同类 demo 在 step 0 读它能参考本次经验。
2. 写一份到 `~/reCamera_demo/<demo_name>/DEPLOY_REPORT.md`（该 demo 自己的部署报告，本机留存）。

记录格式：

```markdown
### <demo_name> (<date>)
- 状态：✅ 成功
- 模型文件：<model_files>
- 特殊依赖：<dependencies or “无”>
- 编译问题：<problem and solution or “无”>
- 验证结果：<verification_summary>
- 关键经验：<lessons_learned or “无”>
```

## 输出

- 设备上部署成功的项目
- 质量基准报告 - `eval/qa_report.md`
- 历史经验记录 - `knowhubs/reCamera_KnowHub/demo-records.md`
- 部署报告 - `~/reCamera_demo/<demo_name>/DEPLOY_REPORT.md`

## 引用

- 知识库：`knowhubs/reCamera_KnowHub/`
