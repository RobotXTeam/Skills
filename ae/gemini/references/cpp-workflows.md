# C++ and Model Workflows

## Cross-Compile Baseline

reCamera normally lacks a native C/C++ build environment. Build on Linux, then copy the executable to reCamera.

Common environment:

```bash
export SG200X_SDK_PATH=/home/seeed/桌面/sg2002_recamera_emmc
export PATH=/home/seeed/桌面/host-tools/gcc/riscv64-linux-musl-x86_64/bin:$PATH
```

Build pattern:

```bash
cd /home/seeed/sscma-example-sg200x/solutions/<solution>
rm -rf build
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_FLAGS="-std=c++17" ..
make -j$(nproc)
```

Check binary:

```bash
file build/<binary>
```

Expected architecture is RISC-V/musl, not x86_64.

## Deploy Pattern

1. Create `/home/recamera/<demo>` on reCamera.
2. Copy executable, models, and scripts.
3. `chmod +x` executable.
4. Stop camera-owning services.
5. Run with explicit UDP target or HTTP port.
6. Capture logs and evidence.
7. Restart services unless the user wants the demo left running.

## UDP Face Analysis

Wiki: distilled directly in `SKILL.md` under `UDP_Face_Analysis`.

Local source/assets:

```text
/home/seeed/sscma-example-sg200x/solutions/sesg-project/face_udp/
  build/face_udp
  model/yolo-face_mixfp16.cvimodel
  model/age_gender_race_bf16.cvimodel
  model/emotion_bf16.cvimodel
  udp_receiver.py
```

Run on reCamera:

```bash
sudo env LD_LIBRARY_PATH=/mnt/system/lib:/mnt/system/usr/lib:/mnt/system/usr/lib/3rd:$LD_LIBRARY_PATH \
  ./face_udp yolo-face_mixfp16.cvimodel age_gender_race_bf16.cvimodel emotion_bf16.cvimodel \
  single 0.7 1 <receiver-ip> 5001 20
```

Expected terminal stats include video FPS, UDP FPS, YOLO timing, AGR/EMO timing, and UDP throughput.
For distant/side faces in Steven's office scene, `single 0.5 1` can be used to make visual validation more stable; record that parameter change in the QA report.

## YOLO Benchmark

Wiki: distilled directly in `SKILL.md` under `yolo_benchmark`.

Required assets from Google Drive:

- `recamera_benchmark`
- `yolo11n_detection_cv181x_int8.cvimodel`
- usually `yolo_udp.py`

Run on reCamera:

```bash
sudo env LD_LIBRARY_PATH=/mnt/system/lib:/mnt/system/usr/lib:/mnt/system/usr/lib/3rd:$LD_LIBRARY_PATH \
  ./recamera_benchmark ./yolo11n_detection_cv181x_int8.cvimodel <receiver-ip>
```

If the executable is not available locally or in the Drive folder, do not substitute a different program and claim the benchmark is reproduced. Use the C++ YOLO HTTP demo or on-device model only as an alternative and label it clearly.

## Real-Time YOLO HTTP C++ Demo

Wiki: distilled directly in `SKILL.md` under `Real_time_YOLO_object_detection_using_reCamera_based_on_Cpp`.

This is a separate C++ demo, not the same as `yolo_benchmark.md`. It returns detection JSON at:

```text
http://192.168.42.1/modeldetector
```

Use it when the user asks for C++ YOLO HTTP reproduction, not when they specifically ask for benchmark FPS.

## Gimbal C Development

Wiki: distilled directly in `SKILL.md` under `reCamera_Gimbal/gimbal_development_c`.

The C path uses `can-utils`, CAN bitrate `100000`, interface `can0`, and standard CAN frames. The wiki warns that C gimbal examples may be stale compared with motor firmware; prefer the latest motor CAN manual when precision matters.

## Autostart

Wiki: distilled directly in `SKILL.md` under `Make_the_Cpp_program_auto_start_on_boot`.

reCamera uses SysVinit. Add `S??` scripts under `/etc/init.d` only after a demo is proven stable and the user explicitly asks for boot persistence.
