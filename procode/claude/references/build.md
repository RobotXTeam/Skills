# 构建系统与编译工作流

> 数据来源：2026-08-14 对仓库的实际测绘。所有命令均出自仓库内脚本/README。

## ⚠️ 最重要的前提：本平铺检出不能直接编译

当前仓库 `/home/steven/work/RV1126B/仓库/完整的/rockchip` 是一个**平铺的 git-repo 镜像**：83 个子仓库全部平铺在顶层。而 `build.sh` 期望的是 `rv1126b-manifests/tree.txt` 描述的**嵌套 SDK 树**：

- `project/cfg/BoardConfig_Recamera2/`（BoardConfig）
- `project/app/<recamera_ipc, recamera_web, ...>`（各 app + mk_* 包装 Makefile）
- `project/make_meta/`
- `sysdrv/source/{kernel, uboot/{u-boot, rkbin}, mcu/...}`
- `media/<mpp, rockit, avs, ...>`
- `tools/linux/toolchain/<aarch64-rockchip1240-linux-gnu, ...>`

已验证：平铺副本里 `linux-ipc-project/app` 只有 rkai，**没有 `cfg/` 目录**，因此 `./build.sh lunch` 会报 "No available Board Config"。要真正编译，必须：

1. 用 `rv1126b-manifests/recamera_v2_dev.xml` 做 `repo sync`，或
2. 按 `tree.txt` 用**符号链接**把 83 个平铺目录组装成嵌套树，或
3. 离线包场景：解压后 `.repo/repo/repo sync -l`

`tree.txt` 就是目录映射的权威依据（见 `references/directory-map.md`）。

**最小符号链接组装示例**（在平铺仓库的**上一级**新建 SDK 根；完整清单对照 tree.txt）：

```bash
SDK=<平铺仓库路径>
mkdir -p RV1126B_SDK/project/cfg RV1126B_SDK/project/app/component \
         RV1126B_SDK/sysdrv/source/uboot RV1126B_SDK/media RV1126B_SDK/tools/linux/toolchain
cd RV1126B_SDK
ln -s "$SDK/linux-ipc-project" project-build && mv project-build project 2>/dev/null || true
# 实际做法：project 本体 + 各嵌套子仓库
ln -s "$SDK/linux-ipc-project" project
ln -s "$SDK/linux-ipc-demo_cfg_recamera2" project/cfg/BoardConfig_Recamera2
ln -s "$SDK/linux-ipc-app-recamera2-ipc" project/app/recamera_ipc
ln -s "$SDK/linux-ipc-app-lib-vigil" project/app/recamera_ipc/common/vigil
ln -s "$SDK/linux-ipc-project-app-mk_recamera_web" project/app/recamera_web
ln -s "$SDK/linux-app-web-recamera_web_backend" project/app/recamera_web/recamera_web_backend
ln -s "$SDK/linux-app-web-recamera_web_react" project/app/recamera_web/recamera_web_react
ln -s "$SDK/linux-ipc-sysdrv" sysdrv-tmp && ln -s "$SDK/rk-kernel" "$SDK/linux-ipc-sysdrv-cfg-rv1126b" ...
# sysdrv/source/kernel=rk-kernel、sysdrv/source/uboot/{u-boot,rkbin}、
# media/* 与 tools/linux/toolchain/* 同理 —— 逐一对照 tree.txt
```

注意：build.sh 期望 SDK 根有 `build.sh -> project/build.sh` 软链；`linux-ipc-project/app` 平铺里只有 rkai，其余 app 目录需按上面方式挂进 project/app/。

## 构建编排架构

编排核心 = `linux-ipc-project`（挂载为嵌套树的 `project/`）：

```
./build.sh lunch   → 选择 BoardConfig，软链到 $SDK_ROOT/.BoardConfig.mk 并 source
                     导出全部 RK_* 变量（RK_CHIP / RK_TOOLCHAIN_CROSS / RK_KERNEL_DTS /
                     RK_APP_TYPE / RK_PARTITION_CMD_IN_ENV / RK_CAMERA_SENSOR_IQFILES ...）
./build.sh         → 默认 allsave = build_all + build_save
```

`build_all` 顺序（build.sh ~1501-1518 行）：

```
build_sysdrv（uboot → kernel → rootfs → recovery，即 make -C sysdrv）
  → build_media（make -C media）
  → build_app（先 build_meta --export 导出头文件，再 make -C project/app）
  → build_firmware（打包 rootfs.img / userdata.img / recovery.img / update.img / update_ota.tar）
```

**app 阶段的 mk_* 包装模式**：`project/app/Makefile` 用 `$(wildcard ./*/Makefile)` 收集所有子目录；每个子目录是一个 `mk_*` 包装 Makefile（本平铺仓库中对应 `linux-ipc-project-app-mk_*`、`linux-ipc-media-mk_*` 等目录），它们 `include ../Makefile.param`（共享 `RK_APP_CROSS`/`RK_APP_OPTS`/`MAROC_COPY_PKG_TO_APP_OUTPUT` 宏），然后按 BoardConfig 开关门控，对嵌套的真实子仓库执行 cmake/npm 构建，产物拷入 `project/app/out`（=`RK_APP_OUTPUT`）。`out/` 树即 `app_out`，由 firmware 阶段打进 rootfs.img。

## reCamera Pro 的 BoardConfig

`linux-ipc-demo_cfg_recamera2/BoardConfig-EMMC-RK801-RV1126B_V1-IPC_64BIT.mk` 是 reCamera Pro 默认配置：

| 变量 | 值 |
|---|---|
| RK_CHIP | rv1126b |
| 架构/工具链 | arm64 / `aarch64-rockchip1240-linux-gnu` |
| 存储 | eMMC + RK801 PMIC |
| RK_KERNEL_DTS | `rv1126b-recamera2-v1.dts` |
| RK_KERNEL_DEFCONFIG | `rv1126b_ipc_defconfig` + fragments：`rv1126b-display.config rv1126b-sdiowifi.config rv1126b-bt.config rv1126b-recamera2.config`（后者覆盖前者，新增 kernel CONFIG 加到 rv1126b-recamera2.config） |
| RK_UBOOT_DEFCONFIG | `rv1126b_recamera2_defconfig` |
| RK_APP_TYPE | `RKIPC_RV1126B_RECAMERA2` |
| 启用的 app 开关 | `RK_APP_RECAMERA_{WEB,NOTIFY,ONVIF,SERVICES,GO2RTC,NETWORK}=y` |
| 分区表 | `RK_PARTITION_CMD_IN_ENV`：32K(env), 512K@32K(idblock), 4M@1M(uboot), 64K(misc), 10M(recovery), 11M(boot), 3G(rootfs), -(userdata) |
| RK_OTA_VERSION | V1.1.2 |
| RK_AIISP_MODEL | NONE（option-package.sh 会剪掉 librkpostisp.so 和 *.aiisp） |

其他 BoardConfig 变体（非 reCamera Pro）：`linux-ipc-demo_cfg_rv1126b`（通用 IPC）、`_bat`（电池 IPC）、`_cvr`（连续录像）、`_dv`（行车记录类）。

## 完整编译流程（从零）

```bash
# 0. 前置：嵌套树已组装好，进入 project/（SDK 根有 build.sh -> project/build.sh 软链）
./build.sh check        # 检查主机依赖（清单在 scripts/build-depend-tools.txt）：
                        # dtc, makeinfo, gperf, g++-multilib, gcc-multilib, flex, bison,
                        # bzip2, automake, cmake, pkg-config, scons>=4.0.1；
                        # Web 前端另需主机有 node + npm

# 1. 安装工具链（一次性；会写 ~/.bashrc 和 ~/.bash_profile）
cd <SDK_ROOT>/tools/linux/toolchain/aarch64-rockchip1240-linux-gnu/
source env_install_toolchain.sh

# 2. 选板（交互式，或直接传 .mk 文件名）
./build.sh lunch
./build.sh lunch BoardConfig-EMMC-RK801-RV1126B_V1-IPC_64BIT.mk

# 3. 全量编译（默认动词 allsave = build_all + build_save + power-domain 检查）
./build.sh
```

build.sh 全部动词：`uboot kernel rootfs sysdrv driver env media app recovery tool firmware updateimg ota save all allsave unpackimg factory sdcard_upgrade dm dm-key-gen check info kernelconfig buildrootconfig clean <stage>`。可附加 `DEBUG` / `ASAN`（如 `./build.sh app DEBUG` 设 `RK_BUILD_VERSION_TYPE=DEBUG` 并跳过 strip）。

## 产物位置

`RK_PROJECT_OUTPUT_IMAGE = $SDK_ROOT/output/image`：

| 文件 | 内容 |
|---|---|
| download.bin | loader（下载到 DDR；SPL+DDR+USB plug） |
| idblock.img | eMMC loader（按 env 分区表） |
| uboot.img | U-Boot FIT + trust BL31/BL32 |
| env.img | mkenvimage 生成的分区表 + bootargs（来自 RK_PARTITION_CMD_IN_ENV，root=/dev/mmcblk0p7） |
| boot.img | kernel FIT：Image + dtb + resource.img + rv1126b-recamera2 DTBO overlays（RK_KERNEL_RC_DTO=y → boot-dto.its） |
| rootfs.img | ext4，3G 分区；reCamera2 设 `RK_BUILD_APP_TO_OEM_PARTITION=n`，app 装进 rootfs，**不生成 oem.img** |
| userdata.img | 空 ext4 |
| misc.img | recovery-misc.img 副本 |
| recovery.img | recovery kernel + tiny ramdisk FIT |
| update_ota.tar | boot.img + rootfs.img + RK_OTA_update.sh |
| update.img | 整包（tools/linux/Linux_Pack_Firmware/mk-update_pack.sh） |

中间产物：`output/out/{app_out, media_out, sysdrv_out, rootfs_glibc_rv1126b, ...}`、`project/app/out`。
`build_save` 把镜像+patches 复制到 `Image/<BOARD>_<MEDIUM>_<POWER>_<HW>_<DATE>_RELEASE_TEST/`。

## 单组件重建（改代码后最常用）

前提：已 lunch（环境变量已导出）且 media_out 已存在（app 依赖 media 头/库）。

```bash
# 单个 app（如 recamera2-ipc）——在嵌套树中
make -C project/app/recamera_ipc      # app Makefile 按 RK_APP_TYPE 自动门控
                                      # （RKIPC_RV1126B_RECAMERA2 -> -DCOMPILE_FOR_RV1126B=ON）
./build.sh firmware                   # 重新打包镜像（不做全量重建）

# Web 栈
make -C project/app/recamera_web      # backend(cmake) + frontend(npm)
# 仅前端改动：
cd linux-app-web-recamera_web_react && npm run build
# （或 make -C <nested>/recamera_web_react：npm install --legacy-peer-deps + build，
#   产物拷到 ../out/usr/www，保留 cgi-bin/）
./build.sh firmware

# 分阶段重建
./build.sh clean kernel && ./build.sh kernel   # kernel 每次全量重建（先 distclean）
./build.sh driver    # = build_kernel + make -C sysdrv drv（树外 .ko：rockit/kmpp/motor/wifi/dtbo_loader）
./build.sh clean app && ./build.sh app
```

直接调 sysdrv Makefile：`make BOOT_MEDIUM=emmc` / `make uboot` / `make kernel KERNEL_CFG=... KERNEL_DTS=... KERNEL_CFG_FRAGMENT=...` / `make rootfs` / `make drv` / `make env` / `make buildroot_menuconfig`。

## 烧录（详见 tools-flash.md）

```bash
# 板子进 loader/maskrom 模式后：
./rkflash.sh all                    # 用 tools/linux/Linux_Upgrade_Tool/upgrade_tool
./rkflash.sh boot | rootfs | uboot | misc | recovery | userdata | loader | erase
# 或
tools/linux/Linux_Upgrade_Tool/rkdownload.sh -d output/image
# udev 规则（一次性）：cp 88-rockusb.rules /etc/udev/rules.d/ && udevadm control --reload-rules
```

## 本组子仓库一览

| 平铺目录 | 嵌套树挂载点 | 作用 |
|---|---|---|
| linux-ipc-project | `project/` | 构建总编排：build.sh（~104KB）、app/Makefile、app/Makefile.param、scripts/（*.its 模板、mk-fitimage.sh、mkfs_*.sh、build-depend-tools.txt）、rkflash.sh、option-package.sh、diffversion.sh |
| linux-ipc-project-app-mk_ipcweb-backend | `project/app/ipcweb/` | 旧版 mini_ipcweb CGI 后端的 mk 包装（门控 RK_APP_IPCWEB_BACKEND=y 或 RK_ENABLE_WEB_BACKEND=y；rv1126b+arm64 有怪癖：强制 PKG_TARBALL=ipcweb-env-rk3576）。不是 reCamera Pro 的 Web |
| linux-ipc-project-app-mk_recamera_web | `project/app/recamera_web/` | **reCamera Pro Web 栈的 mk 包装**（门控 RK_APP_RECAMERA_WEB=y）：cmake 构建 backend + make 构建 React 前端 |
| linux-rkfsmk_release | `project/app/component/rkfsmk/rkfsmk/` | 预编译的 librkfsmk（FAT 格式化/检查 + MP4 修复），只有头文件可编辑；aarch64 用 `lib/aarch64-rockchip1240-linux-gnu-lib64/librkfsmk.so`；被 rkadk 链接 |
| linux-ipc-media-mk_rkfsmk_release | `project/app/component/rkfsmk/` | rkfsmk 的 mk 包装（把预编译 .so 拷进 app_out；平铺镜像中因找不到嵌套源目录会跳过） |
| linux-ipc-bsp-meta_tags | `project/make_meta/` | sensor meta 镜像生成器（IQ bin + AE/AWB 表）。只有 RK_META_SIZE 被设置时才生效——reCamera2 BoardConfig 没设，所以对 reCamera Pro 是 no-op。`--export` 模式用于 build_app 导出头文件。新增 sensor 要改 build_meta.sh 的 support_sensors |
| linux-rkfsmk_release | — | 见上 |
| linux-ipc-media-mk_rkadk / linux-bsp-rkadk | `project/app/component/rkadk{,/rkadk}` | rkadk 音频/存储开发套件（详见 media-pipeline.md） |
| linux-ipc-media-mk_rkfsmk_release | — | 见上 |

## 关键坑（Gotchas）

1. **平铺副本不可直接 build**（见顶部组装说明）。缺的是嵌套目录结构（project/cfg、project/app 各 mk 包装的嵌套子仓库、sysdrv/source/kernel 等）——`./build.sh lunch` 报 "No available Board Config" 就是因为没有 project/cfg。产品 defconfig `rv1126b_ipc_defconfig` 本身**存在**于 `rk-kernel/arch/arm64/configs/`，与平铺无关。
2. kernel 与 uboot **每次都全量重建**（sysdrv Makefile 先 distclean）；buildroot（一次性从 `linux-ipc-sysdrv/tools/board/buildroot/buildroot-2023.02.6.tar.gz` 解压）和 app cmake 目录是增量的，但 app 每次 `rm -rf build/ out/`。
3. app Makefile 按 `RK_APP_TYPE` 自我门控：token 不匹配时 PKG_TARGET 为空，`make` **静默什么都不编**。用 `./build.sh info` 检查。
4. `./build.sh app` 依赖 media（先 `build_meta --export`，app 链接 `output/out/media_out`）。
5. 改完任何 app 后重新打包必须 `./build.sh firmware`（镜像从 output/out/* 组装，不是从 app 构建目录）。
6. `option-package.sh` 按 `RK_ENABLE_*` 标志（FSR/AVS/AIISP/DIS_EIS/IRFPA…）从 rootfs/oem 删除文件。
7. 分区表内嵌在 env.img（来自 RK_PARTITION_CMD_IN_ENV）；uboot 1M 对齐以预留 256K 给 EMMC_VENDOR。
8. 内核 DTS 改**真身**：`rk-kernel/arch/arm64/boot/dts/rockchip/rv1126b-recamera2-v1.dts`（arch/arm/boot/dts 下是 wrapper）；摄像头板变体以 userdata 里的 .dtbo overlay 形式由 dtbo_loader.ko 加载，不在 dtb 里。
9. Windows 复制会破坏执行位/符号链接（readme_en.txt 明示）。
10. 并行度：`RK_JOBS = nproc/2+1`（build.sh:39 export）；`RK_APP_JOBS` 默认继承 RK_JOBS，仅在 RK_JOBS 未设时回落 nproc。

## 关键文件索引

- `linux-ipc-project/build.sh` — 总入口（~104KB bash）
- `linux-ipc-project/readme_en.txt` / `readme_cn.txt` — 官方构建说明
- `linux-ipc-project/app/Makefile` + `app/Makefile.param` — app 阶段驱动
- `linux-ipc-project/scripts/build-depend-tools.txt` — 主机依赖清单
- `linux-ipc-project/rkflash.sh`、`option-package.sh`
- `linux-ipc-demo_cfg_recamera2/BoardConfig-EMMC-RK801-RV1126B_V1-IPC_64BIT.mk`
- `linux-ipc-sysdrv/Makefile` — sysdrv 阶段（uboot/kernel/rootfs/drv）
- `rv1126b-manifests/tree.txt` — 嵌套树权威映射
