# reCamera Demo Project Layout

## Default Repository

demo 的源码仓库（编辑和构建的唯一来源）放在本地 Linux 主机：

```text
$REPO_ROOT   # 例如 sscma-example-sg200x
```

所有 reCamera demo 代码和构建都在这台主机上进行；产物部署到 reCamera。

## Demo Directory Rule

所有新的 reCamera C++ demo 和项目实验应创建在：

```text
$REPO_ROOT/solutions/sesg-project/<demo_name>
```

不要把新 demo 放在 `solutions/cosg-project` 或直接放 `solutions/` 下，除非明确要求。已有 demo 可留在原目录，新工作默认 `sesg-project`。

## Expected Demo Shape

新 demo 目录通常包含：

```text
solutions/sesg-project/<demo_name>/
  CMakeLists.txt
  main/
    CMakeLists.txt
    main.cpp
  rootfs/            # 可选运行时服务/包文件
  control/           # 可选包脚本
  README.md          # 可选简短本地 runbook
```

## Demo Completeness

每个 demo 必须是完整可编译的项目，而不是只在本机能跑的碎片。demo 目录必须包含：

- 编译可执行程序所需的全部源文件；
- 构建入口（`CMakeLists.txt`、`build.sh` 或等价物），以 `./script.sh` 调用的脚本需设可执行位；
- 必需的头文件、配置、启动脚本、服务文件、接收端脚本和 README/Wiki 文档；
- 少量关键证据图片/文本供审阅。

demo 不能依赖：

- 未提交的工作区文件；
- 某台机器上的本地绝对路径文件；
- 既未提交也未文档化的隐藏模型/库；
- 未文档化的 CMake 标志或手工环境改动。

按文档构建命令编译后，应产出 reCamera 可运行的 RISC-V musl 可执行程序（`file` 应显示 `RISC-V ... ld-musl-riscv64*`）；配合文档声明的模型和运行时资产部署到 reCamera 后，按文档命令应能复现 demo 行为。

大模型（`.cvimodel`/`.onnx`/`.pth`/`.pt`）、完整证据图片/视频、大型运行时库不要放进源码树，除非有意作为仓库一部分。

## Public Documentation Path Rule

README、Wiki、demo 文档和源码示例注释是写给其他开发者的，不要包含本地绝对路径（如 `/home/<user>/...`）。用可迁移形式：

```text
$REPO_ROOT/solutions/sesg-project/<demo_name>
$SDK_ROOT
$TOOLCHAIN_BIN
$DEMO_DIR
docs/evidence/<file>
```

内部部署报告可记录真实本地路径，但公开 README/Wiki/demo 文档用相对路径、环境变量、占位符或伪命令。
