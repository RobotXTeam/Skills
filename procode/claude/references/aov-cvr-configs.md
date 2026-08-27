# AOV / CVR 参考应用与 BoardConfig 家族

## ⚠️ 定位：这些不是 reCamera Pro 的产品链

AOV/CVR 应用是 Rockchip 的**参考/其他产品形态**；reCamera Pro 走 `linux-ipc-demo_cfg_recamera2`（RK_APP_TYPE=RKIPC_RV1126B_RECAMERA2）。但理解 BoardConfig/RK_APP_TYPE 门控机制对改产品配置是必修课。

## RK_APP_TYPE 门控表（换产品只改 BoardConfig，不改 build.sh）

| RK_APP_TYPE token | 构建什么 | 哪个 BoardConfig 家族 |
|---|---|---|
| `RKIPC_RV1126B_RECAMERA2` | **recamera2-ipc**（产品主 app）+ RK_APP_RECAMERA_{WEB,NOTIFY,ONVIF,SERVICES,GO2RTC,NETWORK} | demo_cfg_recamera2 |
| `RKIPC_RV1126B` / `RKIPC_RV1126B_DV` | rkipc（mk_rkipc）与 recamera2-ipc 的通用/DV 变体 | demo_cfg_rv1126b / _dv |
| `RKCVR_RV1126B` | mk_cvr → linux-app-cvr + LVGL | demo_cfg_rv1126b_cvr |
| `RK_SAMPLE_AOV` + RK_ENABLE_AOV=y | aov_sample_ng | demo_cfg_rv1126b_bat |
| `RK_AO_RECORD_DEMO`(+RK_ENABLE_FASTBOOT) / `RK_AO_RECORD_SERVICE` | ao_record_demo / ao_record_service | **无出厂配置启用**（纯参考） |
| `RK_APP_RKAI` | rkai LLM/VLM demo | demo_cfg_rv1126b 的 LLM_VLM 配置 |
| `RK_FASTBOOT_*` | fastboot_server/client 变体 | bat（TB 电池 IPC） |

app Makefile 用 `$(filter <TOKEN>, $(RK_APP_TYPE))` 自我门控，`make info` 打印支持的 token。

## AOV（Always-On Video）三件套

| 目录 | 作用 |
|---|---|
| linux-app-aov_sample_ng | **AOV 参考框架**：~14 个 sample（vi/venc/iva/aiisp/npu/audio/multi-vi/stitch/aoa-capture）+ 自己的 RkLunch.sh + suspend/resume 测试。按 RK_CHIP 选源（rv1126b → common/isp3.5 + sample_comm_aov_rv1126b.c + 预编译 librk_aoa）。AOA=Always-On Audio（唤醒词 VQE，rockaa 头）。`RK_AOV_APP_BUILD_STATIC=y` 全静态；test/aor_check_integrity 是预编译 PSRAM 完整性检查器勿重建 |
| linux-app-ao_record_demo | 单文件快启录像 demo：VI→VENC+RKAIQ+RTSP，mmap meta 分区共享元数据，2560x1472 即开即录。无出厂配置启用 |
| linux-app-ao_record_service | AOV 预录服务：PSRAM 里 ~5fps RAW 环形缓冲，事件触发后经 FSR（3DNR 超分）编码大小双 MP4 到 SD 卡，freetype OSD。依赖 MCU 侧 PSRAM 预录环（rtos-apps-pre-record）。无出厂配置启用 |

## CVR（连续录像/行车记录）

- `linux-app-cvr`：真 CVR 应用（CMake）：LVGL UI + RKADK 配置 + 前后双摄录像 + 紧急/延时录像 + 远程配置 + NTP + 可选 ADAS/fastboot/AOV。`cfg/rv1126b/cvr_conf.h` 定义传感器数=2、IQ 路径、RKADK ini、SD 挂载 /mnt/sdcard。RkLunch.sh 把 CPU 设 userspace@1512MHz
- `linux-ipc-app-mk_cvr`：构建包装（project/app/cvr）：rkcvr-build 依赖 lvgl-build + rkadk-build；`-DSOC_RV1126B=ON -DUSE_FILECACHE=ON`；make_param_host 从 ini 生成 param 镜像。USE_RKAOV/USE_RKAUTO/USE_RKAUDIO 默认注释

## BoardConfig 五家族（project/cfg/）

| 平铺目录 | 挂载点 | 产品形态 |
|---|---|---|
| **linux-ipc-demo_cfg_recamera2** | project/cfg/BoardConfig_Recamera2 | **reCamera Pro**。主配置 BoardConfig-EMMC-RK801-RV1126B_V1-IPC_64BIT.mk（arm64/aarch64 工具链/uboot rv1126b_recamera2_defconfig/kernel rv1126b_ipc_defconfig+recamera2.config/DTS rv1126b-recamera2-v1.dts/buildroot recamera2_buildroot_aarch64_defconfig/OTA V1.1.2）。32 位变体 IPC.mk（OTA V0.2.1）。`overlay/` 下 overlay-buildroot-* 目录经 RK_POST_OVERLAY 叠加进 rootfs（asound、board-id、websocket_log、watchdog、ttyd、sshd…）。RECAMERA2-IPC-RELEASE-NOTES.md 在 SDK 根 |
| linux-ipc-demo_cfg_rv1126b | BoardConfig_IPC | Rockchip 参考 IPC（26 个 BoardConfig 配置：EVB1/EVB2、EMMC/SPI_NAND/SPI_NOR、fastboot、多摄、UVC、AMP、LLM/VLM、投影）。RK_APP_TYPE=RKIPC_RV1126B。RK-RELEASE-NOTES-IPC.txt=v1.2.0 |
| linux-ipc-demo_cfg_rv1126b_bat | BoardConfig_BatteryIPC | 电池/AOV：AOV（RK_SAMPLE_AOV）、AOA+外置 RAM、TB 快启电池 IPC（RK_FASTBOOT_*）。后处理 rk-spi_nor-aov-post.sh 等 |
| linux-ipc-demo_cfg_rv1126b_cvr | BoardConfig_CVR | 行车记录：CVR / CVR_FASTBOOT / CVR_AOV(SPI_NOR)。rv1126b-pre-oem-post.sh 会从 OEM 剪掉 sample_*/mpi_* 测试二进制、librockit_tiny、iva 模型、librknnrt |
| linux-ipc-demo_cfg_rv1126b_dv | BoardConfig_DV | DV 双视角 64 位参考（RKIPC_RV1126B_DV） |

## 开发要点

1. **改产品配置**只动 `linux-ipc-demo_cfg_recamera2/BoardConfig-EMMC-RK801-RV1126B_V1-IPC_64BIT.mk`：分区表在 RK_PARTITION_CMD_IN_ENV、rootfs 叠加在 RK_POST_OVERLAY、OTA 版本在 RK_OTA_VERSION、IQ 文件清单在 RK_CAMERA_SENSOR_IQFILES（sc450ai/sc850sl ainr）
2. 新增 kernel CONFIG → rv1126b-recamera2.config fragment
3. **cfg 后处理脚本会静默删文件**（rk-fastboot-post.sh、rv1126b-pre-oem-post.sh、tb-*-post.sh）——往镜像里加新二进制/库前先查这些脚本的删除清单
4. RK_APP_TYPE → buildroot 包选择的接线在 `linux-ipc-sysdrv/source/buildroot`（平铺检出中不存在）
5. 所有仓库是 Seeed 对 Rockchip 的镜像（remote iteam-gitlab.seeed.cn/rockchip/*）；dev manifest 跟 main 分支，release manifest 钉 hash
