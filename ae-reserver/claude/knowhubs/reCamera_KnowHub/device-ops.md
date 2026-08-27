# 设备操作知识

## 设备访问

- Web UI：`http://192.168.42.112`。
- 关键 web 路由：`/#/init`、`/#/workspace`、`/#/network`、`/#/security`、`/#/terminal`、`/#/system`、`/#/power`。
- 原始 Node-RED UI：`http://192.168.42.112:1880`。
- 网络拓扑和各入口 IP（reCamera USB/LAN、seeed-reserver 各网段）：见 `environments/seeed-reserver-recamera/network.md`。
- SSH 用户/密码：见 `environments/seeed-reserver-recamera/credentials.md`；优先使用封装脚本自动尝试，必要时用 `RECAMERA_PASSWORD` 显式指定。
- USB 动态 IP：在 seeed-reserver 上用 `environments/seeed-reserver-recamera/scripts/reserver_usb_ip.sh` 探测，禁止硬编码旧值（迁移过渡期设备可能仍物理连在旧主机上，一律假设经 seeed-reserver 访问）。

## SSH 与文件传输

通过 `seeed-reserver` 跳板访问 reCamera，统一使用封装脚本（自动依次尝试 reCamera 密码，密码见 `environments/seeed-reserver-recamera/credentials.md`，可用 `RECAMERA_PASSWORD` 显式指定）：

```bash
environments/seeed-reserver-recamera/scripts/recamera_ssh.sh 'hostname; whoami'
environments/seeed-reserver-recamera/scripts/recamera_scp_to.sh <local-file> /home/recamera/<demo>/
```

SSH/SCP 的 ProxyCommand、超时参数等细节以脚本实现为准，不要另行硬编码 raw 命令。

## 隧道与截图（Web UI）

对 reCamera Web UI 截图时，通过 `seeed-reserver` 做 SSH 本地转发：

```bash
ssh -N -L 18080:192.168.42.112:80 seeed-reserver   # seeed-reserver 密码见 environments/seeed-reserver-recamera/credentials.md
```

然后在本机用 Playwright 或浏览器打开 `http://127.0.0.1:18080`，截图保存到 `/tmp/recamera-*`。

## OS 和服务

reCamera OS 基于 Buildroot，使用 `/etc/init.d` 下的 SysVinit 脚本。

常见服务：

- `S03node-red`：Node-RED。
- `S91sscma-node`：Node-RED 使用的摄像头/模型服务。
- `S93sscma-supervisor`：监督器和 web/后端服务。
- `S98ttyd`：web 终端。
- `S50sshd`：SSH。

C++ 摄像头 demo 运行前需要停止占用摄像头的服务，服务清单和停/恢复命令见 `knowhubs/reCamera_KnowHub/cpp-runtime.md`。

## 模型知识

reCamera 使用 Sophgo CV181x/SG200X `.cvimodel` 文件。

已知 wiki 模型下载：

- `yolo11n_cv181x_int8.cvimodel`：`https://files.seeedstudio.com/wiki/reCamera/models/yolo11n_cv181x_int8.cvimodel`
- `yolov8n_cv181x_int8.cvimodel`
- `person_cv181x_int8.cvimodel`
- `gender_cv181x_int8.cvimodel`
- `gesture_cv181x_int8.cvimodel`
- `digital_meter_cv181x_int8.cvimodel`
- `yolo11n_drone_int8_sym.cvimodel`

`UDP_Face_Analysis` 使用：

- `yolo-face_mixfp16.cvimodel`
- `age_gender_race_bf16.cvimodel`
- `emotion_bf16.cvimodel`

这些来自 `RobotXTeam/sscma-example-sg200x` 发布 `v1.0.1`，也存在于 seeed-reserver 的仓库中（`/home/seeed0/sscma-example-sg200x`）。

## 证据期望

当被要求"运行"demo 时，收集适合 demo 的证据：

- HTTP demo：响应体加服务器日志。
- UDP 视频 demo：接收的帧保存为 PNG/JPG 加发送器统计。
- Web UI demo：通过本地隧道截图。
- 硬件 demo：命令日志和 exact 硬件/凭据阻塞器（如果有）。
