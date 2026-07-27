# reCamera 概览

## Wiki 范围

本 skill 蒸馏自 reCamera 官方 wiki（`Seeed-Studio/wiki-documents` 的 `Edge/reCamera` 部分，`docusaurus-version` 分支）。原始 wiki markdown 不随 skill 分发，蒸馏后的能力清单见 `capability-map.md`。遇到新 wiki 页面，直接读该页面再套用本 skill 的工作流。

Node-RED 类 demo 暂不作为可运行 recipe，仅在用户明确询问时作背景阅读。

## 设备访问

- USB/直连 IP：`192.168.42.1`
- Web UI：`http://192.168.42.1`，关键路由 `/#/init`、`/#/workspace`、`/#/network`、`/#/security`、`/#/terminal`、`/#/system`、`/#/power`
- 原始 Node-RED UI：`http://192.168.42.1:1880`
- SSH：用户 `recamera`，密码用你自己的设备密码；优先用封装脚本或 `sshpass`，可用 `RECAMERA_PASSWORD` 环境变量显式指定，不要把密码写进脚本或文档。

## OS 和服务

reCamera OS 基于 Buildroot，使用 `/etc/init.d` 下的 SysVinit 脚本。常见服务：

- `S03node-red`：Node-RED
- `S91sscma-node`：Node-RED 使用的摄像头/模型服务
- `S93sscma-supervisor`：监督器和 web/后端服务
- `S98ttyd`：web 终端
- `S50sshd`：SSH

C++ 摄像头 demo 通常需要停止 `S03node-red`、`S91sscma-node`、`S93sscma-supervisor`，以免摄像头被占用（停服务命令见 `cpp-runtime.md`）。

## 模型知识

reCamera 使用 Sophgo CV181x/SG200X `.cvimodel` 文件。官方 wiki 提供的模型下载：

- `yolo11n_cv181x_int8.cvimodel`：`https://files.seeedstudio.com/wiki/reCamera/models/yolo11n_cv181x_int8.cvimodel`
- `yolov8n_cv181x_int8.cvimodel`
- `person_cv181x_int8.cvimodel`
- `gender_cv181x_int8.cvimodel`
- `gesture_cv181x_int8.cvimodel`
- `digital_meter_cv181x_int8.cvimodel`
- `yolo11n_drone_int8_sym.cvimodel`

## 本地开发根目录

部署/编译前确认这些就绪（用环境变量，不要写死绝对路径）：

- `$REPO_ROOT`：demo 源码仓库（如 `sscma-example-sg200x`）
- `$SDK_ROOT`：SG200X SDK
- `$TOOLCHAIN_BIN`：RISC-V musl 交叉工具链 bin 目录

## 证据期望

被要求"运行"demo 时，按 demo 类型收集证据：

- HTTP demo：响应体 + 服务器日志
- UDP 视频 demo：接收端保存的 PNG/JPG 帧 + 发送端统计
- Web UI demo：通过本地隧道截图（见 `device-ops.md`）
- 硬件 demo：命令日志 + 硬件/凭据阻塞说明（如有）
