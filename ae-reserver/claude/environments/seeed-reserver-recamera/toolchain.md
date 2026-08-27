# 工具链配置

## 唯一开发与编译根目录

所有 reCamera C++ demo 的代码和编译都在 `seeed-reserver` 主机上，统一根目录：

- seeed-reserver C++ demo 仓库（本地仓库 = 编译位置 = 唯一真源）：`/home/seeed0/sscma-example-sg200x`
- 新 demo 默认目录：`/home/seeed0/sscma-example-sg200x/solutions/sesg-project/<demo_name>`

不再保留"本机副本/迁移前参考"这种双份概念。编辑、构建、打包、提交全部在 `seeed-reserver` 主机的 `/home/seeed0/sscma-example-sg200x` 内完成；本机不再放第二份 demo 仓库。

磁盘分工：仓库、工具链、build 目录一律在固态盘（挂载 `/`）；机械盘 `/media/seeed/新加卷` 只放大件数据（模型、证据、数据集），不放可执行程序、不放 build 目录、不放 docker。

## seeed-reserver 上的工具链目录

- seeed-reserver C++ demo 仓库：`/home/seeed0/sscma-example-sg200x`
- SG200X SDK：`$SDK_ROOT` = `/home/seeed0/toolchain/sg2002_recamera_emmc`（即 `$SG200X_SDK_PATH`）
- 交叉编译器：`$TOOLCHAIN_BIN` = `/home/seeed0/toolchain/host-tools/gcc/riscv64-linux-musl-x86_64/bin`（`riscv64-unknown-linux-musl-gcc`）

环境变量 `TOOLCHAIN_BIN` / `SDK_ROOT` / `SG200X_SDK_PATH` / `PATH` 已写入 seeed-reserver 的 `~/.bashrc` 和 `~/.profile`，**交互式 shell 生效**；但在脚本或非交互 SSH 命令中，**仍应显式写完整路径 export**：

```bash
export TOOLCHAIN_BIN=/home/seeed0/toolchain/host-tools/gcc/riscv64-linux-musl-x86_64/bin
export SDK_ROOT=/home/seeed0/toolchain/sg2002_recamera_emmc
export SG200X_SDK_PATH=$SDK_ROOT
export PATH=$TOOLCHAIN_BIN:$PATH
```

## C++ 开发环境

- seeed-reserver C++ demo 仓库：`/home/seeed0/sscma-example-sg200x`
- SG200X SDK：`/home/seeed0/toolchain/sg2002_recamera_emmc`
- 交叉编译器：`/home/seeed0/toolchain/host-tools/gcc/riscv64-linux-musl-x86_64/bin/riscv64-unknown-linux-musl-gcc`
- 构建工具：cmake、ninja 已安装

## 模型转换环境

- Docker 镜像：`sophgo/tpuc_dev:v3.1`（已加载到 seeed-reserver）
- 容器名：`tpuc_dev`（`docker create` 已建，挂载 `-v /home/seeed0/tpu-workspace:/workspace`）
- 主机侧 TPU 转换工作区：`/home/seeed0/tpu-workspace`（固态盘）
- TPU-MLIR 路径：`/workspace/tpu-mlir`（容器内）
- 镜像备份：机械盘 `/media/seeed/新加卷/reCamera/bulk/docker-backup/tpuc_dev_v3.1.tar`

## Python 环境

- seeed-reserver 系统 Python 3.12.3，无 conda。
- 从旧主机迁来的 Python 3.10 venv（如 `reCamera_demo/pvnet_venv`）在 seeed-reserver（3.12）上不能直接用；旧 venv 保留在机械盘作存档。
- 已重建的 baseline venv：`/home/seeed0/venvs/pvnet`（Python 3.10，deadsnakes PPA 安装；torch 1.11.0 / torchvision 0.12.0 / opencv-headless 4.9 / onnx 1.16，与旧环境同版本，激活后 CPU 推理可用）。
- seeed-reserver 访问 PyPI 直连不稳定，pip 安装一律加 `-i https://pypi.tuna.tsinghua.edu.cn/simple`。
- seeed-reserver 无 NVIDIA GPU（只有 Intel UHD 核显）：Python teacher baseline 一律纯 CPU 推理（demo 以 CNN 为主，CPU 完全可跑，无需 GPU 主机）；CPU 较慢，超大输入适当控制帧数即可。

## 录制环境

- Xvfb 和 ffmpeg 已安装在 `seeed-reserver` 上，用于 OpenCV 接收器录制

## 已装工具

git、gh、sshpass、docker、ffmpeg、Xvfb、ninja、cmake、python3、rsync、curl。未装 rclone（rclone 与 `agent:` remote 只在 Steven 本机）。

## 下载/克隆前先检查

在下载或克隆资源前，先检查 `seeed-reserver` 上这些已有目录：

- `/home/seeed0/sscma-example-sg200x`
- `/home/seeed0/toolchain/sg2002_recamera_emmc`
- `/home/seeed0/toolchain/host-tools`
- `/home/seeed0/tpu-workspace`
- `/media/seeed/新加卷/reCamera/reCamera_demo`（软链接 `~/reCamera_demo`）
- `/media/seeed/新加卷/reCamera/bulk/`（备份/杂物）

## 其它注意事项

- seeed-reserver 上还跑着 1Panel/openclaw 容器，与 reCamera 工作流无关，不要去动。
