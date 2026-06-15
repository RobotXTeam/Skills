# 工具链配置

## 唯一开发与编译根目录

所有 reCamera C++ demo 的代码和编译都在 `seeed` 主机上，统一根目录：

- seeed C++ demo 仓库（本地仓库 = 编译位置 = 唯一真源）：`/home/seeed/sscma-example-sg200x`
- 新 demo 默认目录：`/home/seeed/sscma-example-sg200x/solutions/sesg-project/<demo_name>`

不再保留"本机副本/迁移前参考"这种双份概念。编辑、构建、打包、提交全部在 `seeed` 主机的 `/home/seeed/sscma-example-sg200x` 内完成；本机不再放第二份 demo 仓库。

## seeed 上的工具链目录

- seeed C++ demo 仓库：`/home/seeed/sscma-example-sg200x`
- SG200X SDK：`/home/seeed/桌面/sg2002_recamera_emmc`
- 交叉编译器：`/home/seeed/桌面/host-tools/gcc/riscv64-linux-musl-x86_64/bin/riscv64-unknown-linux-musl-gcc`
  - 另有一份等价编译器：`/home/seeed/zsz/TOOL/riscv64-linux-musl-x86_64/bin/riscv64-unknown-linux-musl-gcc`

## C++ 开发环境

- seeed C++ demo 仓库：`/home/seeed/sscma-example-sg200x`
- SG200X SDK：`/home/seeed/桌面/sg2002_recamera_emmc`
- 交叉编译器：`/home/seeed/桌面/host-tools/gcc/riscv64-linux-musl-x86_64/bin/riscv64-unknown-linux-musl-gcc`

## 模型转换环境

- Docker 镜像：`sophgo/tpuc_dev:v3.1`
- TPU-MLIR 路径：`/workspace/tpu-mlir`

## 录制环境

- Xvfb 和 ffmpeg 已安装在 `seeed` 上，用于 OpenCV 接收器录制
