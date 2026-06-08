# Custom Model Conversion And NPU Demo Methodology

当用户要求将新的 PyTorch/ONNX 模型部署到 reCamera 的 NPU 或创建新的非 wiki demo 时使用此方法论。预期输出是一个可工作的 `cvimodel`、reCamera 侧的 C++ demo、真实设备证据和简短的部署报告。在模型在 reCamera 上加载并运行之前，不要将转换称为"已部署"。

## Host Conversion Baseline

首选转换栈：

- Docker 镜像：`sophgo/tpuc_dev:v3.1`。
- 将真实的本地 TPU-MLIR 安装挂载到容器的 `/workspace/tpu-mlir`；镜像的内置路径可能是空的。
- 使用 `model_transform.py`、`run_calibration.py` 和 `model_deploy.py`。
- 将工作保持在任务目录下，如 `/home/steven/work/recamera_<model>`。

命令模板：

```bash
docker run --rm \
  -v /path/to/tpu-mlir:/workspace/tpu-mlir \
  -v "$PWD":/work \
  sophgo/tpuc_dev:v3.1 bash -lc '
    source /workspace/tpu-mlir/envsetup.sh
    cd /work
    model_transform.py --model_name <name> --model_def <model>.onnx \
      --input_shapes <exported_onnx_input_shape> --mean <m0,m1,m2> --scale <s0,s1,s2> \
      --keep_aspect_ratio --pixel_format rgb --test_input <image> \
      --mlir <name>.mlir
    run_calibration.py <name>.mlir --dataset calib --input_num 8 \
      -o <name>_cali_table
    model_deploy.py --mlir <name>.mlir --quantize INT8 \
      --calibration_table <name>_cali_table --chip cv181x \
      --fuse_preprocess --customization_format RGB_PACKED \
      --model <name>_cv181x_int8.cvimodel
  '
```

## Conversion Decisions

- 如果模型可能无法干净量化，先从 BF16 开始证明图支持。
- 如果 BF16 遇到 reCamera ION OOM，尝试 INT8 校准或更小的输入。
- 尊重模型架构约束。ViT 风格的模型通常需要维度能被 patch size 整除，例如 Depth Anything ViT 使用 `14` 的倍数。
- 将 `--input_shapes` 与导出的 ONNX 图匹配，通常是 NCHW 格式。使用融合 RGB 预处理时，reCamera 运行时输入可能仍报告为 packed NHWC `U8`。
- `--fuse_preprocess --customization_format RGB_PACKED` 使运行时输入为原始 `uint8` RGB NHWC。不要在 C++ 中喂入归一化的 float NCHW。
- 仅当后处理可以使用相对排序或 int8 logits（如 argmax/分类/分割掩码）时才使用 `--quant_output`。对于深度/回归/置信度阈值输出，除非重写后处理以处理量化输出，否则避免使用。
- 对于快速可行性测试，小型校准集是可以接受的；对于质量声明，使用来自目标摄像头域的代表性帧。

## PaddleOCR / Paddle Inference Notes

PaddleOCR 发布的 `*_infer` 包通常包含 `inference.pdmodel` 和 `inference.pdiparams`，需要先导出 ONNX，再进入 TPU-MLIR。`sophgo/tpuc_dev:v3.1` 中已有 `paddle2onnx`，即使 `paddle` Python 包因 `libssl.so.1.1` 不可导入，`paddle2onnx` CLI 仍可转换这些 inference 模型。

```bash
paddle2onnx --model_dir <infer_dir> \
  --model_filename inference.pdmodel \
  --params_filename inference.pdiparams \
  --opset_version 11 \
  --save_file <model>.onnx
```

PP-OCR 的 ONNX 常是动态 shape，转换 CVIMODEL 时必须固定：

- 中文检测模型常用 `--input_shapes [[1,3,640,640]]`，输出类似 `sigmoid_0.tmp_0`，DBNet 后处理需要概率图的绝对值，不要盲目开启 `--quant_output`。
- 中文识别模型常用 `--input_shapes [[1,3,48,320]]` 或更宽的 `[[1,3,48,640]]`，输出类似 `softmax_*.tmp_0`，CTC greedy decode 只依赖 argmax 时可以评估 `--quant_output`，但置信度语义会变化。
- PaddleOCR 标准预处理通常是 RGB、`mean 127.5,127.5,127.5`、`scale 0.0078125,0.0078125,0.0078125`，融合预处理后 reCamera C++ 侧应喂连续 `uint8` RGB NHWC。
- 检测模型如果 C++ 侧使用 letterbox，应在 TPU-MLIR 转换时也使用 `--keep_aspect_ratio --pad_value 128 --pad_type center`，否则坐标反算和 padding 语义会不一致。

当 ION 内存接近 cv181x 预算时，先尝试更小输入或 INT8；`--quant_output` 可以显著降低输出反量化内存，但只适合后处理不依赖绝对 float 置信度的模型。

## Depth Anything 实践记录

需要记住的实践结果：

- 使用的源检查点：`/home/steven/下载/depth_anything_v2_vits.pth`。
- 工作目录：`/home/steven/work/recamera_depth_anything`。
- `224x224` BF16 编译成功但在 reCamera 上失败，错误 `ion ioctl fail:: Out of memory`。
- `168x168` BF16 运行，NPU 时间约 `656 ms`。
- `224x224` INT8 使用 8 张图片的最小校准集运行：模型 `/home/steven/work/recamera_depth_anything/models/depth_anything_v2_vits_224_int8_min8.cvimodel`，单张图片约 `1494 ms`，实时摄像头 `1693 ms/frame`。
- 报告/证据：`/home/steven/work/recamera_depth_anything/DEPLOY_REPORT.md`，`/home/steven/下载/recamera_depth_anything_live_224_int8_jpeg/recamera_live_depth_anything_224_int8_jpeg.mp4`。

## Device Runtime Pattern For Custom Models

如果 `ModelFactory` 不支持任务类型，直接使用 `ma::engine::EngineCVI`：

- `engine->init()`;
- `engine->load(model_path)`;
- 检查输入/输出的 `shape`、`type`、`size` 和量化元数据;
- 填充输入张量;
- `engine->setInput(0, tensor)`;
- `engine->run()`;
- `engine->getOutput(0)`;
- 手动解码 `F32`、`BF16`、`S8` 和 `U8` 输出。

对于融合预处理的自定义模型，分配 CPU 打包的输入：

- `is_physical = false`;
- `tensor.data.data = rgb.data`;
- 确保连续的 `uint8` RGB NHWC 缓冲区匹配引擎输入形状，通常是 `[1,H,W,3]`。

对于消耗物理摄像头缓冲区的官方检测器 demo，`is_physical = true` 可能是有效的。不要将该路径与 CPU 解码的 JPEG 缓冲区混合使用。

## Camera Input And Visual Evidence

当直接的 RGB888 VPSS 帧被视为打包的 OpenCV RGB 时，可能在视觉上看起来不正确。对于需要可信视觉证据的自定义 demo：

- 将摄像头通道 `1` 配置为 `MA_PIXEL_FORMAT_JPEG`，例如 `640x480`;
- 检索 JPEG 帧并使用 `cv::imdecode` 解码;
- 调整大小到模型输入;
- 在 NPU 输入前转换 `BGR -> RGB`;
- 产生并排证据，如 `input | heatmap/mask/detections`;
- 在 reCamera 上保存帧，将其拉回到 PC/seeed，然后使用 `ffmpeg` 编码。

OpenCV 已经可以在 `sscma-example-sg200x` 中使用；只链接需要的部分，通常是 `opencv_core`、`opencv_imgcodecs` 和 `opencv_imgproc`。如果 OpenCV `cv` 与 `ma::cv` 冲突，使用 `::cv::`。

## C++ Build And Deployment Template

在 PC 上构建：

```bash
export SG200X_SDK_PATH=/home/steven/sg2002_recamera_emmc
export PATH=/home/steven/host-tools/gcc/riscv64-linux-musl-x86_64/bin:$PATH
cd /home/steven/sscma-example-sg200x/solutions/<demo_name>
cmake -B build -DCMAKE_BUILD_TYPE=Release .
cmake --build build -j$(nproc)
```

部署到 reCamera 上的任务目录，例如 `/home/recamera/<demo_name>`，然后在停止摄像头占用服务后使用 `sudo` 和标准 `LD_LIBRARY_PATH` 运行。

验证阶梯：

1. PyTorch/ONNX 导出加 ONNX Runtime 形状检查。
2. TPU-MLIR 编译为 `cvimodel`。
3. reCamera `EngineCVI` 加载/运行，打印形状、数据类型、计时和失败文本。
4. 来自摄像头或代表性输入的实际设备视觉产物。
5. 恢复服务/重启并验证 `http://192.168.42.1/api/version`。
