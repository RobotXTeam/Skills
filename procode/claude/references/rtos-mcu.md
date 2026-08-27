# RT-Thread MCU 侧（AMP 子系统）

## ⚠️ 先说结论：reCamera Pro 出厂固件不启用 MCU

reCamera2 BoardConfig **没有** `RK_ENABLE_AMP` / `RK_UBOOT_RKBIN_MCU_CFG`，分区表无 amp 分区，`rv1126b-recamera2-v1.dts` 不含 `rv1126b-amp.dtsi`。电池/充电由 Linux 侧 sysfs 处理（rkipc battery_charge_thread）。本组代码只服务于 Rockchip 的电池 IPC/AOV 方案（`linux-ipc-demo_cfg_rv1126b` 的 AMP BoardConfig）。开发 reCamera Pro 常规功能时**不需要**这一层。

## 硬件与分工

RV1126B = A53 Linux 核 + **RISC-V 400MHz HPMCU**（Synopsys SCR1 级，rv32imc/ilp32，跑 RT-Thread v4.1.x）。MCU 职责（电池 IPC 场景）：

- Linux 启动前的快速 AE/AWB 收敛 + ISP 出图（thunderboot/fastboot 快启）
- 事件前环形缓冲预录（pre-record）
- RK816 PMIC 电池管理（油量计/充电/RTC，在 `bsp/rockchip/common/drivers/pmic/`，不在 battery-ipc 里）
- 低速外设（I2C/SPI/SARADC/PWM/UART）、PMU 定时器/GPIO 唤醒编排、MCU/ARM 运行计数

Linux↔MCU 通信：预留 DDR 共享内存（meta 结构 + ISP3 帧缓冲）+ mailbox/virtio-rpmsg（内核 `rockchip_amp.c`）。

## 子仓库一览（嵌套树挂载于 sysdrv/source/mcu/）

| 平铺目录 | 挂载点 | 作用 |
|---|---|---|
| rtos-rt-thread-rt-thread | mcu/rt-thread | RT-Thread 内核 + rv1126b-mcu BSP。scons 构建：`scons --useconfig=board/<board>/defconfig && scons --genconfig && scons -j16` → rtthread.elf/bin。板型目录 `board/`：rv1126b_evb1、rv1126b_evb2-{SC200AI,SC450AI,SC450AI-SC450AI,SC850SL}-ADC（命名 [board]-[sensor]-[lightsensor]）、fpga。调试串口 UART4_M2(GPIO6_A0/A1) 1.5Mbps |
| rtos-apps-battery-ipc | rt-thread/applications/battery-ipc | MCU 侧"电池 IPC"相机应用：fast_ae.c(~1900 行快速 AE/AWB)、isp_stream MSH 命令；链预编译 libfastae_gcc.a/libfastawb_gcc.a；rv1126b_evb2-* defconfig 启用（CONFIG_RT_USING_RK_BATTERY_IPC=y） |
| rtos-apps-pre-record | rt-thread/applications/pre-record | MCU 预录（共享 DDR 环形缓冲），pre_record MSH 命令。⚠️ `RT_USING_RK_PRE_RECORD` **没有 Kconfig 定义**、任何 defconfig 都没开——启用要自己加 Kconfig |
| rk-mcu-hal | rt-thread/bsp/rockchip/common/hal | MCU HAL（hal_base/cru/gpio/i2c/isp…+ CMSIS + RV1126B BSP init）。LAST_COMMIT 是未展开的 $Format:%H$ 占位符 |
| linux-ipc-bsp-mcu_build | mcu/project | MCU 构建包装：`./build.sh lunch|all|menuconfig|save|clean`；scons + mkimage.sh → output/image/{rtthread.bin, hpmcu.img 或 amp.img} |
| linux-ipc-bsp-mcu_docs | mcu/docs | RV1126B MCU 快速上手、AMP quick start、FAQ、电源/时钟/DVFS 文档 |
| rtos-rt-thread-docs | （v0.1.0 曾挂 mcu/docs） | Rockchip RT-Thread 开发指南 PDF 合集（AMP/UART/Power/Clock…）。新版 manifest 已不含此仓库 |
| rk-prebuilts-xpack-riscv-none-embed-gcc-10.2.0-1.2-linux-x64 | mcu/prebuilts/gcc/linux-x86/riscv/xpack-… | RISC-V 工具链（GCC 10.2.0，前缀 riscv-none-embed-）。只列目录，勿改 |

## 构建与烧写（AMP 板卡场景）

```bash
# 从 Linux SDK 顶层（需 RK_ENABLE_AMP=y 的 BoardConfig）
./build.sh mcu amp

# 或 MCU 构建包装
cd sysdrv/source/mcu/project && ./build.sh lunch && ./build.sh all

# 打包
./mkimage.sh amp          # FIT 打包 amp.img（Image/amp.its，load 0x48c02000）
cat rkbin/hpmcu_start.bin rtthread.bin > Image/hpmcu.img   # thunderboot 变体

# 烧写
upgrade_tool di -amp amp.img          # maskrom 模式
dd if=/tmp/amp.img of=/dev/block/by-name/amp bs=1M oflag=dsync   # eMMC 设备上
```

主机依赖：make、texinfo、scons(python2 时代)、`pip install kconfiglib numpy configparser`。工具链路径由 rtconfig.py `EXEC_PATH` 指向（可用 RTT_EXEC_PATH 覆盖）。

## 固定地址（改一个必须同步改全部四处）

| 地址 | 用途 | 出现位置 |
|---|---|---|
| 0x48c02000 | MCU 固件基址（DRAM_SIZE 0x3a000） | link.lds.S、Image/amp.its、内核 rv1126b-amp.dtsi reserved-memory(hpmcu@48c02000 0x3a000 no-map)、RV1126BTRUST_MCU.ini |
| 0x41300000 | ISP3 共享 DDR | battery-ipc/meta 头 |
| 0x41240000 | META 共享 DDR | CONFIG_RT_USING_META_DDR_ADRESS |

meta 共享头（rk_meta.h、rk_meta_wakeup_param.h、rk_meta_app_param.h）在 battery-ipc 与 `linux-ipc-bsp-meta_tags/include` 各有一份——**两边必须手工同步**。

## 内核侧启用 AMP 的三件套

1. kernel fragment `arch/arm64/configs/rockchip_amp.config`（CONFIG_MAILBOX/CONFIG_ROCKCHIP_AMP/CONFIG_RPMSG_VIRTIO/CONFIG_ROCKCHIP_MBOX）
2. DTS `#include rv1126b-amp.dtsi`
3. BoardConfig：`RK_ENABLE_AMP=y` + `RK_UBOOT_RKBIN_MCU_CFG` + uboot rk-amp.config fragment + 分区表加 1M(amp)

## 关键坑

1. **reCamera Pro 不用这套**——动手前先确认是否真的要 AMP。
2. mcu_build/build.sh 硬编码 SDK_ROOT_DIR=父目录；平铺检出无法直接编，必须按 tree.txt 挂载。
3. 顶层 build.sh 的 build_mcu() 期望 `sysdrv/source/mcu/build.sh`，但脚本实际挂在 `sysdrv/source/mcu/project/build.sh`（路径不一致）。
4. MCU 用到的 CLK/pinctrl 要在 rv1126b-mcu.dtsi/rv1126b-amp.dtsi 声明并在内核侧 disable 对应外设（资源划分规则见 mcu_docs 快速上手）。
