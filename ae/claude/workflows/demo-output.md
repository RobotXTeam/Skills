# Demo 输出工作流

## 目的

根据想法或开源项目，使用知识库部署到设备上，验证部署成功，录制运行效果，生成 Wiki 文档(要用户确认录制的视频效果ok之后再生成wiki文档)。
必须完全执行 ## 工作流程（必须强制要求逐步完成所有步骤，不能跳步）

## 输入

- 项目想法或开源项目 URL
- 目标设备（reCamera）


## 工作流程（必须强制要求逐步完成所有步骤，不能跳步）

### 0. 检查历史记录

在开始执行前，读取 `knowhubs/reCamera_KnowHub/success-records.md`，检查是否有可参考的历史记录：

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
- 画质用1080p的分辨率，推理的画面不应该直接放出来，应该是结果画面osd到原画面上这样很清晰（要注意对齐坐标）
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

#### 11.0 本机实时 OSD 显示（先于录制）

录制最终证据前，先在本机弹一个**实时 OSD 窗口**让用户看实时画面，确认检测框/掩码/告警横幅正确、阈值合适，再录。这是用户审核的一等能力（实时看 + 留证据）。

复用 `knowhubs/reCamera_KnowHub/live-osd-display.md` 的能力三件套（`environments/seeed-recamera/scripts/` 下 `udp_sender.py` / `udp_viewer.py` / `udp_relay.py`）。前提：demo 在设备上持续往一个目录写 `frame_NNNN.jpg`（带 OSD 的标注帧）。

```bash
# 1) 本机起 viewer（绑 :9200，弹窗），DISPLAY 按本机桌面设置
DISPLAY=:0 python3 udp_viewer.py 9200 "reCamera <demo> live OSD"

# 2) 设备侧起 sender 直推本机（root，能读 root 写的帧）
#    先判同子网: 设备上 `ip route get <本机IP>` 无 via 即同子网走直推
sudo python3 udp_sender.py /home/recamera/<demo>/live <本机IP> 9200
#    不同子网(只能经 seeed USB): seeed 起 udp_relay.py <seeed_usb_ip>:9100 -> 本机:9200，sender 指向 seeed_usb_ip:9100
```

验收：sender 日志 `sent N frames, X fps` ≈ 摄像头产帧率；本机日志 `pkts=.. complete=..` 中 complete≈sent 即零丢包；窗口里实时帧带正确 OSD。注意：别用 `kill -9` 停摄像头（会泄漏 VPSS 导致下次起不来，见 live-osd-display.md 坑列表）。


### 12. 用户审核

在本机打开视频，由用户审核：
- 内容是否正确
- 效果是否通过
- 是否需要调整

用户审核包含两条腿：第 11.0 步的**本机实时 OSD 显示**（看实时、调阈值/颜色规则）+ 本步的**录制证据回看**（确认最终视频/截图）。两者都通过才算审核完成。

### 13. 生成 Wiki 草稿文档

如果用户审核通过，先生成 Wiki 草稿文档。注意：此时只能作为草稿，不要最终发布/写定 Wiki；最终 Wiki 必须等 GitHub 干净克隆验证闭环通过后再确认。

- 使用模板 `templates/wiki-output.md`
- 按照现有 wiki 蒸馏格式
- 可以调用 AI 生成图片
- 使用效果图片和视频
- 写完传回本机
- README/Wiki 草稿必须写清楚：GitHub 源码路径、Google Drive 根目录链接、`run/`、`model/`、`evidence/image/`、`evidence/video/` 精确子路径、运行包文件名、模型文件名、必要运行库文件名、公开构建命令和公开运行命令。
- README/Wiki 草稿必须包含质量基准摘要：模型数据集来源、固定输入来源、baseline 命令、reCamera 命令、评分指标、通过阈值、实际得分、关键失败样本说明（如有）。

### 14. 上传运行包、模型和证据到 Google Drive

在推送 GitHub 前，把本 demo 的**运行包(run/)**、模型、完整证据图片、证据视频发布到 Google Drive。`run/` 让用户拉下来直接在 reCamera 跑通：

- 所有 rclone 命令在 **Steven 本机**执行（`agent:` remote 只配置在本机，seeed 上没有）。
- 上传命令（登录验证、mkdir 四目录、带 `--filter` 的 run/模型/图片/视频上传、lsf 核对、curl 访问验证）按 `environments/seeed-recamera/network.md` 的"云端资产发布"一节执行。
- `run/` 开箱即跑包的内容规格按 `environments/seeed-recamera/development-policy.md` 的"run/ Ready-to-Run Package (Core Requirement)"一节准备。
- 上传目录固定为 `agent:reCamera_Shared/Wiki/<demo_name>/run/`、`.../model/`、`.../evidence/image/`、`.../evidence/video/`，不要改放 GitHub Release 或 LFS。
- 默认不要为每个 demo 子目录生成独立分享链接；使用固定 Wiki 根目录公开链接，减少 Google Drive API rate limit 风险。
- `curl -L -I "$WIKI_ROOT_LINK"` 至少能拿到公开 Google Drive 页面响应；如果返回权限错误，必须修复父目录分享权限后再写文档。
- README 和 Wiki 必须同时包含固定 Wiki 根目录链接、四个子路径（run/model/image/video）、`run/` 可执行文件名、模型文件清单、关键证据图片/视频文件清单。


### 15. 推送到 GitHub

用户确认 demo 和文档无误后，在 seeed 上（仓库 `/home/seeed/work/sscma-example-sg200x`）提交并推送：确认 Clash 代理配置（见 `environments/seeed-recamera/network.md`"代理配置"）→ `git pull origin main` → 复制 `<demo_name>_Demo_Wiki.md`、`DEPLOY_REPORT.md`、`eval/qa_report.md` 到 `solutions/sesg-project/<demo_name>/wiki/`，复制 1-3 张关键证据帧到 `evidence/` → `git add` → `git commit` → `git push origin main`。复制-推送命令序列参考 `knowhubs/reCamera_KnowHub/capability-map.md` 的"同步流程"。

**注意事项：**
- 提交前检查 `git status` 确认没有意外文件
- 不要提交 `.cvimodel`、`.onnx`、`.pth`、`.pt` 等大模型文件到 GitHub；它们必须在第 14 步已上传到 `agent:reCamera_Shared/Wiki/<demo_name>/model/`
- 证据截图只复制关键帧（1-3 张）到 GitHub，完整证据图片在第 14 步已上传 Drive 的 `evidence/image/`，证据视频在 `evidence/video/`
- GitHub 提交内容与 Drive 上传内容的划分，见本文末尾"推送到 GitHub 的内容"表和 `environments/seeed-recamera/network.md` 的"GitHub 仓库"一节

### 16. GitHub 干净克隆验证闭环

推送到 GitHub 后，**不要立即把 Wiki 当作最终完成**。必须在固定测试线/干净验证目录中拉取刚推送的 GitHub 版本，验证外部用户路径是否完整。

验证原则（干净 clone、只用公开构建命令、`file` 验证 RISC-V musl ELF、从 Drive 拉取声明资产、部署验收、全链路闭环、失败回修）见 `environments/seeed-recamera/development-policy.md` 的"Post-Push Verification Gate"和 `knowhubs/reCamera_KnowHub/project-layout.md` 的"Post-Push Clean Verification"。

参考验证脚本骨架。**注意执行位置**：clone/build/deploy 在 seeed 或固定测试线执行；但 `rclone copy agent:` 拉取 Drive 资产**只能在 Steven 本机**执行（`agent:` remote 只在本机），先拉到本机暂存目录，再传到验证环境：

```bash
# 在 seeed 或固定测试线执行；目录必须是临时干净目录
VERIFY_ROOT=/tmp/sscma_github_verify_<demo_name>
rm -rf "$VERIFY_ROOT"
mkdir -p "$VERIFY_ROOT"

git clone --depth 1 --branch main https://github.com/RobotXTeam/sscma-example-sg200x.git "$VERIFY_ROOT/repo"
cd "$VERIFY_ROOT/repo"
git rev-parse --short HEAD

export REPO_ROOT="$PWD"
export SDK_ROOT=<path-to-sg2002-sdk>                  # seeed 实际路径见 environments/seeed-recamera/toolchain.md
export TOOLCHAIN_BIN=<path-to-riscv64-musl-toolchain>/bin
export PATH="$TOOLCHAIN_BIN:$PATH"
export SG200X_SDK_PATH="$SDK_ROOT"

cd "$REPO_ROOT/solutions/sesg-project/<demo_name>"
# 使用 README/Wiki 公开构建命令，例如：
rm -rf build && mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
make -j"$(nproc)"
file ./<demo_executable>

# 从 Google Drive 拉取公开声明的运行资产（在 Steven 本机执行，agent: 只在本机）
rclone copy agent:reCamera_Shared/Wiki/<demo_name>/run/ <local-staging>/run/ --progress
rclone copy agent:reCamera_Shared/Wiki/<demo_name>/model/ <local-staging>/model/ --progress
# 再传到验证环境：scp/rsync <local-staging>/{run,model} 到 seeed:$VERIFY_ROOT/

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

### 17. 最终写定 Wiki

只有第 16 步验证闭环通过后，才可以把 Wiki 草稿写定为最终 Wiki：

- 不要写”理论可运行”或”本机验证通过”；必须写清楚 GitHub 干净 clone 后的真实验证结果。
- Wiki 中的构建命令、部署命令、运行命令必须与闭环验证中实际使用的公开命令一致。
- Wiki 中的 Google Drive 路径必须能让用户拿到所有 GitHub 不提交但运行必需的模型和库。
- 如果验证过程中发现 README/Wiki 命令不完整，必须先修 GitHub 代码或文档，重新推送并重跑第 16 步。

### 18. 更新成功记录

**只有完成上述 0-18 全部步骤，才能执行此步骤。**

如果用户中途停止、某一步失败、用户未审核通过、或 GitHub 验证闭环未通过，则**不写入成功记录**。

完成全部 0-18 步后，更新 `knowhubs/reCamera_KnowHub/success-records.md`：

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
- Demo 模板：`templates/wiki-output.md`
