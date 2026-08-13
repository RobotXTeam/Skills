# 网络配置

## 网络拓扑

- PC -> `seeed`：SSH 别名 `seeed`，用户 `seeed`，密码 `0`。
- seeed LAN：`192.168.2.113`。
- seeed Linkbit`10.88.222.222`。
- seeed Tailscale：`100.76.45.91`。
- seeed OS：Ubuntu 22.04。
- `seeed` -> reCamera：直接 USB/LAN `192.168.42.1`。
- reCamera SSH：用户 `recamera`，密码可能是 `recamera.1` 或 `kkk000++`；优先使用封装脚本自动尝试。
- reCamera OS API：`http://192.168.42.1/api/version`，最后验证 `0.2.3`。
- reCamera OS：Buildroot 2021.05，Linux 5.10.4 RISC-V。

## 代理配置

seeed 需要通过 Clash 代理访问 GitHub：

- 代理地址：`http://127.0.0.1:7890`
- 代理软件：Clash Verge（ninja-mihomo）
- 配置文件：`/home/seeed/.local/share/io.github.clash-verge-ninja.clash-verge-ninja/runtime-seeed.yaml`

Git 代理配置：

```bash
git config --global http.proxy http://127.0.0.1:7890
git config --global https.proxy http://127.0.0.1:7890
```

首次使用需要配置 SSH 密钥：

```bash
# 生成 SSH 密钥
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ''

# 添加到 GitHub（需要本地 gh 操作）
gh ssh-key add ~/.ssh/id_ed25519.pub --title 'seeed-device'
```

## 动态 IP 处理

重要：seeed 在 `192.168.42.0/24` 上的 USB IP 在 reCamera 重启或 USB 重连后会变化。永远不要硬编码旧值如 `192.168.42.197`。总是运行：

```bash
environments/seeed-recamera/scripts/seeed_usb_ip.sh
```

## 工作目录结构

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

/home/seeed/work/sscma-example-sg200x/solutions/sesg-project/<demo_name>/  ← 仓库目录
├── CMakeLists.txt                       ← ✅ 提交
├── README.md                            ← ✅ 提交
├── main/*.cpp, *.h                      ← ✅ 提交
├── *.py                                 ← ✅ 提交
├── wiki/                                ← ✅ 提交
│   ├── <demo_name>_Demo_Wiki.md
│   ├── DEPLOY_REPORT.md
│   └── qa_report.md                     ← ✅ 提交，baseline/reCamera 对齐评分摘要
├── evidence/                            ← ✅ 提交少量关键截图
│   └── frame_*.png                      ← 只提交关键帧（1-3 张）
└── model/                               ← ❌ .gitignore 忽略；模型发布到 Google Drive
```

### seeed 设备环境（编写、编译代码和推仓库的地方）

```
~/reCamera_demo/                         ← 工作根目录
├── <demo_name>/                         ← 如 ppocr_v4、depth_anything
│   ├── DEPLOY_REPORT.md                 ← 部署报告
│   ├── <demo_name>_Demo_Wiki.md         ← Wiki 文档
│   ├── models/                          ← 模型文件
│   └── evidence/
│       ├── image/                       ← 证据图片（完整图片上传 Google Drive）
│       └── video/                       ← 证据视频（上传 Google Drive）

/home/seeed/work/sscma-example-sg200x/solutions/sesg-project/<demo_name>/  ← 仓库目录
├── CMakeLists.txt
├── README.md
├── main/*.cpp, *.h
├── *.py
├── wiki/                                ← Wiki 文档（提交到 GitHub）
├── evidence/                            ← 少量关键证据截图（提交到 GitHub）
└── model/                               ← 模型文件（不提交；发布到 Google Drive）
```


## GitHub 仓库

seeed 上的仓库位置：

- 仓库：`/home/seeed/work/sscma-example-sg200x`
- 远程：`https://github.com/RobotXTeam/sscma-example-sg200x.git`
- 认证：GitHub CLI（用户 congchin38-coder）

常用命令：

```bash
cd /home/seeed/work/sscma-example-sg200x
git pull origin main    # 拉取最新
git push origin main    # 推送更新
```

推送到 GitHub 的内容：

- Wiki 文档：`solutions/sesg-project/<demo>/wiki/`
- 部署报告：`solutions/sesg-project/<demo>/wiki/DEPLOY_REPORT.md`
- 质量报告：`solutions/sesg-project/<demo>/wiki/qa_report.md`
- 证据截图：`solutions/sesg-project/<demo>/evidence/frame_*.png`（关键帧 1-3 张）
- 源代码：`solutions/sesg-project/<demo>/main/*.cpp`
- 构建入口：`solutions/sesg-project/<demo>/CMakeLists.txt`（或 `build.sh`）
- Python 脚本：`solutions/sesg-project/<demo>/*.py`
- README：`solutions/sesg-project/<demo>/README.md`

不提交到 GitHub：

- 完整证据图片，上传到 `agent:reCamera_Shared/Wiki/<demo>/evidence/image/`
- 证据视频，上传到 `agent:reCamera_Shared/Wiki/<demo>/evidence/video/`
- 模型文件（`.cvimodel`、`.onnx`、`.pth`、`.pt`），上传到 `agent:reCamera_Shared/Wiki/<demo>/model/`
- 中间产物（`.mlir`、`.npz`）
- 校准数据（`calib/`）

明确此 GitHub 仓库的目的是**上传完整的项目代码并提供给外部用户，以便用户能够自行复刻 demo 与 wiki**。
因此，代码必须绝对完整，确保用户拿到手之后可以直接在相应的编译环境中编译出能够在 reCamera 上运行的可执行程序。在提交的代码、脚本以及说明文档中，**绝对不要包含本机部署的绝对路径**（例如 `/home/steven/...` 或 `/home/seeed/...`），**必须使用相对路径**或通用环境变量来代替。

GitHub 代码完整性要求（完整源码、构建入口可按公开写法直接运行、外部资产声明、不依赖私有绝对路径等）见 `knowhubs/reCamera_KnowHub/project-layout.md`（GitHub Completeness Contract）。

## 云端资产发布

Steven 本机已经配置 rclone Google Drive remote：`agent:`。Demo 运行包、模型、完整证据图片和证据视频不要放进 GitHub 仓库，统一发布到：

```text
agent:reCamera_Shared/Wiki/<demo_name>/run/
agent:reCamera_Shared/Wiki/<demo_name>/model/
agent:reCamera_Shared/Wiki/<demo_name>/evidence/image/
agent:reCamera_Shared/Wiki/<demo_name>/evidence/video/
```

执行顺序（以下 rclone 命令全部在 **Steven 本机**执行，`agent:` remote 只配置在本机；seeed 上没有该 remote）：

```bash
rclone listremotes
rclone lsd agent:reCamera_Shared/Wiki --max-depth 1
rclone mkdir agent:reCamera_Shared/Wiki/<demo_name>/run/
rclone mkdir agent:reCamera_Shared/Wiki/<demo_name>/model/
rclone mkdir agent:reCamera_Shared/Wiki/<demo_name>/evidence/image/
rclone mkdir agent:reCamera_Shared/Wiki/<demo_name>/evidence/video/

# 上传 run/ 开箱即跑包（整目录上传，不加过滤）
rclone copy <local-run-dir> agent:reCamera_Shared/Wiki/<demo_name>/run/ --progress
rclone lsf -R agent:reCamera_Shared/Wiki/<demo_name>/run/

# 上传模型（只上传模型和配置类文件）
rclone copy <local-model-dir> agent:reCamera_Shared/Wiki/<demo_name>/model/ \
  --filter "+ *.cvimodel" --filter "+ *.onnx" --filter "+ *.pth" --filter "+ *.pt" \
  --filter "+ *.json" --filter "+ *.txt" --filter "- *" --progress

# 上传完整证据图片
rclone copy <local-evidence-image-dir> agent:reCamera_Shared/Wiki/<demo_name>/evidence/image/ \
  --filter "+ *.png" --filter "+ *.jpg" --filter "+ *.jpeg" --filter "+ *.webp" --filter "+ *.gif" \
  --filter "- *" --progress

# 上传证据视频
rclone copy <local-evidence-video-dir> agent:reCamera_Shared/Wiki/<demo_name>/evidence/video/ \
  --filter "+ *.mp4" --filter "+ *.mov" --filter "+ *.mkv" --filter "+ *.webm" \
  --filter "- *" --progress

rclone lsf agent:reCamera_Shared/Wiki/<demo_name>/model/
rclone lsf agent:reCamera_Shared/Wiki/<demo_name>/evidence/image/
rclone lsf agent:reCamera_Shared/Wiki/<demo_name>/evidence/video/

WIKI_ROOT_LINK="https://drive.google.com/drive/folders/1GOQUMCel7fapbJCWzEEynDIvIt-6Wf5p?usp=drive_link"
curl -L -I "$WIKI_ROOT_LINK"
```

`curl` 应返回可公开打开的 HTTP 响应（200 或 Google Drive 公开页面跳转）；如果返回权限错误，必须先修复父目录分享权限，再写 README/Wiki。

README 和 Wiki 必须写入 `$WIKI_ROOT_LINK` 对应的固定 Google Drive 根目录公开链接，并列出 `run/`、`model/`、`evidence/image/`、`evidence/video/` 四个子路径和文件名：运行包部分列出可执行文件名和 `run/README.md`，模型部分列出需要下载的模型文件名，证据部分列出关键证据文件名。不要只写 `<path-to-model>` 占位。不要把 rclone token、配置文件或任何密钥写入公开文档。

如果 `agent:` 已存在但访问失败，在 **Steven 本机**执行：

```bash
rclone config reconnect agent:
```

如果 `agent:` 不存在，执行 `rclone config` 新建 Google Drive remote，名称固定为 `agent`，scope 使用 `drive`。

`run/` 开箱即跑包的内容规格见 `environments/seeed-recamera/development-policy.md`（run/ Ready-to-Run Package）。

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
README 和 Wiki 默认贴固定 Wiki 根目录链接，并写清楚以上子路径，让用户按 demo 名称进入对应文件夹。只有需要直达子目录时才额外尝试 `rclone link`；如果遇到 Google Drive API rate limit，不要反复重试直达链接。
```
