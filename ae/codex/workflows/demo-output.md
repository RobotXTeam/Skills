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
│   └── evidence/
│       ├── image/                       ← 证据图片（关键帧提交Github，完整图片上传 Google Drive）
│       │   ├── frame_0000.png
│       │   └── ...
│       └── video/                       ← 证据视频（不提交Github，上传 Google Drive）
│           └── demo.mp4
│
├── export_*.py                          ← 导出脚本
└── *.mlir, *.npz                        ← 中间产物（不提交Github）

/home/seeed/sscma-example-sg200x/solutions/sesg-project/<demo_name>/  ← 仓库目录
├── CMakeLists.txt                       ← ✅ 提交
├── README.md                            ← ✅ 提交
├── main/*.cpp, *.h                      ← ✅ 提交
├── *.py                                 ← ✅ 提交
├── wiki/                                ← ✅ 提交
│   ├── <demo_name>_Demo_Wiki.md
│   └── DEPLOY_REPORT.md
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


### 3. 部署到设备

执行部署步骤：
- 使用环境配置连接到设备
- 按照规划的步骤操作
- 记录每个步骤的结果
- 所有的视觉类demo的代码都需要的三个输入，一个是直接用reCamera的相机进行录制输入，二是留一个是本地视频输入，三是本地图片输入
- 所有的demo可执行程序在reCaera上运行时都要用sudo去执行

### 4. 验证输出

验证部署是否成功：
- 截图查看输出内容
- 检查日志文件
- 验证功能是否正常

### 5. 多模态检验
- 使用多模态功能读输出的截图和内容是否对的上，如果你发现输出的内容和本demo要的结果不同，说明其实你跑通了流程，但是代码是不对的，你要的不仅仅是“跑通”，而是“跑好”，要验证你这个demo输出的东西是客户想要的，而不是仅仅跑通

### 6. 录制视频流和图片

录制设备的运行效果：
- 使用主机拉取设备的视频流
- 录制视频窗口
- 传回本机
- 录制视频流和图片必须要有足够的证据，比如实时osd检测框或者osd数据在画面上，或者导出来在seeed主机上去加，但总之用户看到视频之后就直接能看到这个demo的视觉效果，要让用户知道，原来这个demo的作用是这样的

### 7. 多模态检验
- 使用多模态功能读输出的视频、图片和内容是否对的上，如果你发现输出的内容和本demo要的结果不同，说明其实你跑通了流程，但是代码是不对的，你要的不仅仅是“跑通”，而是“跑好”，要验证你这个demo输出的东西是客户想要的，而不是仅仅跑通

### 8. 用户审核

在本机打开视频，由用户审核：
- 内容是否正确
- 效果是否通过
- 是否需要调整

### 9. 生成 Wiki 草稿文档

如果用户审核通过，先生成 Wiki 草稿文档。注意：此时只能作为草稿，不要最终发布/写定 Wiki；最终 Wiki 必须等 GitHub 干净克隆验证闭环通过后再确认。

- 使用模板 `templates/demo-wiki.md`
- 按照现有 wiki 蒸馏格式
- 可以调用 AI 生成图片
- 使用效果图片和视频
- 写完传回本机
- README/Wiki 草稿必须写清楚：GitHub 源码路径、Google Drive 根目录链接、`run/`、`model/`、`evidence/image/`、`evidence/video/` 精确子路径、运行包文件名、模型文件名、必要运行库文件名、公开构建命令和公开运行命令。

### 10. 上传运行包、模型和证据到 Google Drive

在推送 GitHub 前，把本 demo 的**运行包(run/)**、模型、完整证据图片、证据视频发布到 Google Drive。`run/` 让用户拉下来直接在 reCamera 跑通：

```bash
# 在 Steven 本机执行，使用已登录的 rclone remote
rclone listremotes
rclone lsd agent:reCamera_Shared/Wiki --max-depth 1

# 准备 run/ 开箱即跑包（本机目录，例如 <demo>/run/）：
#   - reCamera 可执行程序（交叉编译好的 RISC-V ELF，file 应显示 ld-musl-riscv64*）
#   - README.md（精简开箱即跑说明：下载哪些文件、放设备哪、停服务、运行命令 threshold 0.60、验收）
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


### 11. 推送到 GitHub

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

### 12. GitHub 干净克隆验证闭环

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

### 13. 最终写定 Wiki

只有第 10 步验证闭环通过后，才可以把 Wiki 草稿写定为最终 Wiki：

- 不要写”理论可运行”或”本机验证通过”；必须写清楚 GitHub 干净 clone 后的真实验证结果。
- Wiki 中的构建命令、部署命令、运行命令必须与闭环验证中实际使用的公开命令一致。
- Wiki 中的 Google Drive 路径必须能让用户拿到所有 GitHub 不提交但运行必需的模型和库。
- 如果验证过程中发现 README/Wiki 命令不完整，必须先修 GitHub 代码或文档，重新推送并重跑第 10 步。

### 14. 更新成功记录

**只有完成上述全部 13 步，才能执行此步骤。**

如果用户中途停止、某一步失败、用户未审核通过、或 GitHub 验证闭环未通过，则**不写入成功记录**。

完成全部 13 步后，更新 `success-records.md`：

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
- 少量关键证据截图 - 提交到 GitHub
- 完整证据图片和证据视频 - 上传到 Google Drive 并在 README/Wiki 贴公开链接
- Wiki 文档 - 提交到 GitHub
- 部署报告 - 提交到 GitHub

## 引用

- 知识库：`knowhubs/reCamera_KnowHub/`
- 环境配置：`environments/seeed-recamera/`
- Demo 模板：`templates/demo-wiki.md`
