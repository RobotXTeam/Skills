# Custom Model Conversion And NPU Demo Methodology

当用户要求将新的 PyTorch/ONNX 模型部署到 reCamera 的 NPU 或创建新的非 wiki demo 时使用此方法论。预期输出是一个可工作的 `cvimodel`、reCamera 侧的 C++ demo、真实设备证据和简短的部署报告。在模型在 reCamera 上加载并运行之前，不要将转换称为"已部署"。

## Supported Models

| 模型 | 任务 | 备注 |
|------|------|------|
| YOLO11n | detect / pose / seg / cls | pose 和 seg 需要 qtable |
| YOLO26n | detect / cls | pose/seg 不支持（Mod op） |
| BiSeNetv2 | 语义分割（Cityscapes） | 推荐 INT8+quant_output |
| PP-LiteSeg | 语义分割（Cityscapes） | 需要 ONNX graph surgery |
| PaddleOCR | 检测/识别 | 需先 paddle2onnx |
| Depth Anything | 深度估计 | ViT 架构，输入需 14 的倍数 |

不支持：YOLO26 pose/seg（Mod 操作不支持）、ONNX TopK/Argmax（CPU 后处理）。

## Conversion Scripts

预置脚本位于 skill 的 `scripts/` 目录：

```bash
# 通用转换
./convert_to_cvimodel.sh <onnx_file> <dataset_dir>

# 任务专用
./convert_yolo11_detect.sh <onnx> <dataset>
./convert_yolo11_pose.sh <onnx> <dataset>      # 需要 qtable
./convert_yolo11_seg.sh <onnx> <dataset>       # 需要 qtable
./convert_yolo11_cls.sh <onnx> <dataset>
./convert_yolo26_detect.sh <onnx> <dataset>
./convert_yolo26_cls.sh <onnx> <dataset>
./convert_bisenetv2.sh <onnx> <dataset>        # 输出 INT8 + BF16 + INT8_qout 三种
./convert_ppliteseg.sh <onnx> <dataset>        # 输出 INT8 + INT8_qout，自动 graph surgery
./batch_convert_all.sh                         # 批量转换当前目录所有 ONNX
```

## Host Conversion Baseline

首选转换栈：

- Docker 镜像：`sophgo/tpuc_dev:v3.1`。
- 将真实的本地 TPU-MLIR 安装挂载到容器的 `/workspace/tpu-mlir`；镜像的内置路径是空的，必须挂载。
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
      --input_shapes <shape> --mean <m0,m1,m2> --scale <s0,s1,s2> \
      --keep_aspect_ratio --pixel_format rgb --output_names <names> \
      --test_input <image> --mlir <name>.mlir
    run_calibration.py <name>.mlir --dataset calib --input_num 100 \
      -o <name>_cali_table
    model_deploy.py --mlir <name>.mlir --quantize INT8 \
      --calibration_table <name>_cali_table --chip cv181x \
      --fuse_preprocess --customization_format RGB_PACKED \
      --model <name>_cv181x_int8.cvimodel
  '
```

## Model-Specific Output Names

### YOLO11 Detection
```
--output_names /model.23/cv2.0/cv2.0.2/Conv_output_0,/model.23/cv3.0/cv3.0.2/Conv_output_0,/model.23/cv2.1/cv2.1.2/Conv_output_0,/model.23/cv3.1/cv3.1.2/Conv_output_0,/model.23/cv2.2/cv2.2.2/Conv_output_0,/model.23/cv3.2/cv3.2.2/Conv_output_0
```
顺序必须是 Box, Class, Box, Class, Box, Class 交替。

### YOLO26 Detection
```
--output_names /model.23/one2one_cv2.0/one2one_cv2.0.2/Conv_output_0,/model.23/one2one_cv3.0/one2one_cv3.0.2/Conv_output_0,/model.23/one2one_cv2.1/one2one_cv2.1.2/Conv_output_0,/model.23/one2one_cv3.1/one2one_cv3.1.2/Conv_output_0,/model.23/one2one_cv2.2/one2one_cv2.2.2/Conv_output_0,/model.23/one2one_cv3.2/one2one_cv3.2.2/Conv_output_0
```

### YOLO11 Segmentation / Pose
```
--output_names output0,output1    # seg
--output_names output0            # pose，加 --quantize_table yolo11n_pose_qtable
```

### BiSeNetv2
```
--output_names preds
--input_shapes [[1,3,512,1024]]
--mean 123.675,116.28,103.53 --scale 0.01712475,0.01750700,0.01742919
```

### PP-LiteSeg
```
--output_names p2o.pd_op.bilinear_interp.6.0
--input_shapes [[1,3,512,1024]]
--mean 123.675,116.28,103.53 --scale 0.01712475,0.01750700,0.01742919
```

## Conversion Decisions

- 如果模型可能无法干净量化，先从 BF16 开始证明图支持。
- 如果 BF16 遇到 reCamera ION OOM，尝试 INT8 校准或更小的输入。
- 尊重模型架构约束。ViT 风格的模型通常需要维度能被 patch size 整除，例如 Depth Anything ViT 使用 `14` 的倍数。
- 将 `--input_shapes` 与导出的 ONNX 图匹配，通常是 NCHW 格式。使用融合 RGB 预处理时，reCamera 运行时输入可能仍报告为 packed NHWC `U8`。
- `--fuse_preprocess --customization_format RGB_PACKED` 使运行时输入为原始 `uint8` RGB NHWC。不要在 C++ 中喂入归一化的 float NCHW。
- 对于快速可行性测试，小型校准集是可以接受的；对于质量声明，使用 100+ 来自目标摄像头域的代表性帧。

## ION Memory Optimization (--quant_output)

CV181x ION 内存由 TPU、VPSS、VENC 共享，总共约 60MB。INT8 模型如果输出 float32 会在片上反量化，消耗大量 ION。

使用 `--quant_output` 保持 int8 输出，避免反量化：

| 变体 | 模型大小 | ION 内存 | 输出类型 |
|------|----------|----------|----------|
| BiSeNetv2 BF16 | 14 MB | 87.59 MB | float32 |
| BiSeNetv2 INT8 | 6.0 MB | 62.89 MB | float32 |
| **BiSeNetv2 INT8_qout** | **5.9 MB** | **34.27 MB** | **int8** |
| PP-LiteSeg INT8 | 10.3 MB | 59.00 MB | float32 |
| **PP-LiteSeg INT8_qout** | **9.8 MB** | **26.73 MB** | **int8** |

**何时使用 `--quant_output`**：ION 内存紧张、后处理只需相对排序（argmax/分类/分割掩码）。

**何时不用**：需要绝对 float32 置信度值（如特定阈值的检测置信度）。

## Hybrid Quantization (qtable)

YOLO pose/seg 使用 qtable 实现混合量化，精度更好：

```bash
model_deploy.py ... --quantize_table yolo11n_pose_qtable \
  --model yolo11n-pose_cv181x_mix.cvimodel
```

## PP-LiteSeg ONNX Graph Surgery

PP-LiteSeg 转换前必须修改 ONNX 图（`convert_ppliteseg.sh` 自动处理）：

1. **移除 ArgMax + Cast 节点**：原始输出是 `[1,H,W] int32`（argmax 后的标签图），TPU-MLIR 需要 `[1,19,H,W] float32` 的 argmax 前 logits。
2. **修复 AveragePool `count_include_pad`**：PP-LiteSeg 有 5 个 AveragePool 的 `count_include_pad=0`，cv181x 要求 `=1`。
3. **本地预简化 ONNX**：Docker 内的 onnxsim 会引入损坏的 Squeeze ops，必须在宿主机先跑 `onnxsim`。

```python
import onnx, onnxsim
from onnx import TensorProto, helper

model = onnx.load("pp_liteseg.onnx")
# 找到最后一个 Resize 输出，添加为图输出
for node in model.graph.node:
    if node.op_type == 'Resize':
        resize_out = node.output[0]
new_out = helper.make_tensor_value_info(resize_out, TensorProto.FLOAT, [1, 19, 512, 1024])
model.graph.output.insert(0, new_out)
# 本地简化
model, check = onnxsim.simplify(model, test_input_shapes={'x': [1, 3, 512, 1024]})
# 修复 AveragePool
for node in model.graph.node:
    if node.op_type == 'AveragePool':
        for attr in node.attribute:
            if attr.name == 'count_include_pad':
                attr.i = 1
onnx.save(model, "pp_liteseg_prepared.onnx")
```

PP-LiteSeg cvimodel 被 sscma-model 检测为 `MA_MODEL_TYPE_BISENETV2`（type 17），可直接使用，但必须用 `RGB_PACKED` 格式。

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
export SG200X_SDK_PATH=/home/seeed/桌面/sg2002_recamera_emmc
export PATH=/home/seeed/桌面/host-tools/gcc/riscv64-linux-musl-x86_64/bin:$PATH
cd /home/seeed/sscma-example-sg200x/solutions/<demo_name>
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

## ONNX vs CVIMODEL Validation

转换后必须验证 ONNX 和 CVIMODEL 输出一致性：

```python
# ONNX 推理（标准 float32 流水线）
import onnxruntime as ort, numpy as np, cv2
sess = ort.InferenceSession("model.onnx")
img = cv2.imread("test.jpg")
img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
img_float = cv2.resize(img_rgb, (W, H)).astype(np.float32) / 255.0
img_norm = (img_float - mean) / std
img_nchw = np.transpose(img_norm, (2, 0, 1))[np.newaxis].astype(np.float32)
onnx_out = sess.run(None, {input_name: img_nchw})[0]

# CVIMODEL 推理（uint8 RGB，fuse_preprocess 处理归一化）
import pyruntime_cvi as cvi
model = cvi.Model("model_cv181x_int8_qout.cvimodel", output_all_tensors=True)
img_rgb2 = cv2.cvtColor(cv2.imread("test.jpg"), cv2.COLOR_BGR2RGB)
input_data = np.ascontiguousarray(cv2.resize(img_rgb2, (W, H)), dtype=np.uint8)
model.inputs[0].data[:] = input_data.reshape(model.inputs[0].data.shape)
model.forward()

# 对比
agreement = np.sum(label_onnx == label_cvi) / label_onnx.size * 100
print(f"Pixel agreement: {agreement:.2f}%")
```

已验证结果：
- BiSeNetv2：像素一致率 98-99%，ION 34.27MB，推理 436ms。
- PP-LiteSeg：像素一致率 92-96%，ION 26.73MB。

## Tested Conversions

| 模型 | ONNX | CVIMODEL | 命令 |
|------|------|----------|------|
| YOLO11n detect | 10.7 MB | 3.0 MB | `./convert_yolo11_detect.sh` |
| YOLO11n pose | 11.3 MB | 3.6 MB | `./convert_yolo11_pose.sh` |
| YOLO11n seg | 11.7 MB | 4.0 MB | `./convert_yolo11_seg.sh` |
| YOLO11n cls | 10.8 MB | 3.0 MB | `./convert_yolo11_cls.sh` |
| YOLO26n detect | 9.4 MB | 2.9 MB | `./convert_yolo26_detect.sh` |
| YOLO26n cls | 11.3 MB | 3.0 MB | `./convert_yolo26_cls.sh` |
| BiSeNetv2 seg | 13 MB | 5.9 MB (INT8_qout) | `./convert_bisenetv2.sh` |
| PP-LiteSeg seg | 32 MB | 9.8 MB (INT8_qout) | `./convert_ppliteseg.sh` |

## Troubleshooting

| 错误 | 原因 | 解决 |
|------|------|------|
| `operand xxx not found` (model_transform) | Docker onnxsim 引入损坏的 Squeeze ops | 宿主机先跑 onnxsim，不要在 Docker 里跑 |
| `AvgPooling2d: assertion count_include_pad=true` | PP-LiteSeg AveragePool 的 count_include_pad=0 | 转换前修复所有 AveragePool 节点 |
| `Op not support: Mod` | YOLO26 pose/seg 使用 Mod 操作 | 改用 YOLO11 |
| `model_transform: command not found` | TPU-MLIR 环境未初始化 | 容器内 `source /workspace/tpu-mlir/envsetup.sh` |
| 输出顺序错误/检测结果异常 | detection outputs 未按 Box,Class 交替排列 | 确保 6 个输出按 Box,Class,Box,Class,Box,Class 排序 |
| ION 内存超限 | INT8 输出被反量化为 float32 | 加 `--quant_output` |
| CVIMODEL 结果完全错误 | 输入预处理不匹配 | 确保 fuse_preprocess 接收 uint8 RGB NHWC，不是 float32 NCHW |
| `/workspace/tpu-mlir` 为空 | 本地 TPU-MLIR 未挂载 | `-v /path/to/tpu-mlir:/workspace/tpu-mlir` |
| sscma-model 输出是 bbox 而非分割 | cvimodel 用 RGB_PLANAR 但 sscma-model 喂 HWC | 改用 `--customization_format RGB_PACKED` |

## Quick ONNX Export

```python
from ultralytics import YOLO
YOLO('yolo11n.pt').export(format='onnx', imgsz=640, simplify=False, opset=12)     # Detection
YOLO('yolo11n-cls.pt').export(format='onnx', imgsz=224, simplify=False, opset=12)  # Classification
YOLO('yolo11n-pose.pt').export(format='onnx', imgsz=640, simplify=False, opset=12) # Pose
YOLO('yolo11n-seg.pt').export(format='onnx', imgsz=640, simplify=False, opset=12)  # Segmentation
```

## Key Points

1. YOLO26 pose/seg 不支持，用 YOLO11。
2. Detection 需要 6 个交替输出：Box, Class, Box, Class, Box, Class。
3. BiSeNetv2 用 ImageNet 预处理，mean/scale 不同于 YOLO。
4. PP-LiteSeg 需要 ONNX graph surgery（移除 ArgMax/Cast，修复 AveragePool，本地预简化）。
5. Docker 内不要跑 onnxsim，宿主机先跑。
6. ION 紧张用 `--quant_output`（PP-LiteSeg 59→27MB，BiSeNetV2 63→34MB）。
7. sscma-model 兼容用 `RGB_PACKED`。
8. 必须挂载本地 tpu-mlir 到 Docker。
9. fuse_preprocess 后模型期望 uint8 RGB NHWC 输入。
10. YOLO pose/seg 用 qtable 混合量化。
11. 生产用 100+ 校准图片。
12. 转换后必须验证 ONNX vs CVIMODEL 像素一致率。
