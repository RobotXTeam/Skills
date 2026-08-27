# 媒体管线与 ISP/算法层

## 分层总览

```
sensor(sc450ai / IR sc850sl)
  → camera_engine_rkaiq（librkaiq.so，ISP 3.5/V35，3A + IQ 调优）
  → [可选 RkPostISP/AIISP NPU 增强 — reCamera Pro 关闭]
  → rockit MPI（VI/GDC/VPSS/VENC/VO/AVS/IVS/AI/AO/RGN/TDE/SYS/MB）← 应用主要调用的 API
      ├─ rk-mpp（硬件编解码引擎，H.264/H.265/JPEG 编+解码，无 VP8/AV1）
      ├─ linux-linux-rga（im2d 2D 加速：resize/crop/旋转/blend）
      ├─ AVS（多摄拼接，预编译 librkALG_avsCore.so）
      └─ IVA（NPU 视频分析，预编译 librockiva + .data 模型）
  → rkadk（可选的高层封装：record/stream/rtsp/rtmp/muxer/OSD）
```

**关键认知：rockit MPI 核心、IVA、AVS 是预编译闭源二进制**（仓库只有头文件+示例）——只能链接使用，不能重建。可编辑的只有：rk-mpp、linux-linux-rga、linux-bsp-rkadk、sysutils、samples、thirdlibs、alsa/libdrm/libv4l、rkaiq。

## 构建组织

- 顶层驱动：`linux-ipc-media-c`（挂载为 `media/`），Makefile 迭代 `./*/Makefile`（mpp/rockit/rga/isp 等包装目录 + alsa-lib/libdrm/libv4l/sysutils/avs/iva/samples/third_libs），产物汇聚到 `media/out/{lib,include,bin,root,isp_iqfiles,share,avs_calib}` → 复制为 `output/out/media_out` → 打进 rootfs
- 芯片开关：`linux-ipc-media-cfg-rv1126b/cfg.mk`（挂载为 `media/cfg/cfg.mk`）：CONFIG_RK_CHIP=rv1126b、ISP HW V35、MPP/RKAIQ/RGA2/ROCKIT/IVA/AVS/FSR=y、libiconv=n、rockauto=n、MPP allocator 非 DRM。cfg.mk 里 CONFIG_RK_MEDIA_CROSS 默认 arm-rockchip1240（32 位），但 media Makefile.param 会用 BoardConfig 的 RK_TOOLCHAIN_CROSS 覆盖——**产品 64BIT 配置下 media 也是 aarch64 编**
- 重建单模块：`cd media/<mod> && make clean && make`（先确认 cfg.mk 门控为 y）；整体 `./build.sh media`（需嵌套树，见 build.md）
- lib64 目录普遍备有 aarch64/armhf 双变体（预编译库按 RK_MEDIA_ARCH_TYPE 选）

## 子仓库一览

| 平铺目录 | 挂载点 | 状态 | 要点 |
|---|---|---|---|
| rk-mpp | media/mpp/mpp | ✅ 源码可改 | 硬件编解码。`-DMPP_SOC=RV1126B`（soc.cmake 启用 VDPU384A/VDPU720/VEPU511）。MPP_SOC 写错会静默改 codec 集 |
| linux-rockit | media/rockit/rockit | 🔒 预编译 | **应用的主 API**。头文件 `mpi/sdk/include/rk_mpi_*.h`；librockit.so 在 `lib/<arch>/rv1126b/linux/`；权威文档 `mpi/doc/Rockchip_Developer_Guide_MPI_CN.pdf`。rv1126b 用 uAPI2（-DUAPI2） |
| linux-ipc-media-c | media/ | Make | 顶层构建驱动 + Makefile.param |
| linux-ipc-media-cfg-rv1126b | media/cfg | Make | CONFIG_RK_* 开关表 |
| linux-ipc-media-avs(+ 无 mk) | media/avs | 🔒 预编译 | 拼接算法 + 标定/LUT 数据 + 2/4 摄 JSON/XML 配置。LUT 用 Windows 端 Rockchip_AVS_tool 离线生成。RK_ENABLE_AVS=y 启用 |
| linux-ipc-media-iva + -iva_mk | media/iva{,_mk} | 🔒 预编译 | librockiva（检测/人脸/图像分析）+ NPU .data 模型；-DTARGET_SOC 选芯片变体 |
| linux-ipc-media-samples-ng | media/samples | ✅ 源码 | **学 MPI 的首选参考**：`simple_test/simple_vi_bind_venc_rtsp.c`（VI→VENC→RTSP）、`simple_vi_bind_avs_bind_venc.c`、音频 ai→aenc；`simple_cmd_rv1126b.txt` 是设备运行命令清单 |
| linux-ipc-media-sysutils | media/sysutils | ✅ 源码 | librksysutils：gpio/led/pwm/adc/iio/watchdog 封装；examples 即文档 |
| linux-linux-rga | media/rga/rga | ✅ 源码 | im2d API（im2d_api/im2d.h）；`-DRKRGA_TARGET_SOC=rv1126b` |
| linux-ipc-media-lvgl_mk | project/app/component/lvgl | Make | LVGL 8.4.0 静态库；按 RK_APP_TYPE 选 lv_conf；**构建时 wget，离线需预放 tarball** |
| linux-ipc-media-mk_rkadk + linux-bsp-rkadk | project/app/component/rkadk{/rkadk} | ✅ 源码 | RKADK 高层封装（record/stream/rtsp/muxer/storage）；依赖 rkfsmk+thirdlibs 先编；reCamera 主 app 直接用 rockit，但 rkadk 可用（vigil 的 MP4 写入就走 rkmuxer） |
| linux-ipc-media-nginx_mk | project/app/nginx_mk | Make | nginx 1.24.0 + HTTP-FLV 模块 + S56nginx；**构建时 wget**；依赖 buildroot 的 openssl/zlib/pcre2 |
| linux-ipc-app-thirdlibs | media/third_libs | ✅ 源码 | freetype/libjpeg/libpng/zlib（libiconv 关闭） |

## ISP 层（camera_engine_rkaiq）

- 挂载：`media/isp/camera_engine_rkaiq`，经 `linux-ipc-media-c/isp/Makefile` 构建：`-DISP_HW_VERSION=ISP_HW_V35`（RV1126B）、产物 librkaiq.so、rkisp_demo、**rkaiq_3A_server**（设备上的 S40rkaiq_3A）、rkaiq_tool_server、IspFec（rv1126b 专属，FEC/LDCH 畸变校正网格）、smart_ir、rk_stream
- **IQ 调优文件**：`rkaiq/iqfiles/isp35/{common,ainr,airms}`。reCamera2：RGB=sc450ai、IR=sc850sl，ainr 下有 NPU 降噪模型子目录（sc450ai/{bnr,ynr}）。旧 XML 工程在 iqfiles 根目录（iq_parser_v2 转 JSON）
- **绑定机制**：app 传 sensor V4L2 entity name + 目录，引擎打开 `{iq_dir}/{sensor_name}.json`——没有目录扫描。app 侧代码：recamera2-ipc `common/isp/rv1126b/isp.c`（`rk_aiq_uapi2_sysctl_enumStaticMetasByPhyId` → `sysctl_init(sensor_name, iq_dir)`）
- **改调优的操作**：改 `rkaiq/iqfiles/isp35/...` 下的 JSON → `./build.sh media` → 拷到设备 **/oem/usr/share/iqfiles**（即 `rkipc -a` 指定的目录）；要改出厂打包清单就改 BoardConfig 的 `RK_CAMERA_SENSOR_IQFILES`

## 算法库（common_algorithm / vqe_app / RkPostISP）

- `linux-external-common_algorithm`（media/common_algorithm）：🔒 **几乎全是预编译 drop**。音频：rkaudio_algorithms（VQE/AINR/声音事件检测，conf_rv1126b 含 config_aivqe_aad_wakeup.json、fw_aad_aed.bin、rkaudio_model_sed_bcd.rknn）、rkap_3a、rkap_anr、rockaa(AEC)；视频：move_detect、occlusion_detect；misc：DIS/EIS。修改 = 换库/换配置，不是重编
- `vqe_app`：无构建系统，手动编：
  ```bash
  aarch64-rockchip1240-linux-gnu-gcc -o vqe_main vqe_main.c <cJSON.c> \
    -I <include> -L linux-external-common_algorithm/audio/rkaudio_algorithms/lib64 \
    -lrkaudio_vqe -lrkaudio_common
  ./vqe_main in_2ch_16k.wav out_1ch_16k.wav [config.json]
  ```
  库报 "wrong input in_size" 时加 `-DRKPREP_IN_SIZE_IS_BYTES=1`
- `linux-ipc-app-RkPostISP`：AIISP（NPU 后 ISP 增强）预编译库 + .aiisp 模型。⚠️ **未挂载进 tree.txt，且 reCamera2 BoardConfig 设 RK_AIISP_MODEL=NONE → 本产品关闭**；option-package.sh 还会把 librkpostisp.so 从镜像里剪掉

## 开发指引

- 写新的媒体应用：从 `linux-ipc-media-samples-ng/simple_test/` 抄起，链 `-lrockit -lrockchip_mpp -lrga -lrkaiq`（静态：`make rk_static=1`）
- 应用侧真实用例：recamera2-ipc `src/rv1126b_ipc/video/video.c`（VI→GDC→VPSS→VENC + bind + 帧分发）
- MPI 用法查 `linux-rockit/mpi/doc/Rockchip_Developer_Guide_MPI_CN.pdf`；RGA 查 linux-linux-rga/docs；RKADK 查 linux-bsp-rkadk/docs
