---
name: procode
description: Seeed reCamera Pro (RV1126B Rockchip SDK) 完整代码库的架构地图与开发指引。当需要了解、查阅、修改、编译或部署 reCamera Pro / reCamera v2 的代码时加载本 skill：包括 83 个子仓库的目录映射、build.sh 构建系统、rkipc/recamera2-ipc 主应用、vigil 录像引擎、React+C++ Web UI、媒体管线(rockit/MPP/rkaiq)、ISP 调优、RKNN/RKNN-LLM、RT-Thread MCU、BoardConfig、烧录与 OTA。Triggers on: reCamera Pro, recamera v2, RV1126B, rockchip SDK, rkipc, vigil, recamera2-ipc, entry.cgi, RkLunch, BoardConfig_Recamera2, build.sh lunch, web backend, REST API, FastCGI, DTS, device tree, sensor, kernel, boot.img.
---

# procode — reCamera Pro (RV1126B) 代码库地图

本 skill 是 **Seeed reCamera Pro** 完整 SDK 代码库的导航与开发指引。其他 agent 在接触这个仓库前应先读本 skill，再按需读 references/ 对应分篇。

## 仓库基本信息

- **路径**：`/home/steven/work/RV1126B/仓库/完整的/rockchip`（路径含中文，shell 命令**务必加引号**）
- **规模**：21GB，83 个平铺的 git 子仓库（git-repo 多仓工作区，remote 为 Seeed 私有 GitLab，URL 内嵌 oauth2 token——**勿把 git remote 打进日志**）
- **产品**：Seeed reCamera Pro（= reCamera v2），芯片 Rockchip RV1126B（A53 Linux 核 + RISC-V HPMCU + NPU）
- **版本线**：dev manifest 跟 main 分支；release 钉版，最新 v1.1.2（RK_OTA_VERSION V1.1.2）
- **软件形态**：Linux 6.1.157 + buildroot(busybox init) + Rockchip IPC SDK + Seeed 产品应用层

## 一句话架构

rkipc（recamera2-ipc fork）是唯一中枢进程：sensor(sc450ai)→rkaiq ISP→rockit/MPP 编码→RTSP/录像(vigil 进程内)/RKNN 推理；周边是 Python notify、Rust services、ONVIF、React+C++(FastCGI) Web UI，全部用 **Unix 域套接字 + nginx** 连接——**没有 systemd，没有 D-Bus**。

## ⚠️ 三个必读前提

1. **平铺检出不能直接编译**：build.sh 期望 `rv1126b-manifests/tree.txt` 的嵌套树（project/cfg、project/app/…、sysdrv/source/…）。要编译需 repo sync 或按 tree.txt 组装符号链接。`./build.sh lunch` 在当前平铺树会报 "No available Board Config"。
2. **三个 rkipc 树别改错**：产品用 `linux-ipc-app-recamera2-ipc`（有 vigil）；`linux-ipc-app-rkipc` 是通用 fork；`linux-app-rkipc` 是遗留（tuya/battery）。
3. **大量闭源预编译**：rockit MPI 核心、IVA、AVS、rkfsmk、OP-TEE、RKNN 运行时都是二进制 drop——只能链接/替换，不能重建。可编辑主力：recamera2-* 应用、web 栈、rk-mpp、rga、rkadk、rkaiq、kernel、u-boot。

## 路由表（按需读 references/）

| 你要做的事 | 读哪篇 |
|---|---|
| 找某个目录是什么、挂到 SDK 哪里 | `references/directory-map.md`（83 目录全映射） |
| 理解整体编译、BoardConfig、单组件重建、产物镜像 | `references/build.md` |
| 改内核/DTS/U-Boot/驱动模块/启动链 | `references/sysdrv-bsp.md` |
| 改媒体管线、ISP 调优、用 rockit/MPP/RGA API | `references/media-pipeline.md` |
| 改主应用 rkipc、vigil 录像、notify/services/onvif、设备运行时 | `references/recamera2-apps.md` |
| 改 Web 前端(React)/后端(entry.cgi)/nginx、本地联调 | `references/web-ui.md` |
| RKNN/RKNN-LLM 推理、模型部署、NPU | `references/ai-npu.md` |
| RT-Thread MCU/AMP（reCamera Pro 未启用，先读结论） | `references/rtos-mcu.md` |
| BoardConfig 家族、AOV/CVR 参考应用、RK_APP_TYPE 门控 | `references/aov-cvr-configs.md` |
| 烧录/OTA/scp 单文件部署/WiFi/UVC/工具链 | `references/tools-flash.md` |
| 找官方文档、发版流程（lock_manifest） | `references/docs.md` |

## 快速事实卡

- **产品 BoardConfig**：`linux-ipc-demo_cfg_recamera2/BoardConfig-EMMC-RK801-RV1126B_V1-IPC_64BIT.mk`（arm64，RK_APP_TYPE=RKIPC_RV1126B_RECAMERA2，DTS rv1126b-recamera2-v1.dts）
- **主工具链**：aarch64-rockchip1240-linux-gnu（GCC 12.4.0）——产品 64BIT 配置下**内核、media、应用全部 aarch64**（ARCH=arm64 由 RK_TOOLCHAIN_CROSS 推导）；arm-rockchip1240-linux-gnueabihf（32 位）仅用于 32 位参考配置
- **构建入口**（嵌套树中）：`./build.sh lunch` → `./build.sh`（allsave）；单 app `make -C project/app/<dir>` + `./build.sh firmware` 重打包
- **设备关键路径**：主进程 /oem/usr/bin/rkipc；启动 /oem/usr/bin/RkLunch.sh；配置 /userdata/config/{rkipc.ini,record,notify.json,model}；Web /oem/usr/www；IQ /oem/usr/share/iqfiles
- **关键套接字**：/var/tmp/rkipc（控制，FunMap 表约 276 个 rk_* 命令）、/var/tmp/notify（推理 protobuf）、/dev/shm/*（services/事件）
- **端口**：80(nginx) 8123(推理WS) 8765(日志WS) 7681(ttyd) 1984(go2rtc WebRTC) 5554(RTSP，即 RkLunch.sh iptables 门控的端口)
- **刷机**：maskrom + `rkdownload.sh -d output/image`（rkflash.sh all 的 parameter.txt 步骤已失效）；**ssh 默认关**（需 touch /userdata/config/system/.ssh_exit）
- **前端铁律**（linux-app-web-recamera_web_react/AGENTS.md）：UI 改动必过 i18n+明暗主题+响应式；完成前 `npm run build`
- **MCU/AOV/CVR/fastboot**：均为 Rockchip 参考链，reCamera Pro 出厂不启用（fastboot 是快启预览不是刷机）

## 相关 skills

- `reweb` — SG2002 supervisor 全栈开发（本仓库 WebUI 已迁移过去的项目）
- `recamera` — reCamera wiki QA 与 NPU demo
- 项目记忆 `rv1126b-sg2002-webui-migration` — WebUI 迁移的最终候选与设备信息（登录密码 AES key 等测试细节）
