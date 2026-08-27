# 目录总映射（83 个子仓库 → 嵌套 SDK 树）

当前检出是**平铺**的：83 个 git 子仓库全在顶层。官方嵌套布局以 `rv1126b-manifests/tree.txt` 为准（`generate_project_tree.py` 生成）。所有子仓库 remote 是 Seeed 私有 GitLab（`iteam-gitlab.seeed.cn/rockchip/*`，URL 内嵌 token，勿外泄）。

图例：✅ 可编辑源码　🔒 预编译/二进制 drop　⚙️ 构建胶水/配置　📄 文档

## project/（构建编排 + 应用，→ build.md）

| 平铺目录 | 嵌套路径 | |
|---|---|---|
| linux-ipc-project | `project/` | ⚙️ build.sh 总入口、app/Makefile、rkflash.sh、scripts/ |
| linux-ipc-demo_cfg_recamera2 | `project/cfg/BoardConfig_Recamera2` | ⚙️ **reCamera Pro 产品配置 + overlay/** |
| linux-ipc-demo_cfg_rv1126b | `project/cfg/BoardConfig_IPC` | ⚙️ 参考 IPC 配置家族 |
| linux-ipc-demo_cfg_rv1126b_bat | `project/cfg/BoardConfig_BatteryIPC` | ⚙️ 电池/AOV 配置 |
| linux-ipc-demo_cfg_rv1126b_cvr | `project/cfg/BoardConfig_CVR` | ⚙️ CVR 配置 |
| linux-ipc-demo_cfg_rv1126b_dv | `project/cfg/BoardConfig_DV` | ⚙️ DV 配置 |
| linux-ipc-bsp-meta_tags | `project/make_meta` | ⚙️ sensor meta 镜像生成（reCamera2 不生效） |

## project/app/（应用层，→ recamera2-apps.md / web-ui.md / ai-npu.md / tools-flash.md）

| 平铺目录 | 嵌套路径 | |
|---|---|---|
| linux-ipc-app-recamera2-ipc | `project/app/recamera_ipc` | ✅ **产品主进程 rkipc**（含 RkLunch.sh） |
| linux-ipc-app-lib-vigil | `project/app/recamera_ipc/common/vigil` | ✅ vigil 录像引擎（C++20，进程内库） |
| linux-ipc-app-recamera2-services | `project/app/recamera_services` | ✅ Rust 守护进程套件 |
| linux-ipc-app-recamera2-notify | `project/app/recamera_notify` | ✅ Python 推理通知 |
| linux-ipc-app-recamera2-onvif | `project/app/recamera_onvif` | ✅ gSOAP ONVIF |
| linux-ipc-app-recamera2-utils | `project/app/recamera_utils` | ✅ 产测工具（默认未启用） |
| linux-ipc-project-app-mk_recamera_web | `project/app/recamera_web` | ⚙️ Web 栈 mk 包装 |
| linux-app-web-recamera_web_backend | `project/app/recamera_web/recamera_web_backend` | ✅ C++ FastCGI 后端 entry.cgi |
| linux-app-web-recamera_web_react | `project/app/recamera_web/recamera_web_react` | ✅ React SPA |
| linux-ipc-project-app-mk_ipcweb-backend | `project/app/ipcweb` | ⚙️ 遗留 mini web mk 包装 |
| linux-app-web-new-mini_ipcweb-backend | `project/app/ipcweb/ipcweb-backend` | ✅ 遗留后端 + 预编译 www-rkipc |
| linux-ipc-project-app-mk_rkipc | `project/app/rkipc` | ⚙️ rkipc mk 包装 |
| linux-ipc-app-rkipc | `project/app/rkipc/rkipc` | ✅ rkipc 通用 fork（multi_ipc） |
| linux-app-rkipc | （manifest 外，遗留） | ✅ rkipc 遗留 fork（tuya/battery） |
| linux-app-rkai | `project/app/rkai/rkai` | ✅ RKAI LLM/VLM demo（含 rknn_api.h） |
| linux-app-rkllm | `project/app/rkllm-inference` | ✅ RKNN+RKLLM 多模态 demo（reCamera2 启用） |
| linux-app-ao_record_demo | `project/app/ao_record_demo` | ✅ AOV 快启录像参考 |
| linux-app-aov_sample_ng | `project/app/aov_sample` | ✅ AOV sample 框架 |
| linux-app-cvr | `project/app/cvr/cvr` | ✅ CVR 应用 |
| linux-ipc-app-mk_cvr | `project/app/cvr` | ⚙️ CVR mk 包装 |
| linux-ipc-app-fastboot_server | `project/app/component/fastboot_server` | ✅ thunder-boot 预览（非刷机！） |
| linux-app-fastboot_client | `project/app/fastboot_client` | ✅ thunder-boot 客户端 |
| linux-ipc-app-wifi_app | `project/app/wifi_app` | ✅ WiFi/BT 栈（rkwifi_server） |
| linux-external-uvc_app | `project/app/uvc_app_tiny` | ✅ UVC gadget |
| linux-ipc-app-testdemo | `project/app/testdemo` | ✅ yoloworld/投屏 demo |

## media/（媒体层，→ media-pipeline.md）

| 平铺目录 | 嵌套路径 | |
|---|---|---|
| linux-ipc-media-c | `media/` | ⚙️ media 顶层构建驱动 |
| linux-ipc-media-cfg-rv1126b | `media/cfg` | ⚙️ CONFIG_RK_* 开关 |
| rk-mpp | `media/mpp/mpp`（另挂 `sysdrv/drv_ko/kmpp/kmpp`，**kmpp-develop 分支**，供重建 kmpp 内核模块） | ✅ 硬件编解码 MPP |
| linux-rockit | `media/rockit/rockit` | 🔒 rockit MPI（头文件+示例可看，库闭源） |
| linux-linux-rga | `media/rga/rga` | ✅ RGA 2D 加速（im2d） |
| linux-external-camera_engine_rkaiq | `media/isp/camera_engine_rkaiq` | ✅ ISP/3A 引擎 + IQ 调优文件 |
| linux-external-common_algorithm | `media/common_algorithm/common_algorithm` | 🔒 音视频算法预编译 drop |
| linux-ipc-media-avs | `media/avs` | 🔒 AVS 拼接预编译 + LUT/标定数据 |
| linux-ipc-media-iva_mk | `media/iva` | ⚙️ IVA mk 包装 |
| linux-ipc-media-iva | `media/iva/iva` | 🔒 IVA 预编译 + NPU 模型 |
| linux-ipc-media-samples-ng | `media/samples` | ✅ **MPI 参考示例（学习首选）** |
| linux-ipc-media-sysutils | `media/sysutils` | ✅ gpio/adc/pwm/watchdog 工具库 |
| linux-ipc-app-thirdlibs | `media/third_libs` | ✅ freetype/jpeg/png/zlib |
| rk-rknn-llm | `media/rknn-llm-mk/rknn-llm` | 🔒 RKNN-LLM SDK v1.2.3（运行时预编译 + PC toolkit） |
| linux-ipc-app-component-prerecord | `media/prerecord` | 🔒 预录组件（无 rv1126b 库，本产品无效） |
| linux-ipc-app-component-rockauto_mk | `media/rockauto` | ⚙️ rockauto mk 包装 |
| linux-ipc-app-component-rockauto | `media/rockauto/rockauto` | 🔒 车载视觉库（CVR/ADAS） |
| linux-ipc-media-lvgl_mk | `project/app/component/lvgl` | ⚙️ LVGL 包装（wget，需网络） |
| linux-ipc-media-mk_rkadk | `project/app/component/rkadk` | ⚙️ RKADK 包装 |
| linux-bsp-rkadk | `project/app/component/rkadk/rkadk` | ✅ RKADK 高层 API（rkmuxer/rtsp/stream） |
| linux-ipc-media-mk_rkfsmk_release | `project/app/component/rkfsmk` | ⚙️ rkfsmk 包装 |
| linux-rkfsmk_release | `project/app/component/rkfsmk/rkfsmk` | 🔒 FAT 格式化/MP4 修复预编译库 |
| linux-ipc-media-nginx_mk | `project/app/nginx_mk` | ⚙️ nginx 1.24 + HTTP-FLV（wget，需网络） |
| linux-app-ao_record_service | `project/app/component/ao_record_service` | ✅ AOV 预录服务（见 aov-cvr-configs.md） |
| linux-ipc-app-RkPostISP | （manifest 外/遗留，v1.1.0 已移除） | 🔒 AIISP 预编译库（产品关闭，见 media-pipeline.md） |
| vqe_app | （manifest 外） | ✅ VQE 音频 demo（手动编译） |

## sysdrv/（BSP 层，→ sysdrv-bsp.md）

| 平铺目录 | 嵌套路径 | |
|---|---|---|
| linux-ipc-sysdrv | `sysdrv/` | ⚙️ sysdrv Makefile + tools/{board,pc} |
| linux-ipc-sysdrv-cfg-rv1126b | `sysdrv/cfg` | ⚙️ 平台默认（被 BoardConfig 覆盖） |
| linux-ipc-sysdrv-drv_ko | `sysdrv/drv_ko`（main）+ `sysdrv/drv_ko/wifi`（**wifi 分支**） | ✅ 树外 .ko + insmod_ko.sh + 全部 WiFi 驱动 |
| linux-ipc-sysdrv-drv_ko-motor | `sysdrv/drv_ko/motor` | ✅ 步进电机驱动（未启用） |
| rk-kernel | `sysdrv/source/kernel` | ✅ Linux 6.1.157（产品 64BIT 配置按 ARCH=arm64 编） |
| android-rk-u-boot | `sysdrv/source/uboot/u-boot` | ✅ U-Boot 2017.09 fork |
| rk-rkbin | `sysdrv/source/uboot/rkbin` | 🔒 DDR/SPL/BL31/BL32 + RKBOOT/RKTRUST ini |
| linux-ipc-bsp-idb_bootconfig | `sysdrv/tools/board/idb_bootconfig` | ✅ SPI-NOR 专用，rv1126b 不编 |
| linux-security-bin | `sysdrv/tools/board/security/bin` | 🔒 OP-TEE 客户端预编译 |
| rk-librkcrypto | `sysdrv/tools/board/security/librkcrypto` | ✅ 硬件加密库 |
| android-rk-platform-system-rk_tee_user | `sysdrv/tools/board/security/rk_tee_user` | ✅ TEE SDK CA/TA |

## sysdrv/source/mcu/（MCU 层，→ rtos-mcu.md；reCamera Pro 未启用）

| 平铺目录 | 嵌套路径 | |
|---|---|---|
| rtos-rt-thread-rt-thread | `sysdrv/source/mcu/rt-thread` | ✅ RT-Thread + rv1126b-mcu BSP |
| rtos-apps-battery-ipc | `…/rt-thread/applications/battery-ipc` | ✅ MCU 快启相机 app |
| rtos-apps-pre-record | `…/rt-thread/applications/pre-record` | ✅ MCU 预录 |
| rk-mcu-hal | `…/rt-thread/bsp/rockchip/common/hal` | ✅ MCU HAL |
| linux-ipc-bsp-mcu_build | `sysdrv/source/mcu/project` | ⚙️ MCU build.sh |
| linux-ipc-bsp-mcu_docs | `sysdrv/source/mcu/docs` | 📄 MCU 文档 |
| rtos-rt-thread-docs | （旧 manifest 遗留） | 📄 RT-Thread 指南 PDF |
| rk-prebuilts-xpack-riscv-none-embed-gcc-10.2.0-1.2-linux-x64 | `sysdrv/source/mcu/prebuilts/gcc/linux-x86/riscv/xpack-…` | 🔒 RISC-V 工具链 |

## tools/（→ tools-flash.md）

| 平铺目录 | 嵌套路径 | |
|---|---|---|
| linux-ipc-tools | `tools/` | 🔒 upgrade_tool/rkdownload.sh/Linux_Pack_Firmware/SocToolKit |
| linux-ipc-tools-toolchain-aarch64-rockchip1240-linux-gnu | `tools/linux/toolchain/aarch64-…` | 🔒 **GCC 12.4.0 aarch64（主工具链）** |
| linux-ipc-tools-toolchain-arm-rockchip1240-linux-gnueabihf | `tools/linux/toolchain/arm-…` | 🔒 32 位 armhf |
| linux-ipc-tools-Rockchip_AVS_tool | `tools/windows/Rockchip_AVS_tool` | 🔒 多摄标定（仅 Windows） |

## docs/（→ docs.md）

| 平铺目录 | 嵌套路径 | |
|---|---|---|
| linux-ipc-docs-rv1126b | `docs/` | 📄 Rockchip 官方 PDF 90 份（无 reCamera 内容） |
| rv1126b-manifests | （manifest 仓库本体） | ⚙️ dev/release xml + tree.txt + lock_manifest.py |

## SDK 根 linkfiles（manifest 挂到根的文件）

`build.sh`→project/build.sh、`rkflash.sh`、`RECAMERA2-IPC-RELEASE-NOTES.md`、快速上手 PDF（en/zh）、`Copyright_Statement.md`
