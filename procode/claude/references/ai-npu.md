# AI / NPU 栈（RKNN + RKNN-LLM）

## 运行时栈

```
rknpu.ko（insmod_ko.sh 加载；DT npu@22000000 "rockchip,rv1126b-rknpu"，IOMMU rknpu_mmu）
  ← librknnrt.so（RKNN 运行时，经 media_out/rootfs 提供）
  ← librkllmrt.so（RKNN-LLM 运行时，来自 rk-rknn-llm，预编译）
  ← 应用 C API：rknn_api.h / rkllm.h
```

## 子仓库一览

| 平铺目录 | 内容 |
|---|---|
| **rk-rknn-llm** | 上游 RKNN-LLM SDK **v1.2.3**（RV1126B 自 v1.2.1 支持）。🔒 预编译：`rkllm-runtime/Linux/librkllm_api/{aarch64,armhf}/librkllmrt.so` + `include/rkllm.h`（API：rkllm_init/run/run_async/destroy/clear_kv_cache/set_chat_template/load_lora）。`rkllm-toolkit/packages/` = PC 端 x86_64 Python wheels（HF/GGUF → .rkllm 转换量化，w4a16/w8a8，optimization_level=0 性能最佳）。`examples/rkllm_api_demo/deploy/` 是 C API 参考。文档 doc/Rockchip_RKLLM_SDK_{CN,EN}_1.2.3.pdf。`scripts/fix_freq_rv1126b.sh` 锁频（NPU 950MHz/CPU 1.6G/DDR 1.33G）跑分用 |
| **linux-app-rkai** | Rockchip RKAI demo：rkai_LLM_Demo（Qwen3-0.6B W4A16）+ rkai_VLM_Demo/Vision_Demo（fastvlm-0.5b）。挂载 `project/app/rkai`，`RK_APP_TYPE=RK_APP_RKAI` 时构建（LLM_VLM 参考板配置）。**cmake 配置期 wget 下载** Qwen3-0.6B_W4A16_RV1126B.rkllm（modelscope，需要网络）。配置 `app_conf/config/rkai_cfg.ini`（模型路径、ctx 长度 LLM 1024/VLM 512、max_new_tokens 128、top_k=1、系统提示词、VLM image tokens）。自带 rknn_api.h（被 rkllm 仓库复用） |
| **linux-app-rkllm** | Seeed 集成的多模态推理/跑分 demo（RKNN 视觉编码器 + RKLLM 解码器）。挂载 `project/app/rkllm-inference`，门控 `RK_APP_RKLLM_INFERENCE=y`（**reCamera2 BoardConfig 已设**）。产物 rkllm_inference_demo（交互）/ rkllm_benchmark_demo（TTFT/prefill/decode/内存）。⚠️ cmake 硬依赖 linux-app-rkai 的 `rkai/common/include/rknn_api.h`（`-DRKNN_API_INCLUDE_DIR=../rkai/rkai/common/include`）——**rkai 仓库必须同步在场** |

## 构建与数据流

1. media 构建：`linux-ipc-media-c/rknn-llm-mk/Makefile` 在 `CONFIG_RK_NPU_RUNTIME=y` 时把 librkllmrt.so + rkllm.h 拷进 media_out
2. app 构建：rkai（RK_APP_TYPE=RK_APP_RKAI）/ rkllm-inference（RK_APP_RKLLM_INFERENCE=y），均链 media_out + buildroot sysroot 的 OpenCV
3. 打包：`option-package.sh` 除非 RK_APP_TYPE=RK_APP_RKAI 否则**剪掉 librkllmrt.so**——reCamera2 产品镜像走自己的打包路径带上 rkllm-inference

## 产品内的 AI（reCamera Pro 实际用的）

- **视觉检测**：recamera2-ipc `common/rc_infer`（RKNN 通用检测封装，YOLOv8 后处理）；模型 `/userdata/config/model/<ext>/<name>`（rc_model，RC_MODEL_BASE_DIR）；仓库自带 nanodet-plus-m_416.rknn、yolox_s.rknn
- **推理结果**：inference.proto → rc_notify → notify server（MQTT/HTTP/WS/UART）→ vigil 的 inference 触发规则
- rkllm_inference_demo 作为 LLM 跑分/演示随产品镜像出货；模型生命周期由 recamera2-ipc 管理（/userdata/config/model/rkllm/）

## 设备操作

```bash
# NPU sysfs：/sys/class/devfreq/22000000.npu
rk-rknn-llm/scripts/fix_freq_rv1126b.sh      # 跑分前锁频
rkai_LLM_Demo --config <path>/rkai_cfg.ini
rkllm_inference_demo <img> <encoder.rknn> <llm.rkllm> <max_new_tokens> <max_ctx> <cores> [img tokens]
# cores: 2=RKNN_NPU_CORE_0_1, 3=CORE_0_1_2, 其他=AUTO
```

RV1126B 跑分参考（benchmark.md）：Qwen3-0.6B w4a16 ≈ **15.4 tok/s**，TTFT ≈ 956ms。

## 关键坑

1. 模型不在仓库里：rkai 的模型 cmake 时 wget；VLM fastvlm 模型按文档手动下载。
2. rkllm 仓库缺 rkai 仓库会配置失败（rknn_api.h 跨仓库引用）。
3. VLM 的 img_start/img_end/img_content token 必须匹配模型 chat template，否则输出乱码。
4. librkllmrt.so 是预编译 drop——替换要整体换，不可重建。
5. rknpu-driver tarball 只是参考内核驱动源码；真实驱动随 rk-kernel 出货。
