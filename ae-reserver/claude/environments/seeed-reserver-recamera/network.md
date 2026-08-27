# 网络配置

## 迁移说明（2026-08-13）

本环境于 2026-08-13 从旧部署主机迁移到新主机 `seeed-reserver`，本文档所有 IP、路径、凭据均以 seeed-reserver 实测为准。seeed-reserver 双盘分工：

- **固态盘**（238G，nvme，挂载 `/`）：跑程序、编译——代码仓库、交叉工具链、SDK、TPU 转换工作区都在这里。
- **机械盘**（466G，NTFS，挂载 `/media/seeed/新加卷`，fstab 持久挂载 UUID=3A1478E31478A413）：只放大件数据（模型、证据、数据集等）；不放可执行程序、不放 build 目录、不放 docker。

## 网络拓扑

- PC -> `seeed-reserver`：Steven 本机 SSH 别名 `seeed-reserver`（`~/.ssh/config` 已配置，且已加 Steven 公钥免密），登录用户 `seeed0`，密码 `0`。
- seeed-reserver LAN：`192.168.2.194`。
- seeed-reserver OS：Ubuntu 24.04.3 LTS x86_64；Python 3.12.3（系统级，无 conda）。
- seeed-reserver 无 NVIDIA GPU（只有 Intel UHD 核显）：Python teacher baseline 一律纯 CPU 推理（demo 以 CNN 为主，CPU 完全可跑，无需 GPU 主机）；CPU 较慢，超大输入适当控制帧数即可。
- `seeed-reserver` -> reCamera：设备已物理连接在 seeed-reserver 上（USB gadget，主机侧网口 192.168.42.x/24 动态分配）。设备 SSH 实测可用地址：`recamera@192.168.42.1`（USB gadget 网关侧地址）；LAN 侧 `192.168.2.102`（eth0）同样可用；任一地址瞬时不通时换另一路重试。Web UI `http://192.168.42.1`。
- reCamera SSH：用户 `recamera`，密码 `kkk000++`（2026-08-19 实测；`recamera.1` 兜底）；优先使用封装脚本自动尝试。
- reCamera OS API：`http://192.168.42.112/api/version`，2026-08-13 实测 `0.3.1`。
- reCamera OS：Buildroot 2021.05，Linux 5.10.4 RISC-V。
- reCamera 网卡：`usb0`（USB gadget，默认 .1，已加静态别名 **.112**）+ `eth0`（LAN，192.168.2.102/24）。`.112` 别名已持久化到设备 `/etc/init.d/S70hardware`（原文件备份为 `S70hardware.bak-migration-20260813`），重启不丢；设备端改动需要 sudo（recamera 用户密码即 sudo 密码）。
- seeed-reserver 上还跑着 1Panel/openclaw 等容器，与 reCamera 工作流无关，不要去动。

## 流媒体/信令服务器（SRS）

seeed-reserver 上运行 GB28181 + RTMP 服务器容器 `srs-gb`（`ossrs/srs:5`，host 网络，`--restart unless-stopped`），配置文件持久化在 `/home/seeed0/srs/srs.gb.conf`（SRS5 语法：每条指令以分号结尾）。监听端口：`1935` RTMP、`5060` SIP/TCP、`9000` GB28181 媒体/TCP、`1985` HTTP API、`8080` HTTP-FLV。SIP serial=`34020000002000000001`、realm=`34020000`，与 `gb28181_yolo` demo 的 `gb28181_client.c` 默认值匹配；推流地址形如 `rtmp://192.168.2.194:1935/live/recamera`。SIP 库交叉编译产物在 `/home/seeed0/gb28181/install`。

## GitHub 直连，无需代理

seeed-reserver 访问 GitHub 直连可用，无需任何代理：

- seeed-reserver 上没有也不需要 Clash 或任何其它代理软件。
- **不要**为 git 配置 `http.proxy` / `https.proxy`（`git config --global http.proxy ...` 一类命令禁止执行）。
- GitHub 认证：`gh` CLI 已登录 congchin38-coder（凭据在 `~/.config/gh/hosts.yml`），`gh auth setup-git` 已执行。
- 仓库远程当前仍是带 PAT 的 https URL（迁移时沿用），保持现状，勿改动。

## reCamera 固定 IP

reCamera 设备地址固定为 **`192.168.42.112`**（2026-08-13 用户确认）。所有连接、部署、API 访问一律使用此地址，不再使用旧的 `192.168.42.1`。若某天该地址不通，先用诊断脚本在 seeed-reserver 上探测 USB 网段现状再向用户确认，禁止擅自改回旧值或硬编码其它 192.168.42.x：

```bash
environments/seeed-reserver-recamera/scripts/reserver_usb_ip.sh
```

## 工作目录结构

### seeed-reserver 主机环境（工作产物：机械盘）

工作产物根目录：`/media/seeed/新加卷/reCamera/reCamera_demo`（软链接 `/home/seeed0/reCamera_demo` 指向它）。只放大件数据，不放可执行程序、不放 build 目录：

```
~/reCamera_demo/                         ← /media/seeed/新加卷/reCamera/reCamera_demo 的软链接
├── <demo_name>/                         ← 如 ppocr_v4、depth_anything
│   ├── DEPLOY_REPORT.md                 ← 部署报告
│   ├── <demo_name>_Demo_Wiki.md         ← Wiki 文档
│   ├── models/                          ← 模型文件（不提交Github，上传 Google Drive）
│   ├── calib/                           ← 校准数据（不提交Github，上传 Google Drive）
│   ├── datasets/                        ← 可选；本 demo 从共享数据集缓存抽取出的样本说明或软链接
│   ├── eval/                            ← 质量基准评测产物
│   │   ├── input/                       ← 固定评测输入（图片/视频/manifest）；seeed-reserver 无 GPU，输入应精简
│   │   ├── baseline/                    ← seeed-reserver CPU Python baseline 输出
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
└── *.mlir, *.npz                        ← 中间产物（不提交Github；转换阶段建议放固态盘 /home/seeed0/tpu-workspace）

~/reCamera_demo/datasets/                ← 共享数据集缓存，所有 demo 复用
├── coco/
├── dota/
├── voc/
├── icdar/
├── imagenet/
└── ...

/home/seeed0/sscma-example-sg200x/solutions/sesg-project/<demo_name>/  ← 仓库目录（固态盘）
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

### seeed-reserver 主机环境（编写、编译代码和推仓库的地方）

仓库在固态盘，是唯一真源（编辑 + 编译 + 提交）：

```
~/reCamera_demo/                         ← 工作产物根目录（软链接 → /media/seeed/新加卷/reCamera/reCamera_demo）
├── <demo_name>/                         ← 如 ppocr_v4、depth_anything
│   ├── DEPLOY_REPORT.md                 ← 部署报告
│   ├── <demo_name>_Demo_Wiki.md         ← Wiki 文档
│   ├── models/                          ← 模型文件
│   └── evidence/
│       ├── image/                       ← 证据图片（完整图片上传 Google Drive）
│       └── video/                       ← 证据视频（上传 Google Drive）

/home/seeed0/sscma-example-sg200x/solutions/sesg-project/<demo_name>/  ← 仓库目录
├── CMakeLists.txt
├── README.md
├── main/*.cpp, *.h
├── *.py
├── wiki/                                ← Wiki 文档（提交到 GitHub）
├── evidence/                            ← 少量关键证据截图（提交到 GitHub）
└── model/                               ← 模型文件（不提交；发布到 Google Drive）
```

固态盘上的其它关键目录：

- `/home/seeed0/sscma-example-sg200x` — 代码仓库（唯一真源）
- `/home/seeed0/toolchain/` — 交叉编译器（`host-tools/...`）与 SDK（`sg2002_recamera_emmc`）
- `/home/seeed0/tpu-workspace` — TPU 转换工作区（挂载进模型转换容器 `/workspace`）


## GitHub 仓库

seeed-reserver 上的仓库位置：

- 仓库：`/home/seeed0/sscma-example-sg200x`
- 远程：当前为带 PAT 的 https URL（迁移时沿用，保持现状，勿改动）
- 认证：gh CLI 已登录 congchin38-coder（凭据在 `~/.config/gh/hosts.yml`），`gh auth setup-git` 已执行；GitHub 直连，无需代理

常用命令：

```bash
cd /home/seeed0/sscma-example-sg200x
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
因此，代码必须绝对完整，确保用户拿到手之后可以直接在相应的编译环境中编译出能够在 reCamera 上运行的可执行程序。在提交的代码、脚本以及说明文档中，**绝对不要包含本机部署的绝对路径**（例如 `/home/steven/...` 或 `/home/seeed0/...`），**必须使用相对路径**或通用环境变量来代替。

GitHub 代码完整性要求（完整源码、构建入口可按公开写法直接运行、外部资产声明、不依赖私有绝对路径等）见 `knowhubs/reCamera_KnowHub/project-layout.md`（GitHub Completeness Contract）。

## 云端资产发布

Steven 本机已经配置 rclone Google Drive remote：`agent:`。Demo 运行包、模型、完整证据图片和证据视频不要放进 GitHub 仓库，统一发布到：

```text
agent:reCamera_Shared/Wiki/<demo_name>/run/
agent:reCamera_Shared/Wiki/<demo_name>/model/
agent:reCamera_Shared/Wiki/<demo_name>/evidence/image/
agent:reCamera_Shared/Wiki/<demo_name>/evidence/video/
```

执行顺序（以下 rclone 命令全部在 **Steven 本机**执行；rclone 与 `agent:` remote 只配置在 Steven 本机，seeed-reserver 上没有安装 rclone，也没有该 remote）：

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

`run/` 开箱即跑包的内容规格见 `environments/seeed-reserver-recamera/development-policy.md`（run/ Ready-to-Run Package）。

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
