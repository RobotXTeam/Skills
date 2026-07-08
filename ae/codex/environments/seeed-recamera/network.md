# 网络配置

## 网络拓扑

- PC -> `seeed`：SSH 别名 `seeed`，用户 `seeed`，密码 `0`。
- seeed LAN：`192.168.4.7`。
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
/home/steven/.claude/skills/ae/environments/seeed-recamera/scripts/seeed_usb_ip.sh
```

## 工作目录结构

### seeed 设备

```
~/reCamera_demo/                         ← 工作根目录
├── <demo_name>/                         ← 如 ppocr_v4、depth_anything
│   ├── DEPLOY_REPORT.md                 ← 部署报告
│   ├── <demo_name>_Demo_Wiki.md         ← Wiki 文档
│   ├── models/                          ← 模型文件
│   └── evidence/
│       ├── image/                       ← 证据图片（完整图片上传 Google Drive）
│       └── video/                       ← 证据视频（上传 Google Drive）

/home/seeed/sscma-example-sg200x/solutions/sesg-project/<demo_name>/  ← 仓库目录
├── CMakeLists.txt
├── README.md
├── main/*.cpp, *.h
├── *.py
├── wiki/                                ← Wiki 文档（提交到 GitHub）
├── evidence/                            ← 少量关键证据截图（提交到 GitHub）
└── model/                               ← 模型文件（不提交；发布到 Google Drive）
```

### 本机环境

```
~/work/reCamera_demo/                    ← 工作根目录
├── <demo_name>/
│   ├── DEPLOY_REPORT.md
│   ├── <demo_name>_Demo_Wiki.md
│   ├── models/
│   └── evidence/
│       ├── image/
│       └── video/

/home/seeed/sscma-example-sg200x/solutions/sesg-project/<demo_name>/  ← 仓库目录
```

## GitHub 仓库

seeed 上的仓库位置：

- 仓库：`/home/seeed/sscma-example-sg200x`
- 远程：`https://github.com/RobotXTeam/sscma-example-sg200x.git`
- 认证：GitHub CLI（用户 congchin38-coder）

常用命令：

```bash
cd /home/seeed/sscma-example-sg200x
git pull origin main    # 拉取最新
git push origin main    # 推送更新
```

推送到 GitHub 的内容：

- Wiki 文档：`solutions/sesg-project/<demo>/wiki/`
- 部署报告：`solutions/sesg-project/<demo>/wiki/DEPLOY_REPORT.md`
- 证据截图：`solutions/sesg-project/<demo>/evidence/frame_*.png`（关键帧 1-3 张）
- 源代码：`solutions/sesg-project/<demo>/main/*.cpp`
- README：`solutions/sesg-project/<demo>/README.md`

不提交到 GitHub：

- 完整证据图片，上传到 `agent:reCamera_Shared/Wiki/<demo>/evidence/image/`
- 证据视频，上传到 `agent:reCamera_Shared/Wiki/<demo>/evidence/video/`
- 模型文件（`.cvimodel`、`.onnx`、`.pth`、`.pt`），上传到 `agent:reCamera_Shared/Wiki/<demo>/model/`
- 中间产物（`.mlir`、`.npz`）
- 校准数据（`calib/`）

## 云端资产发布

Steven 本机已经配置 rclone Google Drive remote：`agent:`。Demo 模型、完整证据图片和证据视频不要放进 GitHub 仓库，统一发布到：

```text
agent:reCamera_Shared/Wiki/<demo_name>/model/
agent:reCamera_Shared/Wiki/<demo_name>/evidence/image/
agent:reCamera_Shared/Wiki/<demo_name>/evidence/video/
```

执行顺序：

```bash
rclone listremotes
rclone lsd agent:reCamera_Shared/Wiki --max-depth 1
rclone mkdir agent:reCamera_Shared/Wiki/<demo_name>/model/
rclone mkdir agent:reCamera_Shared/Wiki/<demo_name>/evidence/image/
rclone mkdir agent:reCamera_Shared/Wiki/<demo_name>/evidence/video/
rclone copy <local-model-dir> agent:reCamera_Shared/Wiki/<demo_name>/model/ --progress
rclone copy <local-evidence-image-dir> agent:reCamera_Shared/Wiki/<demo_name>/evidence/image/ --progress
rclone copy <local-evidence-video-dir> agent:reCamera_Shared/Wiki/<demo_name>/evidence/video/ --progress
rclone lsf agent:reCamera_Shared/Wiki/<demo_name>/model/
rclone lsf agent:reCamera_Shared/Wiki/<demo_name>/evidence/image/
rclone lsf agent:reCamera_Shared/Wiki/<demo_name>/evidence/video/
WIKI_ROOT_LINK="https://drive.google.com/drive/folders/1GOQUMCel7fapbJCWzEEynDIvIt-6Wf5p?usp=drive_link"
curl -L -I "$WIKI_ROOT_LINK"
```

README 和 Wiki 必须写入 `$WIKI_ROOT_LINK` 对应的固定 Google Drive 根目录公开链接，并列出模型、图片、视频的精确子路径和文件名。不要把 rclone token、配置文件或任何密钥写入公开文档。

如果 `agent:` 已存在但访问失败，执行：

```bash
rclone config reconnect agent:
```

如果 `agent:` 不存在，执行 `rclone config` 新建 Google Drive remote，名称固定为 `agent`，scope 使用 `drive`。
