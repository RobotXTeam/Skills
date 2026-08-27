# 工具链、烧录与部署

## ⚠️ 命名陷阱："fastboot" 不是刷机

`linux-ipc-app-fastboot_server` / `linux-app-fastboot_client` 是 Rockchip 的 **thunder-boot 快速出图**方案（开机即显预览），不是固件烧录；且 reCamera2 BoardConfig 未设 `RK_ENABLE_FASTBOOT`/`RK_FASTBOOT_*`，本产品不构建。

真正的刷写/升级通道有 5 条：

## 1. USB 刷机（maskrom/loader 模式，标准全量刷写）

设备需进 maskrom/loader 模式（Rockchip USB idVendor `0x2207`），主机先装 udev 规则（一次性）：

```bash
sudo cp linux-ipc-tools/linux/Linux_Upgrade_Tool/88-rockusb.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules && sudo service udev restart
```

```bash
# 推荐：rkdownload.sh 从 env.img 的 blkdevparts 驱动全部分区
./rkdownload.sh -d output/image
./rkdownload.sh -f output/image/download.bin output/image/env.img ...   # 指定镜像列表
./rkdownload.sh -e output/image/download.bin    # 全片擦除

# rkflash.sh（linux-ipc-project）按分区动词：
./rkflash.sh boot|uboot|rootfs|userdata|misc|recovery|loader <img>|rd|erase
```

⚠️ `./rkflash.sh all` 对本 SDK **部分失效**：它会 `di -p parameter.txt`，而本 SDK 从不生成 parameter.txt（分区表 100% 在 env.img：blkdevparts + sys_bootargs + sd_parts）。首刷用 `rkdownload.sh -d`，之后按分区用 rkflash.sh 动词。

裸 upgrade_tool：`LD`(列出) `UL download.bin` `DB <loader>` `DI -b boot.img` `WL <BeginSec> [SizeSec] <file>` `EL` `RD` `PL` `UF update.img`。

## 2. 整包 update.img / 产线

```bash
linux-ipc-tools/linux/Linux_Pack_Firmware/mk-update_pack.sh -id rv1126b -i output/image
# afptool -pack + rkImageMaker -RV110F → update.img
upgrade_tool UF update.img
```

或 SDK 内 `./build.sh updateimg` / `./build.sh factory`。GUI：SocToolKit（Linux）、FactoryTool/DriverAssistant（Windows，linux-ipc-tools/windows）。

## 3. 产品 OTA（出厂通道，Web UI 驱动）

- `./build.sh ota` 生成 `update_ota.tar`（`RK_OTA_RESOURCE` 默认只有 **boot.img + rootfs.img** + RK_OTA_update.sh；uboot/idblock/env/misc **不走 OTA**）
- 设备上：Web UI 上传 tar，或后端从 GitHub release 下载（默认 repo `Seeed-Studio/reCamera-Pro-OTA`，可用 `/userdata/config/system/github_url` 覆盖）→ `/userdata/update_ota.tar` → `reboot recovery`
- recovery 分区（10M，tiny busybox ramdisk + RkLunch-recovery.sh）：挂 /userdata（或 FAT SD 卡 mmcblk1/mmcblk2）→ 解包 → RK_OTA_update.sh 对 `/dev/block/by-name/*` 逐分区 `dd` → 清 misc → 写 `/userdata/.ota_update_success` → 重启
- 失败自愈：RK_OTA_erase_misc.sh 把 misc offset 512 清零，避免 recovery 循环
- ⚠️ 每次正常开机 RkLunch.sh post_chk 会**删除** /userdata/update_ota.tar；system_api.cpp 里的 Ota_Dowload/Ota_Sha256 常量是开发占位符

## 4. SD 卡 / U-Boot 脚本升级

- **recovery 模式 SD OTA**（现场升级，推荐）：FAT32 SD 卡根目录放 update_ota.tar → `reboot recovery`
- **U-Boot 控制台脚本**（需串口手敲，recamera2 有 CONFIG_CMD_SCRIPT_UPDATE=y）：`sd_update` / `usb_update` / `tftp_update [-d]`；脚本 tftp_update.txt/sd_update.txt 由 `scripts/mk-tftp_sd_update.sh` 生成到 output/image，不自动运行

## 5. 开发者单文件更新（scp）

```bash
# sshd 默认关闭！先在设备上：
touch /userdata/config/system/.ssh_exit     # S50sshd 见到此文件才启动 sshd
scp out/bin/rkipc root@<ip>:/oem/usr/bin/rkipc && ssh root@<ip> killall rkipc
```

⚠️ **/oem 每次刷 rootfs 都会被重置**——scp 推的改动会丢；要持久化放 /userdata（rkipc 已用 /userdata/config/rkipc.ini 覆盖出厂默认）。替代通道：ttyd Web 终端（7681）、vsftpd（rkipc 的 ftp.c 管理，配置 /userdata/config/system/vsftpd.conf）。

### 设备上关键路径速查

| 路径 | 内容 |
|---|---|
| /oem/usr/bin/rkipc、RkLunch.sh | 主进程 + 启动编排 |
| /oem/usr/lib | app+media 库 |
| /oem/usr/www | Web SPA + cgi-bin/entry.cgi |
| /oem/usr/etc/init.d/S??* | 产品 init 脚本（nginx S56、fcgiwrap S55、services S40/S49…） |
| /oem/usr/share/{iqfiles,model,system} | ISP 调优 / RKLLM 模型 / passwd 种子 |
| /oem/usr/ko | insmod_ko.sh + .ko |
| /userdata/config/{rkipc.ini,record,notify.json,model,system} | 持久配置 |
| /etc/ota_version、/userdata/.ota_update_success | OTA 状态 |

分区：`env,idblock,uboot,misc,recovery,boot,rootfs(mmcblk0p7),userdata`（p1..p8）。misc 标志工具：`rk_ota --misc=factory_reset|display`、手动清：`dd if=/dev/zero of=/dev/block/by-name/misc bs=32 count=1 seek=512`。A/B 槽机制已编译但 recamera2 上无效（单槽）。

## 工具类子仓库一览

| 平铺目录 | 挂载点 | 作用 |
|---|---|---|
| linux-ipc-tools | `tools/` | 🔒 预编译刷写/打包工具：Linux_Upgrade_Tool(upgrade_tool, rkdownload.sh, 88-rockusb.rules)、Linux_Pack_Firmware(afptool, rkImageMaker, mk-update_pack.sh)、SocToolKit GUI、windows/ 产线工具 |
| linux-ipc-tools-toolchain-aarch64-rockchip1240-linux-gnu | tools/linux/toolchain/aarch64-… | **GCC 12.4.0 aarch64 交叉编译器**（reCamera Pro 主工具链）；`source env_install_toolchain.sh` 装入 PATH（会写 ~/.bashrc） |
| linux-ipc-tools-toolchain-arm-rockchip1240-linux-gnueabihf | tools/linux/toolchain/arm-… | 32 位 armhf 编译器（RK_APP_ARCH_TYPE=arm 时用，加 Thumb-2 标志；kernel/media 32 位路径用） |
| linux-ipc-tools-Rockchip_AVS_tool | tools/windows/Rockchip_AVS_tool | 多摄标定工具，**只有 Windows 预编译**（rkAVS_calibTool.exe）；demo CMakeLists 硬编码了开发者本机 OpenCV 路径，开箱编不了 |
| linux-ipc-app-wifi_app | app/wifi_app | WiFi/BT 栈：wpa_supplicant/hostapd 源码编 + rk96x SDK（rkwifi_server）。reCamera2 启用（RK_ENABLE_WIFI=y, AP6XXX/AP6256）。设备端 CLI：`rkwifi_server scan|connect <ssid> [psk]|disconnect|is_connected|close`；配置持久在 /userdata/rk96x/conf/ |
| linux-ipc-app-fastboot_server | app/fastboot_server | thunder-boot 预览服务端（不是刷机！）；recamera2 未启用 |
| linux-app-fastboot_client | app/fastboot_client | thunder-boot 客户端/demo（rockiva+RKNN 变体）；未启用 |
| linux-external-uvc_app | app/uvc_app_tiny | UVC gadget（reCamera 作为 USB 摄像头）：rk_mpi_uvc + configfs dwc3 + libeptz/libfaceDet。参考模式，非默认路径。`rk_mpi_uvc -c /userdata/rkuvc.ini -a <iqfiles>` |
| linux-ipc-app-testdemo | app/testdemo | 参考 demo：yoloworld_demo（RKNN+DeepSort+LVGL）、low_delay_net_display（低延迟投屏 TX/RX）；按 RK_APP_TYPE=YOLOWORLD_DEMO/PROJECTOR_DEMO 门控，recamera2 未启用 |

## 关键坑

1. 平铺检出不能直接跑 build.sh/rkflash.sh/rkdownload.sh 的相对路径假设（需嵌套树 + output/image）。
2. rkflash.sh all 的 parameter.txt 步骤会失败——用 rkdownload.sh -d。
3. OTA 只带 boot+rootfs；sshd 默认关；/oem 随 rootfs 重置。
4. update_ota.tar / RK_OTA_update.sh 每次 `./build.sh ota|firmware` 重新生成——别手改 output/image 里的生成脚本（生成器在 build.sh 的 build_ota()）。
5. fastboot ≠ flashing；A/B 槽在 recamera2 上无效。
