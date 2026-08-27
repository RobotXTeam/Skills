# reCamera Pro 核心应用层与运行时架构

> 本组是产品开发的主战场。数据来源：2026-08-14 对仓库与启动脚本的实际测绘。

## 进程拓扑总览

设备运行 **busybox init（/etc/init.d/S?? 风格），无 systemd，无 D-Bus**。一切 IPC 都是 Unix 域套接字 + nginx 反代。

```
                 ┌─────────────────────────────────────────────┐
                 │  rkipc（= recamera2-ipc，产品主进程）          │
                 │  ISP + 媒体管线 + 录像(vigil,进程内) + RKNN 推理 │
                 └───┬───────────────┬───────────────┬─────────┘
        控制套接字      │    protobuf 推理 │        帧入队(进程内)
       /var/tmp/rkipc │    /var/tmp/notify│        lib-vigil
              ┌───────┴──────┐   ┌────────┴───────┐
              │ entry.cgi     │   │ recamera2-notify│ → MQTT/HTTP/WS(8123)/UART
              │ (web backend, │   │ (Python 3.11)   │      UART→/dev/shm/vserial1.sock
              │  FastCGI)     │   └─────────────────┘            └→ tmir → /dev/ttyS4
              │ binonvif      │
              │ (ONVIF gSOAP) │
              └───────────────┘
  services 守护进程（Rust）：gmgr(GPIO) skt2ws(事件→WS) tmir(串口镜像) rcisd(Intellisense)
  全部挂在 /dev/shm/*.sock，由 nginx 反代
  其他：nginx+fcgiwrap、go2rtc(1984)、ttyd(7681)、websocket_log.py(WS 8765)、watchdog
```

## 启动顺序

ROM → download.bin/idblock(SPL+DDR) → U-Boot → boot.img FIT（Linux 6.1 + rv1126b-recamera2-v1.dts + DTBO）→ busybox init → **/oem/usr/bin/RkLunch.sh**（产品启动编排器，由 recamera2-ipc 的 CMake 安装）：

1. **post_chk()**：等 /userdata 挂载 → `/oem/usr/ko/insmod_ko.sh`（模块顺序：rk_aoa, rk_dvbm, otp_eeprom, sensor .ko(sc450ai/sc850sl...), videobuf2*, video_rkcif/rkaiisp/rkisp/rkvpss/rkavsp, csi2 dphy, rga3, kmpp, rknpu, snd-soc-*, motor.ko, rockit_osal/base/rockit；后台 `insmod_wifi.sh &` AP6256/bcmdhd）→ lo/eth0 起来 → 从 /oem/usr/share/ 种子化 /userdata/config 和 /userdata/config/model → 按 /proc/rkisp-vir0 分辨率选 rkipc.ini 模板（2688x1520/3200x1800/3840x2160）→ 生成自签 SSL 证书 → iptables 门控 5554
2. **rcS 0 49**（/oem/usr/etc/init.d/S00–S49）：S00board-id、S10log(websocket_log.py: UDP 5140→WS 8765)、S40rkaiq_3A（3A server）、S40gmgr、S40skt2ws、S40tmir、S49rcisd、S49notify
3. **`rkipc -a /oem/usr/share/iqfiles &`**
4. **rcS 50 99**：S50onvif（仅当 rkipc.ini `[video.0.onvif] enable=1`）、S50ttyd(7681)、S55fcgiwrap(`/run/fcgiwrap.sock`)、S56nginx、S99led/inotify_passwd/factorykey

注意：rootfs 级脚本（S10udev、S15watchdog `watchdog -T 30 -t 15 /dev/watchdog`、S50sshd、S50usbdevice、S90rkota）在 /etc/init.d；产品脚本在 **/oem/usr/etc/init.d**（`/oem` 是 rootfs 内的目录——reCamera2 没有独立 oem 分区，`RK_BUILD_APP_TO_OEM_PARTITION=n`）。调用 RkLunch.sh 的 S99RkLunch 钩子在 buildroot rootfs 包里（平铺检出中不存在）。

## rkipc main() 初始化顺序

`linux-ipc-app-recamera2-ipc/src/rv1126b_ipc/main.c`：

```
rk_param_init(/userdata/config/rkipc.ini) → battery_charge_thread(sysfs dc/poe/typec)
→ RK_wifi_enable → rk_isp_init(rkaiq uapi2: enumStaticMetasByPhyId → sysctl_init(sensor, iqdir))
→ RK_MPI_SYS_Init()(rockit) → rc_notify_init() → vg_service_init(VG_CONFIG_DEFAULT)  [vigil]
→ rkipc_audio_init → rk_video_init(VI→GDC→VPSS→VENC 线程)
→ rkipc_server_init(/var/tmp/rkipc, FunMap 表约 276 个 rk_* 命令) → key 线程 → network/system init
→ 可选 UVC/UAC（rkipc_usb_config.sh）→ NTP 线程 → 主循环
```

## 媒体数据流（src/rv1126b_ipc/video/video.c）

```
sc450ai(IR: sc850sl) → CSI2 DPHY + rkcif + rkisp(ISP 3.5, rkaiq 进程内)
→ RK_MPI VI(DMABUF, 可选 COMPRESS_RFBC) → SYS_Bind(VI→GDC→VPSS)
→ VPSS: chn0 主码流 3840x2160 / chn1 子码流 / chn2 NPU / chn3 VO+JPEG
→ VENC0 H.264/H.265 + VENC1 + JPEG
→ rkipc_thread_venc_0 每帧分发：
   ├─ rkipc_rtsp_write_video_frame（RTSP）
   ├─ gst_mpegts_write（gstreamer MPEGTS）
   ├─ gst_rtmp_write（RTMP）
   ├─ uvc_read_camera_buffer（UVC gadget）
   └─ vg_media_enqueue_video_frame（vigil 录像，带 key_frame 标志）
```

RTSP 配置变更时 video.c 调 `/oem/usr/etc/init.d/S50go2rtc restart`（go2rtc 提供 WebRTC，端口 1984；脚本/二进制不在本检出中，由 RK_APP_RECAMERA_GO2RTC 打包）。

## AI 推理链路

```
rc_infer(RKNN: rknn_init) ← 模型来自 /userdata/config/model/<ext>/<name>（rc_model, RC_MODEL_BASE_DIR）
→ inference.proto(pb-c) 结果 → rc_notify → /var/tmp/notify → recamera2-notify(Python)
→ TemplateFormatter → MQTT / HTTP / WebSocket(0.0.0.0:8123, nginx 代理 /ws/inference/results)
                    / UART(写 /dev/shm/vserial1.sock → tmir 镜像 /dev/ttyS4)
```

仓库自带 RKNN 模型（recamera2-ipc/model/rknn）：`nanodet-plus-m_416.rknn`、`yolox_s.rknn`。

## 录像引擎 lib-vigil（reCamera 的特色功能）

**vigil 是 C++20 库，在 rkipc 进程内运行**（add_subdirectory 进 recamera2-ipc/common/vigil），不是独立进程。

- C API 边界：`include/vigil_capi.h` + `vigil_ctypes.h`（`vg_service_init` / `vg_media_enqueue_video_frame`），保持结构体跨 C/C++ 边界稳定
- 规则触发源（vigil/rules.hpp 枚举，写规则 JSON 用这些名字）：**INFERENCE、INFERENCE_SET、TIMER、GPIO、TTY、SCHEDULE、HTTP、ALWAYS_ON、SED**（SED=声音事件检测，输入来自 `/dev/shm/acousticslabd-result.sock`）
- 配置根：`/userdata/config/record`；录像产物 MP4/JPG/RAW 写入 /userdata（`/dev/mmcblk0p8`，目录 `DCIM/100RECAM`）或 SD；经 rkmuxer 写 MP4（vigil_device_support/src/media.c）
- relay 发布：`/var/www/rc_relay`，HTTP 访问路径 `/storage/relay/`（nginx rc_relay.conf alias）
- 规则事件上报：`/dev/shm/skt2ws-record-events.sock` → skt2ws → 浏览器 WS + rcisd
- HTTP API（rule/config、rule/info、rule/schedule/config、storage/relay）文档：`linux-ipc-app-lib-vigil/docs/minimal-http-api.md`

## Web/API 运行时

- nginx 服务 React SPA（`/oem/usr/www`）；`/cgi-bin/*` → fcgiwrap → **entry.cgi**（recamera_web_backend，C++14 FastCGI，无长驻 HTTP 守护；`rest_api.cpp ApiEntry::run` 注册路由组：network/video/audio/image/system/osd/event/peripherals/model/notify/ftp/web/record(vigil)/config）
- JWT 门控：`/_jwt_verify` 子请求（secret 在 `/userdata/config/system/jwt_secret.key`；localhost 经 geo $is_local_request 旁路）
- **WS/WebRTC 不走 entry.cgi**，是 nginx 直连反代：日志→8765、终端→7681、推理→8123、go2rtc→1984、services→/dev/shm unix 代理（svc_gmgr/svc_skt2ws/svc_tmir/svc_rcisd.conf）
- SenseCraft 云反代：sensecraft.conf（sensecraft-hmi-api.seeed.cc 等）
- nginx 配置母本：`linux-app-web-recamera_web_backend/ipcweb-env-rv1126b/etc/nginx/`

## 本组子仓库一览

| 平铺目录 | 语言 | 作用与要点 |
|---|---|---|
| **linux-ipc-app-recamera2-ipc** | C/C++ | **产品主进程**（二进制名仍叫 rkipc，CMake project 名 rkipc，`-DCOMPILE_FOR_RV1126B=ON`）。rkipc 的 Seeed 产品化 fork：多了 vigil、rc_infer、rc_model、rc_notify、gstreamer、vigil_device_support。构建挂载点 `project/app/recamera_ipc`。Makefile 会先重建 thirdlibs/rkfsmk/nginx。关键文件：`src/rv1126b_ipc/{main.c, video/video.c, RkLunch.sh, rkipc-3840x2160.ini}`、`common/socket_server/{socket.h(CS_PATH=/var/tmp/rkipc), server.c(FunMap 命令表)}` |
| **linux-ipc-app-lib-vigil** | C++20 | 规则式录像/事件引擎。产品内不单独编译，被 recamera2-ipc add_subdirectory。依赖 protobuf、libblkid、nlohmann/json、jemalloc（3rdparty 自带） |
| **linux-ipc-app-recamera2-services** | Rust(+C/TS) | 守护进程套件：gmgr(GPIO,/dev/gpiochip3)、skt2ws(vigil 事件→WS)、tmir(/dev/ttyS4→vserial0/1.sock)、rcisd(Intellisense 事件队列)、led、key_factory、inotify_passwd；扩展：acousticslabd(声音分类)、alpkg(包安装)。Rust 用 `cross`(Docker) 交叉编译，arm64 时目标 aarch64-unknown-linux-gnu。init 脚本 S40gmgr/S40skt2ws/S40tmir/S49rcisd/S99* |
| **linux-ipc-app-recamera2-notify** | Python 3.11 | 推理结果通知服务器。监听 `/var/tmp/notify`，fan-out 到 MQTT/HTTP/UART/WS(8123)。纯 Python 安装到 `/usr/lib/python3.11/site-packages/recamera_notify/`。依赖 paho-mqtt、websockets、protobuf |
| **linux-ipc-app-recamera2-onvif** | C/C++(gSOAP) | ONVIF 服务器 binonvif（发现/profiles/RTSP URI/WSSE）。自带 socket_client 连 /var/tmp/rkipc。装到 /oem/usr/bin/binonvif。README 是 GitLab 占位符，不可信 |
| **linux-ipc-app-recamera2-utils** | C/Python/sh | 产测工具：SN_TOOL(/dev/vendor_storage 读写 SN/MAC)、npu_stress、EMC/RF/BT/IMU 测试。装到 /usr/share/recamera_utils。⚠️ BoardConfig 里该开关被注释，默认不构建 |
| linux-ipc-app-rkipc | C/C++ | rkipc **当前通用 fork**（有 rv1126b_multi_ipc，无 tuya）。由 mk_rkipc 构建，面向 RKIPC_RV1126B 通用 IPC，不是 reCamera Pro 的活跃目标 |
| linux-app-rkipc | C/C++ | **遗留 fork**（有 tuya_ipc、battery_ipc 变体，无 multi_ipc）。不要与上面两个混改 |
| linux-ipc-project-app-mk_rkipc | Make | rkipc 的构建包装（project/app/rkipc），按 RK_APP_TYPE 映射 -DCOMPILE_FOR_* |
| linux-ipc-app-component-prerecord | 预编译 | Rockchip 预录组件。**只有 rv1103b 的 .so，rv1126b 没有 → 对本产品无效** |
| linux-ipc-app-component-rockauto(+_mk) | 预编译 | 车载视觉库（CVR/ADAS/sentry，librockauto.so + 模型 + rkauth 授权工具）。reCamera2 默认未启用 |

## ⚠️ 三个 rkipc 树，别改错

1. `linux-ipc-app-recamera2-ipc` — **产品用这个**（vigil/rc_infer/gstreamer）
2. `linux-ipc-app-rkipc` — 通用 fork（rv1126b_multi_ipc），mk_rkipc 构建
3. `linux-app-rkipc` — 遗留（tuya/battery 变体）

## 关键坑

1. **没有 D-Bus、没有 systemd**——找 dbus/systemctl 是白费；全部是 busybox init + unix socket + nginx。
2. **没有 vigil 进程、没有 vigil 看门狗**——vigil 是 rkipc 进程内的库；唯一看门狗是 busybox 的（S15watchdog）。
3. **MCU 在 reCamera Pro 上不参与运行**：BoardConfig 无 RK_ENABLE_AMP、分区表无 amp、DTS 无 rv1126b-amp.dtsi。电池/充电是 Linux 侧 sysfs 轮询（rkipc battery_charge_thread）。RT-Thread 那套只属于 AMP 板卡配置。
4. 套接字路径是硬编码常量：`/var/tmp/rkipc`（控制）、`/var/tmp/notify`（推理）、`/dev/shm/*`（services/事件）——客户端服务端必须同步改。
5. protobuf 重复符号：recamera2-ipc 的 CMakeLists 显式**移除** `common/rc_notify/inference.pb-c.c`（与 rc_infer 冲突）。重新生成 inference.proto 绑定时记住这一点。
6. entry.cgi 是 fcgiwrap 每请求拉起的 FastCGI；状态都在磁盘或 rkipc 里。
7. S55fcgiwrap umask 000 + socket chmod a+wx，脚本里自带 "TODO: Fix this security issue"。
8. 前端是 CRA（react-scripts）不是 Vite；dev 模式 axios 把 :3000 重写到 :8000（期望 FastAPI mock），生产用相对路径 `/cgi-bin/entry.cgi/`。
9. vigil 录像的 HTTP 路径是 `/storage/relay/` → `/var/www/rc_relay`（不是 vg_relay）。
10. 恢复出厂：`/userdata/config_tar/config_factory`（RkLunch.sh 会把 /userdata/config 软链过去）。

## 设备上的配置热区（改配置去哪里）

| 路径 | 内容 |
|---|---|
| `/userdata/config/rkipc.ini` | 主配置（[video.0..2]/[audio.*]/[network.*]/[isp.0.*]/[video.0.rtsp/rtmp/onvif]）；模板 `rkipc-3840x2160.ini` |
| `/userdata/config/record/*` | vigil 规则/调度/存储 |
| `/userdata/config/notify.json` | notify fan-out 配置 |
| `/userdata/config/system/serial_port.json` | tmir 串口配置 |
| `/userdata/config/model/` | RKNN/RKLLM 模型目录 |
| `/oem/usr/share/iqfiles` | ISP 调优文件（rkaiq IQ JSON） |

## 单组件重建速查

```bash
make -C project/app/recamera_ipc          # 主 app（含 vigil）
make -C project/app/recamera_services     # Rust services（需 cross+Docker）
make -C project/app/recamera_notify       # Python，无编译
make -C project/app/recamera_onvif
make -C project/app/recamera_web          # Web 栈（见 web-ui.md）
./build.sh firmware                       # 重新打包镜像
```
