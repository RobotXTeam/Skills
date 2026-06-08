# 工具链配置

## 本地开发根目录

检查这些目录 before downloading：

- `/home/steven/sscma-example-sg200x`
- `/home/steven/sg2002_recamera_emmc`
- `/home/steven/host-tools`
- `/home/steven/work/risc-v/recamera`
- `/home/steven/reCamera-OS`

## C++ 开发环境

- 本地 C++ demo 仓库：`/home/steven/sscma-example-sg200x`
- 本地 SG200X SDK：`/home/steven/sg2002_recamera_emmc`
- 本地交叉编译器：`/home/steven/host-tools/gcc/riscv64-linux-musl-x86_64/bin/riscv64-unknown-linux-musl-gcc`

## 模型转换环境

- Docker 镜像：`sophgo/tpuc_dev:v3.1`
- TPU-MLIR 路径：`/workspace/tpu-mlir`

## 录制环境

- Xvfb 和 ffmpeg 已安装在 `seeed` 上，用于 OpenCV 接收器录制
