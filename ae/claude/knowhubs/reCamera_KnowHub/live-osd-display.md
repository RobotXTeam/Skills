# Live OSD display on the local PC (real-time preview capability)

> 把"本机实时 OSD 显示"作为 demo 用户审核的一等能力：审核 = 录制证据 **+** 在本地 PC 上实时显示带 OSD 的画面。
> 任何 reCamera demo 只要往一个目录持续写 `frame_NNNN.jpg`（带检测框/掩码/告警横幅的标注帧），就能用这套方法在本机弹一个流畅的实时窗口。

## 为什么用 UDP 直推，不用 HTTP MJPEG / 浏览器

实测同一台 reCamera（seg 模型，摄像头 ~2fps 上限）三种显示法到本机的有效帧率：

| 方法 | 本机收到帧率 | 丢帧 | 说明 |
|---|---|---|---|
| HTTP multipart MJPEG + seeed TCP 中继 | **~0.4 fps** | ~75% | mjpeg_server **轮询**最新 jpg（不是推），每 tick glob+stat 全目录，TCP sendall 背压 |
| HTTP multipart MJPEG 直连设备 LAN | ~0.6 fps | ~60% | 同上，瓶颈在服务端轮询+背压，不是网络 |
| **UDP fire-and-forget 直推** | **~2 fps（≈摄像头上限）** | ~0 | 推不轮询、无背压、keep-latest |

UDP 把摄像头产出的帧几乎 100% 送到屏幕。卡顿只剩**摄像头本身**的天花板（模型推理+后处理+JPEG 写盘的耗时），这是 demo/模型决定的，不是显示决定的。

UDP 适合本场景的理由：链路可靠（LAN/USB，丢包≈0）、丢一帧无所谓（实时预览只关心最新帧）、无 TCP 队头阻塞。大 JPEG（~100KB）会被拆成 ≤1390 字节的小数据包，**小包还能穿过会吞大 TCP 段的 PMTU 黑洞**（见下）。

## 拓扑与路径选择（决策树）

```
1. 设备和本机是否同一个 L2 子网？
   在设备上: ip route get <本机IP>
   - 显示 "dev <iface> src <同子网IP>" 且无 "via <gateway>"  => 同子网, 走【直推】
   - 显示 "via <gateway>"                                      => 路由路径, 多半有 PMTU 黑洞, 走【中继】
2. 【直推】(最优, 一跳): 设备 udp_sender -> 本机:9200 ; 本机 udp_viewer :9200
3.【中继】(fallback): 设备 udp_sender -> seeed USB IP:9100 ; seeed udp_relay 9100->本机:9200 ; 本机 udp_viewer :9200
4.【SSH 隧道桥】(PC 与 seeed 之间只有单向 NAT/ssh 可达时): 设备 sender -> seeed USB:9100;
   seeed udp2tcp(UDP:9100 -> 长度前缀帧写 TCP 127.0.0.1:9101); 本机 `ssh -L 9101:127.0.0.1:9101 seeed`;
   本机 tcp2udp(读隧道帧 -> sendto 127.0.0.1:9200); viewer 不变。 Linkbit 等单向打通环境见见 2026-08 实例。
```

reCamera 常见情况：USB 连 seeed（192.168.42.x，只能经 seeed 中继）；同时很多 reCamera 还有 wifi/LAN 口在你本机同子网（如 192.168.2.x）——优先用同子网直推。

## 关键坑（必须知道）

1. **只发完整 JPEG**：demo 边写 `frame_NNNN.jpg` 边被 sender 读到 = 截断帧（文件大小是 4096 的整倍数是典型信号）。sender 必须**校验 SOI(`\xff\xd8`)+EOI(`\xff\xd9`) 都在**才发；不完整则**不推进 last_name**，下一 tick 重试同一文件，等它写完。否则丢大半帧 + 解码失败。
2. **PMTU 黑洞**：设备经网关路由到本机时，TCP 三次握手能通（小包），但大段数据被丢（"TCP connects but data doesn't flow"）。表现：直连 LAN IP 的 8123 端口 curl 能连上但拿不到 body。**小 UDP 包(≤1400) 能穿过去**，但大 TCP 段不行——这是用 UDP 而非 TCP 直连的另一个理由；或走 seeed USB 中继绕开。
3. **别 `kill -9` 摄像头进程**：会让内核 VPSS/ISP 句柄泄漏，下次 `CVI_VPSS_CreateGrp(grp:0) failed`，摄像头起不来。要停摄像头用正常 SIGTERM（demo 有 signal_handler 优雅退出）；已经泄漏了只能**重启 reCamera** 清空 VPSS。`kill -9` 只留给卡死的子进程（aplay 等）。
4. **mjpeg_server 读 root 写的帧要 root 跑**：demo 用 sudo 跑摄像头，写的帧是 root 600 权限，recamera 用户读不了 → 流只有 HTTP 头没有 body。任何读帧的服务（mjpeg_server / udp_sender）都要 sudo 跑。
5. **本机 cv2.VideoCapture 对 multipart MJPEG 不稳定**：会 `opened False` / 30s 超时。别用它做消费端；用 `urllib` 手解 multipart 或直接用本能力的 UDP viewer。

## 脚本（已随 skill 提供）

- `environments/seeed-recamera/scripts/udp_sender.py` — 设备侧：监控 demo 输出目录，分片直推。
- `environments/seeed-recamera/scripts/udp_viewer.py` — 本机侧：重组 + keep-latest + imdecode + imshow 窗口。
- `environments/seeed-recamera/scripts/udp_relay.py` — seeed 侧 fallback：UDP 数据包透传（设备经 USB 到 seeed，再到本机）。

## 起一条实时 OSD 的标准操作

设：demo 在设备 `/home/recamera/<demo>/live/` 持续写 `frame_NNNN.jpg`；本机 LAN IP `192.168.2.101`，设备同子网 IP `192.168.2.156`。

```bash
# 1) 本机起 viewer（绑 :9200，弹窗）
DISPLAY=:0 python3 udp_viewer.py 9200 "reCamera <demo> live OSD"

# 2) 设备起 sender 直推本机（root，读 root 写的帧）
sudo python3 udp_sender.py /home/recamera/<demo>/live 192.168.2.101 9200
#   -> 日志每 2s 打 "sent N frames, X fps, last_size=..."；X 应≈摄像头产出率
#   -> 本机日志每 2s 打 "pkts=.. complete=.."，complete≈sent 即零丢包
```

如果设备只能经 seeed USB（不同子网）：

```bash
# seeed 起中继
python3 udp_relay.py 9100 192.168.2.101 9200   # seeed USB IP 用 seeed_usb_ip.sh 查
# 设备 sender 指向 seeed USB IP:9100
sudo python3 udp_sender.py /home/recamera/<demo>/live <seeed_usb_ip> 9100
# 本机 viewer 不变
```

## 协议（10 字节头，大端）

```
magic u16=0xB0C0 | frame_id u16 | frag_idx u16 | frag_count u16 | frag_len u16 | payload(<=1390)
```
同一 frame_id 的所有 frag 到齐(`len==frag_count`)即重组（按 idx 排序拼接）；新 frame_id 到来时丢弃未拼完的旧帧（keep-latest）。frame_id u16 会回绕，比较时按"更大才算新"。

## 调优

- 想更流畅：天花板是摄像头产帧率（模型推理+后处理+JPEG 写盘）。换更快的模型（检测比分割快）、降分辨率、或让 demo 在实时路径上少做后处理。显示侧已经跑满摄像头。
- sender 的 `MTU=1400` 可按路径调小（PMTU 黑洞路径尤其要小）。
- 帧太大（>100KB）→ 数据包多，丢一个就废整帧。可在 sender 端 `cv2.imencode` 降质量/降分辨率再分片（设备需有 opencv）；本能力的 sender 默认发原始 jpg 字节，不依赖 opencv。

## 在 demo-output 工作流里的位置

`workflows/demo-output.md` 的用户审核（步骤 12）应包含：
- **本机实时 OSD 显示**（本能力）：录最终证据前，先在本机看实时画面，确认 OSD 框/掩码/告警横幅正确、阈值合适。
- **录制证据**：确认实时效果 OK 后再录视频/截图。

两步结合 = 既看实时、又留证据。
