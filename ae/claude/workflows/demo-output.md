# Demo 输出工作流

## 目的

根据想法或开源项目，使用知识库部署到设备上，验证部署成功，录制运行效果，生成 Wiki 文档(要用户确认录制的视频效果ok之后再生成wiki文档)。
必须完全执行 ## 工作流程（必须强制要求逐步完成所有步骤，不能跳步）

## 输入

- 项目想法或开源项目 URL
- 目标设备（reCamera）

## 目录结构

### 本机环境

```
~/work/reCamera_demo/                    ← 工作根目录
├── <demo_name>/                         ← 如 ppocr_v4、depth_anything
│   ├── DEPLOY_REPORT.md                 ← 部署报告
│   ├── <demo_name>_Demo_Wiki.md         ← Wiki 文档
│   ├── models/                          ← 模型文件（不提交Github，上传 Google Drive）
│   ├── calib/                           ← 校准数据（不提交Github，上传 Google Drive）
│   ├── datasets/                        ← 可选；本 demo 从共享数据集缓存抽取出的样本说明或软链接
│   ├── eval/                            ← 质量基准评测产物
│   │   ├── input/                       ← 固定评测输入（图片/视频/manifest）
│   │   ├── baseline/                    ← seeed NVIDIA 主机 Python baseline 输出
│   │   ├── recamera/                    ← reCamera 同输入推理输出
│   │   └── qa_report.md                 ← 帧级对齐评分报告
│   └── evidence/
│       ├── image/                       ← 证据图片（关键帧提交Github，完整图片上传 Google Drive）
│       │   ├── frame_0000.png
│       │   └── ...
│       └── video/                       ← 证据视频（不提交Github，上传 Google Drive）
│           └── demo.mp4
│
├── export_*.py                          ← 导出脚本
└── *.mlir, *.npz                        ← 中间产物（不提交Github）

~/work/reCamera_demo/datasets/           ← 共享数据集缓存，所有 demo 复用
├── coco/
├── dota/
├── voc/
├── icdar/
├── imagenet/
└── ...

/home/seeed/sscma-example-sg200x/solutions/sesg-project/<demo_name>/  ← 仓库目录
├── CMakeLists.txt                       ← ✅ 提交
├── README.md                            ← ✅ 提交
├── main/*.cpp, *.h                      ← ✅ 提交
├── *.py                                 ← ✅ 提交
├── wiki/                                ← ✅ 提交
│   ├── <demo_name>_Demo_Wiki.md
│   ├── DEPLOY_REPORT.md
│   └── qa_report.md                     ← ✅ 提交，baseline/reCamera 对齐评分摘要
├── evidence/                            ← ✅ 提交少量关键截图
│   └── frame_*.png                      ← 只提交关键帧（5-10 张）
└── model/                               ← ❌ .gitignore 忽略；模型发布到 Google Drive
```

### 云端资产发布目录

所有 demo 的运行包、模型、完整证据图片、证据视频统一上传到 Steven 已登录的 rclone Google Drive remote：

```text
agent:reCamera_Shared/Wiki/<demo_name>/run/
agent:reCamera_Shared/Wiki/<demo_name>/model/
agent:reCamera_Shared/Wiki/<demo_name>/evidence/image/
agent:reCamera_Shared/Wiki/<demo_name>/evidence/video/
```

`run/` 是**开箱即跑包**：放交叉编译好的 reCamera 可执行程序 + `run/README.md` + 必要运行时依赖（一般一个可执行文件即可；GB28181 类这种的需带 SIP `.so` 库和一键脚本）。用户拉 `run/` + `model/` 就能不出 Google Drive、不编译、直接在 reCamera 跑通。

公开 Wiki 根目录链接固定为：

```text
https://drive.google.com/drive/folders/1GOQUMCel7fapbJCWzEEynDIvIt-6Wf5p?usp=drive_link
```

公开文档中可写成：

```text
/reCamera_Shared/Wiki/<demo_name>/run/
/reCamera_Shared/Wiki/<demo_name>/model/
/reCamera_Shared/Wiki/<demo_name>/evidence/image/
/reCamera_Shared/Wiki/<demo_name>/evidence/video/
```

README 和 Wiki 默认贴固定 Wiki 根目录链接，并写清楚以上子路径，让用户按 demo 名称进入对应文件夹。只有需要直达子目录时才额外尝试 `rclone link`；如果遇到 Google Drive API rate limit，不要反复重试直达链接。

### GitHub 仓库的目的与规范

明确此 GitHub 仓库的目的是**上传完整的项目代码并提供给外部用户，以便用户能够自行复刻 demo 与 wiki**。
因此，代码必须绝对完整，确保用户拿到手之后可以直接在相应的编译环境中编译出能够在 reCamera 上运行的可执行程序。在提交的代码、脚本以及说明文档中，**绝对不要包含本机部署的绝对路径**（例如 `/home/steven/...` 或 `/home/seeed/...`），**必须使用相对路径**或通用环境变量来代替。

GitHub 代码完整性要求：

- 仓库必须包含完整源码、构建入口（如 `CMakeLists.txt` / `build.sh`）、部署/启动脚本、README、Wiki 草稿和少量关键证据截图。
- 构建入口必须能按 README/Wiki 中公开写法直接运行；如果 README 写 `./build.sh`，脚本必须有可执行权限；如果使用 CMake，必须显式写全所需 C++ 标准、仓库根路径和依赖变量。
- 大模型、完整证据图片/视频、大型运行时库不要提交 GitHub，但 README/Wiki 必须写清楚它们在 Google Drive 的固定路径和文件名。用户 clone GitHub 后，从 Google Drive 拉取这些文件，就应能编译、部署并运行。
- 不能依赖未提交的本机文件、未记录的手工复制步骤或 Steven/seeed 私有绝对路径。

### seeed 设备环境（编写、编译代码和推仓库的地方）

```
~/reCamera_demo/                         ← 工作根目录
├── <demo_name>/                         ← 如 ppocr_v4、depth_anything
│   ├── DEPLOY_REPORT.md
│   ├── <demo_name>_Demo_Wiki.md
│   ├── models/
│   ├── eval/
│   └── evidence/
│       ├── image/
│       └── video/

/home/seeed/sscma-example-sg200x/solutions/sesg-project/<demo_name>/  ← 仓库目录
```

## 工作流程（必须强制要求逐步完成所有步骤，不能跳步）

### 0. 检查历史记录

在开始执行前，读取 `success-records.md`，检查是否有可参考的历史记录：

- 是否有类似 demo 的成功记录
- 是否有相同模型或相同类型 demo 的经验
- 是否有可复用的编译问题解决方案
- 是否有特殊依赖或配置的记录

如果有相关记录，参考其经验，避免重复踩坑。

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
/home/steven/work/reCamera_demo/datasets/
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

如果 seeed NVIDIA/Python baseline 在当前输入上本身效果明显不好，必须先回到本步骤更换或补充更可信的评测输入，不能直接用低可信 baseline 判定 reCamera 效果失败。

### 4. 准备固定评测输入

所有视觉类 demo 在部署验收前，必须先准备固定评测输入，不能只用实时摄像头做效果判断。输入保存在：

```text
~/reCamera_demo/<demo_name>/eval/input/
├── images/                  # 固定图片样本，可为空但视觉 demo 推荐保留
├── video/input.mp4          # 固定视频样本，可由 reCamera 先录制原始视频得到
└── manifest.json            # 输入清单、样本说明、正负样本和边界样本标注
```

要求：
- 同一批输入必须同时用于 seeed NVIDIA 主机 Python baseline 和 reCamera 推理。
- 输入必须优先来自第 3 步确认的模型原始训练/验证/测试数据集或可信开源数据集。
- `manifest.json` 必须记录数据集来源、版本、缓存路径、样本选择理由、类别映射、是否连续帧、是否由图片合成视频。
- 样本必须包含正样本、负样本和边界样本；例如检测类 demo 不能只放目标存在的画面，也要放无目标、遮挡、小目标、多人/多物、低光照等场景。
- 如果 demo 的核心卖点是实时摄像头，也要先录制一段原始输入视频作为补充样本；但除非找不到可靠数据集，实时录制视频不能替代模型数据集评测。
- 所有视觉类 demo 的代码都必须保留三种输入：reCamera 实时相机、本地视频、本地图片。

### 5. 在 seeed NVIDIA 主机运行官方 Python baseline

在 seeed 主机上使用开源项目官方 Python 示例或官方推荐推理脚本跑同一批固定输入，作为 teacher reference。这个结果不是绝对真值，但它代表原始模型在标准 NVIDIA/Python 链路下的预期效果。

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
- 使用环境配置连接到设备。
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
- 评分未通过时，不能进入录制、用户审核、Wiki 草稿、上传或 GitHub 推送，需先判断是否是评测输入或 baseline 不可信；如果输入可信，再检查代码、模型转换和后处理，直到评分通过为止。
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

如果多次修复后仍无法达到默认质量门，必须停止发布流程，在 `DEPLOY_REPORT.md` 中记录失败原因和可复现证据，不写成功记录。

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
- 录制视频流和图片必须要有足够的证据，比如实时 OSD 检测框或者 OSD 数据在画面上，或者导出来在 seeed 主机上叠加。用户看到视频后应能直接理解这个 demo 的视觉效果。
- 最终证据视频应优先使用第 8 步质量门已通过的模型、阈值、NMS 和后处理参数。

### 12. 多模态检验

使用多模态功能读取输出的视频、图片、baseline 对比结果和评分报告，确认内容是否对得上客户想要的效果。如果发现视频展示效果与第 8 步评分结论矛盾，必须回到第 9 步修复，不能继续发布。

### 13. 用户审核

在本机打开视频，由用户审核：
- 内容是否正确
- 效果是否通过
- 是否需要调整

### 14. 生成 Wiki 草稿文档

如果用户审核通过，先生成 Wiki 草稿文档。注意：此时只能作为草稿，不要最终发布/写定 Wiki；最终 Wiki 必须等 GitHub 干净克隆验证闭环通过后再确认。

- 使用模板 `templates/demo-wiki.md`
- 按照现有 wiki 蒸馏格式
- 可以调用 AI 生成图片
- 使用效果图片和视频
- 写完传回本机
- README/Wiki 草稿必须写清楚：GitHub 源码路径、Google Drive 根目录链接、`run/`、`model/`、`evidence/image/`、`evidence/video/` 精确子路径、运行包文件名、模型文件名、必要运行库文件名、公开构建命令和公开运行命令。
- README/Wiki 草稿必须包含质量基准摘要：模型数据集来源、固定输入来源、baseline 命令、reCamera 命令、评分指标、通过阈值、实际得分、关键失败样本说明（如有）。

### 15. 上传运行包、模型和证据到 Google Drive

在推送 GitHub 前，把本 demo 的**运行包(run/)**、模型、完整证据图片、证据视频发布到 Google Drive。`run/` 让用户拉下来直接在 reCamera 跑通：

```bash
# 在 Steven 本机执行，使用已登录的 rclone remote
rclone listremotes
rclone lsd agent:reCamera_Shared/Wiki --max-depth 1

# 准备 run/ 开箱即跑包（本机目录，例如 <demo>/run/）：
#   - reCamera 可执行程序（交叉编译好的 RISC-V ELF，file 应显示 ld-musl-riscv64*）
#   - README.md（精简开箱即跑说明：下载哪些文件、放设备哪、停服务、实测采用的 threshold、验收）
#   - 必要运行时依赖（普通 demo 无需；GB28181 类带 lib/*.so + 一键脚本）

# 创建目标目录
rclone mkdir agent:reCamera_Shared/Wiki/<demo_name>/run/
rclone mkdir agent:reCamera_Shared/Wiki/<demo_name>/model/
rclone mkdir agent:reCamera_Shared/Wiki/<demo_name>/evidence/image/
rclone mkdir agent:reCamera_Shared/Wiki/<demo_name>/evidence/video/

# 上传 run/ 开箱即跑包（可执行程序 + README + 运行时依赖，整目录上传）
rclone copy <local-run-dir> agent:reCamera_Shared/Wiki/<demo_name>/run/ --progress
rclone lsf -R agent:reCamera_Shared/Wiki/<demo_name>/run/

# 上传模型
rclone copy <local-model-dir> agent:reCamera_Shared/Wiki/<demo_name>/model/ \
  --filter "+ *.cvimodel" \
  --filter "+ *.onnx" \
  --filter "+ *.pth" \
  --filter "+ *.pt" \
  --filter "+ *.json" \
  --filter "+ *.txt" \
  --filter "- *" \
  --progress

# 上传完整证据图片
rclone copy <local-evidence-image-dir> agent:reCamera_Shared/Wiki/<demo_name>/evidence/image/ \
  --filter "+ *.png" \
  --filter "+ *.jpg" \
  --filter "+ *.jpeg" \
  --filter "+ *.webp" \
  --filter "+ *.gif" \
  --filter "- *" \
  --progress

# 上传证据视频
rclone copy <local-evidence-video-dir> agent:reCamera_Shared/Wiki/<demo_name>/evidence/video/ \
  --filter "+ *.mp4" \
  --filter "+ *.mov" \
  --filter "+ *.mkv" \
  --filter "+ *.webm" \
  --filter "- *" \
  --progress

# 核对文件列表
rclone lsf -R agent:reCamera_Shared/Wiki/<demo_name>/run/
rclone lsf agent:reCamera_Shared/Wiki/<demo_name>/model/
rclone lsf agent:reCamera_Shared/Wiki/<demo_name>/evidence/image/
rclone lsf agent:reCamera_Shared/Wiki/<demo_name>/evidence/video/

# 用未认证 HTTP 请求确认用户能访问固定 Wiki 根目录
WIKI_ROOT_LINK="https://drive.google.com/drive/folders/1GOQUMCel7fapbJCWzEEynDIvIt-6Wf5p?usp=drive_link"
curl -L -I "$WIKI_ROOT_LINK"
```

要求：
- `agent:` 必须可访问；如果存在但访问失败，在 Steven 本机执行 `rclone config reconnect agent:` 重新授权。
- 如果 `agent:` 不存在，用 `rclone config` 新建 Google Drive remote，remote 名称固定为 `agent`，scope 使用 `drive`。
- 上传目录固定为 `agent:reCamera_Shared/Wiki/<demo_name>/run/`、`.../model/`、`.../evidence/image/`、`.../evidence/video/`，不要改放 GitHub Release 或 LFS。
- **每个 demo 必须有 `run/` 开箱即跑包**：用户拉 `run/` + `model/` 就能不出 Google Drive、不编译、直接在 reCamera 跑通。`run/` 含 reCamera 可执行程序 + `run/README.md` + 必要运行时依赖。
- 默认不要为每个 demo 子目录生成独立分享链接；使用固定 Wiki 根目录公开链接，减少 Google Drive API rate limit 风险。
- `curl -L -I "$WIKI_ROOT_LINK"` 至少能拿到公开 Google Drive 页面响应；如果返回权限错误，必须修复父目录分享权限后再写文档。
- README 和 Wiki 必须同时包含固定 Wiki 根目录链接、四个子路径（run/model/image/video）、`run/` 可执行文件名、模型文件清单、关键证据图片/视频文件清单。


### 16. 推送到 GitHub

用户确认 demo 和文档无误后，提交并推送到 GitHub：

```bash
# 在 seeed 上执行（仓库位于 /home/seeed/sscma-example-sg200x）
cd /home/seeed/sscma-example-sg200x

# 确保代理已配置（seeed 需要走 Clash 代理访问 GitHub）
git config --global http.proxy http://127.0.0.1:7890
git config --global https.proxy http://127.0.0.1:7890

# 拉取最新代码
git pull origin main

# 复制 wiki 和证据到仓库
mkdir -p solutions/sesg-project/<demo_name>/wiki
mkdir -p solutions/sesg-project/<demo_name>/evidence

# 复制 Wiki 文档
cp ~/reCamera_demo/<demo_name>/<demo_name>_Demo_Wiki.md solutions/sesg-project/<demo_name>/wiki/
cp ~/reCamera_demo/<demo_name>/DEPLOY_REPORT.md solutions/sesg-project/<demo_name>/wiki/
cp ~/reCamera_demo/<demo_name>/eval/qa_report.md solutions/sesg-project/<demo_name>/wiki/

# 复制证据截图（只复制关键帧，1-3 张）
cp ~/reCamera_demo/<demo_name>/evidence/image/frame_0000.png solutions/sesg-project/<demo_name>/evidence/
cp ~/reCamera_demo/<demo_name>/evidence/image/frame_0005.png solutions/sesg-project/<demo_name>/evidence/

# 添加新 demo 文件（不要添加大模型文件）
git add solutions/sesg-project/<demo_name>/

# 提交
git commit -m "Add <demo_name> demo with wiki and evidence"

# 推送
git push origin main
```

**注意事项：**
- 不要提交 `.cvimodel`、`.onnx`、`.pth`、`.pt` 等大模型文件到 GitHub
- 大模型文件必须上传到 `agent:reCamera_Shared/Wiki/<demo_name>/model/`，README 和 Wiki 里写固定 Wiki 根目录公开链接和精确子路径
- 证据截图只复制关键帧（1-3 张）到 GitHub，完整证据图片上传到 `agent:reCamera_Shared/Wiki/<demo_name>/evidence/image/`
- 证据视频不提交到 GitHub，上传到 `agent:reCamera_Shared/Wiki/<demo_name>/evidence/video/`
- 提交前检查 `git status` 确认没有意外文件

### 17. GitHub 干净克隆验证闭环

推送到 GitHub 后，**不要立即把 Wiki 当作最终完成**。必须在固定测试线/干净验证目录中拉取刚推送的 GitHub 版本，验证外部用户路径是否完整。

验证原则：

- 验证对象必须来自 GitHub 最新 `main` 的干净 clone，不允许直接使用 `seeed:/home/seeed/sscma-example-sg200x` 工作区或本机未提交文件。
- 验证命令必须使用 README/Wiki 对外公开的构建命令，不允许临时加未记录的参数。
- 编译产物必须用 `file` 验证为 reCamera 可运行的 RISC-V musl ELF。
- 必须从 Google Drive 下载/拉取 README/Wiki 声明的 `run/`、`model/` 和必要运行库，不能使用本机私有路径里的隐式文件。
- 必须把干净 clone 编译出的可执行程序和 Drive 资产部署到 reCamera，并按公开运行命令启动，采集新的验收证据。
- 只有 `GitHub clone -> Drive assets -> build -> deploy -> run -> evidence` 全链路通过，才算完整 demo 推送。
- 如果任何一步失败，返回 `seeed:/home/seeed/sscma-example-sg200x` 修改 demo，重新 commit/push，再从干净 clone 重复验证，直到闭环通过。

参考验证脚本骨架：

```bash
# 在 seeed 或固定测试线执行；目录必须是临时干净目录
VERIFY_ROOT=/tmp/sscma_github_verify_<demo_name>
rm -rf "$VERIFY_ROOT"
mkdir -p "$VERIFY_ROOT"

git clone --depth 1 --branch main https://github.com/RobotXTeam/sscma-example-sg200x.git "$VERIFY_ROOT/repo"
cd "$VERIFY_ROOT/repo"
git rev-parse --short HEAD

export REPO_ROOT="$PWD"
export SDK_ROOT=<path-to-sg2002-sdk>
export TOOLCHAIN_BIN=<path-to-riscv64-musl-toolchain>/bin
export PATH="$TOOLCHAIN_BIN:$PATH"
export SG200X_SDK_PATH="$SDK_ROOT"

cd "$REPO_ROOT/solutions/sesg-project/<demo_name>"
# 使用 README/Wiki 公开构建命令，例如：
rm -rf build && mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
make -j"$(nproc)"
file ./<demo_executable>

# 从 Google Drive 拉取公开声明的运行资产
rclone copy agent:reCamera_Shared/Wiki/<demo_name>/run/ "$VERIFY_ROOT/run/" --progress
rclone copy agent:reCamera_Shared/Wiki/<demo_name>/model/ "$VERIFY_ROOT/model/" --progress

# 部署到 reCamera 并按公开运行命令验收
# 传输可以使用 environments/seeed-recamera/scripts/recamera_scp_to.sh
# 运行可以使用 environments/seeed-recamera/scripts/recamera_ssh.sh
```

验证完成后，Wiki/README 必须更新为验证通过的事实：

- GitHub commit 短 hash。
- 干净 clone 编译命令和 `file` 输出摘要。
- Google Drive 拉取的 `run/` / `model/` / 运行库文件名。
- reCamera 部署路径和公开运行命令。
- 验收证据文件名和保存位置。

### 18. 最终写定 Wiki

只有第 16 步验证闭环通过后，才可以把 Wiki 草稿写定为最终 Wiki：

- 不要写”理论可运行”或”本机验证通过”；必须写清楚 GitHub 干净 clone 后的真实验证结果。
- Wiki 中的构建命令、部署命令、运行命令必须与闭环验证中实际使用的公开命令一致。
- Wiki 中的 Google Drive 路径必须能让用户拿到所有 GitHub 不提交但运行必需的模型和库。
- 如果验证过程中发现 README/Wiki 命令不完整，必须先修 GitHub 代码或文档，重新推送并重跑第 16 步。

### 19. 更新成功记录

**只有完成上述 0-19 全部步骤，才能执行此步骤。**

如果用户中途停止、某一步失败、用户未审核通过、或 GitHub 验证闭环未通过，则**不写入成功记录**。

完成全部 0-19 步后，更新 `success-records.md`：

```markdown
### <demo_name> (<date>)
- 状态：✅ 成功
- GitHub commit：<short_hash>
- Google Drive 路径：`agent:reCamera_Shared/Wiki/<demo_name>/`
- 模型文件：<model_files>
- 特殊依赖：<dependencies or “无”>
- 编译问题：<problem and solution or “无”>
- 验证结果：<verification_summary>
- 关键经验：<lessons_learned or “无”>
```

## 推送到 GitHub 的内容

| 内容 | 路径 | 说明 |
|------|------|------|
| Wiki 文档 | `solutions/sesg-project/<demo>/wiki/<demo>_Demo_Wiki.md` | 公开文档 |
| 部署报告 | `solutions/sesg-project/<demo>/wiki/DEPLOY_REPORT.md` | 内部报告 |
| 质量报告 | `solutions/sesg-project/<demo>/wiki/qa_report.md` | baseline/reCamera 对齐评分摘要 |
| 证据截图 | `solutions/sesg-project/<demo>/evidence/frame_*.png` | 关键帧（1-3 张） |
| 源代码 | `solutions/sesg-project/<demo>/main/*.cpp` | C++ 代码 |
| 构建配置 | `solutions/sesg-project/<demo>/CMakeLists.txt` | CMake 配置 |
| Python 脚本 | `solutions/sesg-project/<demo>/*.py` | 接收器等 |
| README | `solutions/sesg-project/<demo>/README.md` | 项目说明 |

**不提交到 GitHub：**
- 完整证据图片，改上传到 `agent:reCamera_Shared/Wiki/<demo>/evidence/image/`
- 证据视频，改上传到 `agent:reCamera_Shared/Wiki/<demo>/evidence/video/`
- 模型文件（`.cvimodel`、`.onnx`、`.pth`、`.pt`），改上传到 `agent:reCamera_Shared/Wiki/<demo>/model/`
- 中间产物（`.mlir`、`.npz`）
- 校准数据（`calib/`）

面向外部读者的文档硬性要求：
- README、Wiki、demo 文档和项目源码中的注释/示例命令不要出现 Steven 本机绝对路径，例如 `/home/steven/...`、`/home/steven/work/...`、`/home/steven/下载/...`。
- 用相对路径、环境变量或占位路径替代，例如 `$REPO_ROOT`、`$SDK_ROOT`、`$TOOLCHAIN_BIN`、`$DEMO_DIR`、`<path-to-model>`。
- 如果真实命令依赖 Steven 环境，公开文档中使用可迁移的伪命令，并在内部报告另行记录真实路径。
- 默认不要把 `.cvimodel`、`.onnx`、`.pth`、`.pt` 等大模型文件、完整证据图片或证据视频提交或推送到 GitHub 仓库。必须分别上传到 `agent:reCamera_Shared/Wiki/<demo_name>/model/`、`agent:reCamera_Shared/Wiki/<demo_name>/evidence/image/`、`agent:reCamera_Shared/Wiki/<demo_name>/evidence/video/`，并在公开 README/Wiki 里写固定 Wiki 根目录公开链接、精确子路径和文件清单。不要使用 Release/LFS 作为默认方案，也不要只留下 `<path-to-model>` 占位。

## 输出

- 设备上部署成功的项目
- 质量基准报告 - `eval/qa_report.md` 并提交摘要到 GitHub
- 少量关键证据截图 - 提交到 GitHub
- 完整证据图片和证据视频 - 上传到 Google Drive 并在 README/Wiki 贴公开链接
- Wiki 文档 - 提交到 GitHub
- 部署报告 - 提交到 GitHub

## 引用

- 知识库：`knowhubs/reCamera_KnowHub/`
- 环境配置：`environments/seeed-recamera/`
- Demo 模板：`templates/demo-wiki.md`
