# sysdrv / BSP 层（启动链 + 内核 + U-Boot + 驱动模块）

## 启动链

```
ROM → download.bin / idblock.img（SPL + DDR rv1126b_ddr_1332MHz）
  → U-Boot（rv1126b_recamera2_defconfig，读 env.img 分区表）
  → boot.img FIT（Linux 6.1.157 + rv1126b-recamera2-v1.dtb + resource.img + recamera2 DTBO overlays）
  → rootfs（ext4，/dev/mmcblk0p7，busybox init）
recovery：misc 分区标志置位时，用 rv1126b_recovery_defconfig kernel + tiny ramdisk
```

分区表（env.img，由 mkenvimage 从 `RK_PARTITION_CMD_IN_ENV` 生成）：
`blkdevparts=mmcblk0:32K(env),512K@32K(idblock),4M@1M(uboot),64K(misc),10M(recovery),11M(boot),3G(rootfs),-(userdata)`；bootargs `root=/dev/mmcblk0p7`。**无 oem/amp 分区**。

## 子仓库 → 嵌套树挂载

| 平铺目录 | 挂载点 | 内容 |
|---|---|---|
| linux-ipc-sysdrv | `sysdrv/` | 层编排 Makefile + Makefile.param + tools/{board,pc}（buildroot defconfig、busybox、eudev、adbd、rk_ota、mkenvimage/mkimage、dm-crypt、security Makefile） |
| linux-ipc-sysdrv-cfg-rv1126b | `sysdrv/cfg/` | cfg.mk/package.mk 平台默认值。**reCamera2 实际值全部被 BoardConfig 的 RK_\* 覆盖** |
| linux-ipc-sysdrv-drv_ko | `sysdrv/drv_ko/` | 树外 .ko：rockit、kmpp（默认预编译；源码来自 rk-mpp 的 kmpp-develop 分支另挂 `drv_ko/kmpp/kmpp`）、dtbo_loader + insmod_ko.sh |
| linux-ipc-sysdrv-drv_ko（wifi 分支） | `sysdrv/drv_ko/wifi/` | 同一仓库的 `wifi` 分支：bcmdhd/atbm/ssv/rtl/aic8800/rk96x + insmod_wifi.sh。**改 WiFi 驱动要切到 wifi 分支** |
| linux-ipc-sysdrv-drv_ko-motor | `sysdrv/drv_ko/motor/` | 24BYJ-48 步进电机 motor.ko + 用户态库（ENABLE_MOTOR=y 才编；reCamera2 未启用） |
| rk-kernel | `sysdrv/source/kernel/` | Linux 6.1.157。产品 64BIT 配置按 **ARCH=arm64** 编（由 RK_TOOLCHAIN_CROSS=aarch64-… 推导） |
| android-rk-u-boot | `sysdrv/source/uboot/u-boot/` | Rockchip U-Boot 2017.09 fork + make.sh |
| rk-rkbin | `sysdrv/source/uboot/rkbin/` | 预编译 boot 二进制（DDR/SPL/BL31/BL32/usbplug）+ RKBOOT/RKTRUST ini + boot_merger 等工具 |
| linux-ipc-bsp-idb_bootconfig | `sysdrv/tools/board/idb_bootconfig/` | SPI-NOR idblock 配置工具。**Makefile 只对 rv1106/rv1103b 生效 → rv1126b 上不会编**，本产品无效 |
| linux-security-bin | `sysdrv/tools/board/security/bin/` | 预编译 OP-TEE 客户端库（optee_v1/v2/v3，v3=OP-TEE 4.8.0） |
| rk-librkcrypto | `sysdrv/tools/board/security/librkcrypto/` | 硬件加密库（AES/SM4/RSA/ECC，DMA）；ENABLE_RKCRYPTO=y 才启用 |
| android-rk-platform-system-rk_tee_user | `sysdrv/tools/board/security/rk_tee_user/` | TEE SDK（CA+TA），v2/build.sh 6432；keybox_app TA。**reCamera2 BoardConfig 未开 RK_ENABLE_RK_TEE_USER → 出厂镜像无 TEE 用户态**（BL32 仍在 trust.img 里） |

## kernel 要点（rk-kernel）

- **产品 defconfig**：`rv1126b_ipc_defconfig`（在 **arch/arm64/configs/**，平铺检出中真实存在）+ fragments：`rv1126b-display.config rv1126b-sdiowifi.config rv1126b-bt.config rv1126b-recamera2.config`（**后面的覆盖前面的**；新增 CONFIG 加进 rv1126b-recamera2.config）。arch/arm/configs/ 下的 rv1126b_defconfig 等属于 32 位参考配置
- 产品 DTS：`arch/arm64/boot/dts/rockchip/rv1126b-recamera2-v1.dts`（arm64 构建直接用它；`arch/arm/boot/dts/rv1126b-recamera2-v1.dts` 只是一行 `#include "arm64/rockchip/..."` 的 shim，供 32 位参考配置使用，DTC_FLAGS -@ 支持 overlay）
- overlays：`rv1126b-recamera2-baseboard-{0,1}.dts`、`-extboard-{0,1}.dts` 编进 boot.img resource；运行时 `dtbo_loader.ko` 从 `/userdata/*.dtbo` 再应用（最多 8 个）——**新摄像头板以 userdata 里的 .dtbo 交付，不改 dtb**
- boot.img 打包：`scripts/mkimg --dtb` + `boot-dto.its`（RK_KERNEL_RC_DTO=y）→ FIT(kernel+fdt+resource+overlays)
- 每次全量重建（sysdrv 先 distclean）；PANIC_ON_OOPS 开启

## U-Boot 要点（android-rk-u-boot）

- 构建由 sysdrv 驱动：`make rv1126b_recamera2_defconfig rk-emmc.config rv1126b-ipc.config` 后 `./make.sh --spl-new <overlay-ini> --no-sign`——**不要直接跑 make.sh，走 sysdrv Makefile**（make.sh 硬编码了 prebuilts 工具链路径）
- 产物：uboot.img（FIT + trust BL31/BL32）、download.bin、idblock.img；调试符号打包 uboot.debug.tar.bz2
- defconfig 特性：FIT + HW crypto、ROCKCHIP_VENDOR_PARTITION（EMMC_VENDOR 区）、fastboot flash 开启、BOOTDELAY=0
- 安全启动签名默认关（--no-sign；RK_ENABLE_SECURE_BOOT 未设）

## rkbin 版本配对

`RKBOOT/RV1126BMINIALL_IPC.ini`（LOADER1=DDR FlashData + LOADER2=SPL FlashBoot，RC4 off，NEWIDB）+ `RKTRUST/RV1126BTRUST.ini`（BL31 v1.13 + BL32 optee v1.04）。关键二进制：`bin/rv11/rv1126b_ddr_1332MHz_v1.10.bin`、`rv1126b_spl_ipc_v1.05.bin`、`rv1126b_bl31_v1.13.elf`、`rv1126b_bl32_v1.04.bin`。**BL31/bl32 与 TEE 用户态有版本耦合，不要单独升级某一个。**

## 内核模块加载顺序（/oem/usr/ko/insmod_ko.sh，drv_ko 仓库提供）

```
rk_aoa → rk_dvbm → otp_eeprom → sensor 驱动(sc450ai/sc850sl/imx/gc...)
→ videobuf2* → video_rkcif/rkaiisp/rkisp/rkvpss/rkavsp → csi2 dphy
→ rga3 → kmpp(+kmpp_smart) → rknpu → snd-soc-* → motor(缺则跳过)
→ rockit_osal/rockit → 后台 insmod_wifi.sh（AP6256/bcmdhd，按 SDIO VID 02d0 匹配）
```

## 常用操作

```bash
./build.sh sysdrv            # 整层
./build.sh kernel            # kernel（每次全量）→ boot.img
./build.sh uboot             # → download.bin/idblock.img/uboot.img
./build.sh rootfs            # buildroot rootfs
./build.sh driver            # kernel + 树外 .ko（drv 目标）
./build.sh env               # env.img
./build.sh kernelconfig      # menuconfig（diff 写入 user.config，手动并进 fragment）
# sysdrv 内直调：make kernel KERNEL_DTS=rv1126b-recamera2-v1.dts BOOT_MEDIUM=emmc
```

buildroot 一次性从 `linux-ipc-sysdrv/tools/board/buildroot/buildroot-2023.02.6.tar.gz` 解压后增量构建；reCamera2 defconfig：`recamera2_buildroot_defconfig`（arm64 为 `recamera2_buildroot_aarch64_defconfig`）。

## 工具链

- `aarch64-rockchip1240-linux-gnu` — **产品 64BIT 配置全程用它**：uboot、kernel（ARCH=arm64）、media、应用、buildroot（recamera2_buildroot_aarch64_defconfig）
- `arm-rockchip1240-linux-gnueabihf` — 32 位变体（BoardConfig-…-V1-IPC.mk）与参考配置用；media cfg.mk 的 CONFIG_RK_MEDIA_CROSS 默认值是它，但会被 BoardConfig 的 RK_TOOLCHAIN_CROSS 覆盖
- 期望位置：`tools/linux/toolchain/<cross>/bin/`（平铺检出中是两个独立顶层目录）

## 关键坑

1. 64BIT 产品配置的**内核也是 arm64**（ARCH 由 RK_TOOLCHAIN_CROSS 在 sysdrv Makefile.param 推导）——不要按 32 位思路找 arch/arm/configs；产品 defconfig/fragments 全在 arch/arm64/configs/。32 位叙述只适用于 V1-IPC.mk（非 64BIT）变体。
2. DTS：改 arm64 目录下的真身（见上）。
3. WiFi 驱动在 drv_ko 的 **wifi 分支**（manifest 把同一仓库挂载两次）；kmpp 内核模块源码则是 **rk-mpp 仓库的 kmpp-develop 分支**挂载在 `sysdrv/drv_ko/kmpp/kmpp`（默认编的是预编译 .ko，要重建从这里出）。
4. reCamera Pro 上 WiFi=AP6XXX（bcmdhd）；motor、idb_bootconfig、TEE 用户态、secure boot 全部**未启用**。
5. kernel/uboot 每次 distclean 全量重建——小改动也要等完整编译。
6. 本文所有 `./build.sh`/`make` 命令都要求**嵌套 SDK 树**（见 build.md 的组装说明），平铺检出里直接跑会失败。

## 新增 sensor 五步配方

1. **内核驱动**：sensor 驱动是树内模块（`rk-kernel/drivers/media/i2c/sc450ai.c`、`sc850sl.c` 是现成例子）——加驱动源文件 + Kconfig/Makefile 条目
2. **defconfig fragment**：在 rv1126b-recamera2.config 里开对应 CONFIG（fragment 后者覆盖前者）
3. **insmod_ko.sh**：`linux-ipc-sysdrv-drv_ko/insmod_ko.sh` 里有**硬编码** sensor 列表——`__rmmod_camera_sensor` 名单（约 23 个）和 `__insmod` 段（sc450ai.ko/sc850sl.ko 处）都要加新 .ko
4. **设备树**：DTS 加 sensor/camera 节点（或走 .dtbo overlay + dtbo_loader.ko，见上）
5. **ISP 调优**：rkaiq IQ JSON（`rkaiq/iqfiles/isp35/`，命名 `{sensor_name}.json`）+ BoardConfig `RK_CAMERA_SENSOR_IQFILES` 打包清单（详见 media-pipeline.md ISP 层）
