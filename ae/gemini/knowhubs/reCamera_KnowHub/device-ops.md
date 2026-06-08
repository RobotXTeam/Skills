# 设备操作知识

## 设备访问

- USB/直接 IP：`192.168.42.1`。
- Web UI：`http://192.168.42.1`。
- 关键 web 路由：`/#/init`、`/#/workspace`、`/#/network`、`/#/security`、`/#/terminal`、`/#/system`、`/#/power`。
- 原始 Node-RED UI：`http://192.168.42.1:1880`。
- SSH 用户/密码：`recamera` / `recamera.1`。
- Steven 的桥接主机：`seeed`，Tailscale `100.76.45.91`，LAN `192.168.4.7`，密码 `0`。

## OS 和服务

reCamera OS 基于 Buildroot，使用 `/etc/init.d` 下的 SysVinit 脚本。

常见服务：

- `S03node-red`：Node-RED。
- `S91sscma-node`：Node-RED 使用的摄像头/模型服务。
- `S93sscma-supervisor`：监督器和 web/后端服务。
- `S98ttyd`：web 终端。
- `S50sshd`：SSH。

C++ 摄像头 demo 通常需要停止 `S03node-red`、`S91sscma-node` 和 `S93sscma-supervisor`，以便摄像头不被占用。

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

这些来自 `RobotXTeam/sscma-example-sg200x` 发布 `v1.0.1`，也存在于 Steven 的本地仓库中。

## 证据期望

当被要求"运行"demo 时，收集适合 demo 的证据：

- HTTP demo：响应体加服务器日志。
- UDP 视频 demo：接收的帧保存为 PNG/JPG 加发送器统计。
- Web UI demo：通过本地隧道截图。
- 硬件 demo：命令日志和 exact 硬件/凭据阻塞器（如果有）。
