# 设备操作

直连 reCamera（默认 IP `192.168.42.1`）进行 SSH、文件传输、隧道截图等操作。停止占用摄像头的服务见 `cpp-runtime.md`，接收端录制见 `receiver-recording.md`。

## SSH 到 reCamera

```bash
sshpass -p "$RECAMERA_PASSWORD" ssh -o StrictHostKeyChecking=accept-new \
  recamera@192.168.42.1 'hostname; whoami'
```

或直接 `ssh recamera@192.168.42.1`（交互输入密码）。用 `RECAMERA_PASSWORD` 环境变量传入你自己的设备密码，不要把密码写进脚本或文档。

## 复制文件到 reCamera

```bash
sshpass -p "$RECAMERA_PASSWORD" scp -o StrictHostKeyChecking=accept-new \
  local-file recamera@192.168.42.1:/home/recamera/
```

## UDP 接收端 IP

reCamera 的 UDP demo 需要一个接收端主机 IP 作为参数。在接收端主机上查到它的 IP，传给 reCamera。如果接收端主机和 reCamera 在同一 USB 网络（`192.168.42.0/24`），用接收端在该网段的 IP。reCamera 重启或 USB 重连后该 IP 可能变化，启动发送端前重新读取。

若接收端主机通过 USB 直连 reCamera，查本机在 `192.168.42.0/24` 网段的 IP：

```bash
ip -4 -brief addr | awk '/192[.]168[.]42[.]/{sub(/\/.*$/, "", $3); print $3; exit}'
```

## 隧道与截图

需要访问 reCamera Web UI 截图时，用 SSH 本地转发：

```bash
ssh -N -L 18080:192.168.42.1:80 recamera@192.168.42.1
```

然后浏览器或 Playwright 打开 `http://127.0.0.1:18080`，截图保存到 `/tmp/recamera-*`。

## 停服务与录制

- 停止占用摄像头的服务：见 `cpp-runtime.md`
- 接收端录制（Xvfb + ffmpeg）：见 `receiver-recording.md`
