---
name: recamera
description: "QA-verify Seeed reCamera wiki pages and build reCamera NPU demos on Steven's stable seeed + reCamera setup: SSH into seeed/reCamera, understand the wiki, run demos as written, convert PyTorch/ONNX models to CVIMODEL, write C++ SG200X demos, capture official/device evidence, and output reproducibility scores. Trigger when the user mentions reCamera, reCamera wiki validation, reCamera demos, custom model conversion, Depth Anything, YOLO benchmark, UDP Face Analysis, C++ development on reCamera, SG200X, CVI models, TPU-MLIR, or asks to replicate/score a reCamera wiki."
---

# reCamera Wiki QA Verifier

## Purpose

This skill exists to judge how reproducible Seeed reCamera wiki pages are.

The goal is not only to "make the demo work." The goal is to evaluate the wiki:

- If the wiki runs as written, the wiki is excellent.
- If it fails as written but works after reasonable fixes, the wiki is usable but needs improvement.
- If it still cannot be reproduced after serious debugging, the wiki is failed/shit-level for reproducibility.

Always separate:

- what the wiki says;
- what happened when following it directly;
- what fixes were needed;
- whether the final expected output was reproduced;
- evidence paths;
- wiki writing/reproducibility score.

Do not replace wiki/repository visuals with custom renderer code. For visual demos, use the official wiki/repo/Drive receiver scripts and record their actual output.

## Fixed Environment

Use this skill with the `ssh` skill when device access is needed.

- PC -> `seeed`: SSH alias `seeed`, user `seeed`, password `0`.
- seeed LAN: `192.168.4.7`.
- seeed Tailscale: `100.76.45.91`.
- seeed OS: Ubuntu 22.04.
- `seeed` -> reCamera: direct USB/LAN `192.168.42.1`.
- reCamera SSH: user `recamera`, password `recamera.1`.
- reCamera OS API: `http://192.168.42.1/api/version`, last verified `0.2.3`.
- reCamera OS: Buildroot 2021.05, Linux 5.10.4 RISC-V.
- Local C++ demo repo: `/home/steven/sscma-example-sg200x`.
- Local SG200X SDK: `/home/steven/sg2002_recamera_emmc`.
- Local cross compiler: `/home/steven/host-tools/gcc/riscv64-linux-musl-x86_64/bin/riscv64-unknown-linux-musl-gcc`.
- Xvfb and ffmpeg are installed on `seeed` for OpenCV receiver recording.

Important: seeed's USB IP on `192.168.42.0/24` changes after reCamera reboot or USB reconnect. Never hard-code old values like `192.168.42.197`. Always run:

```bash
/home/steven/.codex/skills/recamera/scripts/seeed_usb_ip.sh
```

## Helper Scripts

- `scripts/preflight.sh`: verifies seeed, reCamera HTTP/SSH, OS, disk, services, and local toolchain.
- `scripts/recamera_ssh.sh 'cmd'`: runs non-interactive commands on reCamera through seeed.
- `scripts/recamera_scp_to.sh LOCAL... REMOTE_PATH`: copies files to reCamera through seeed.
- `scripts/seeed_usb_ip.sh`: prints current seeed USB IP in `192.168.42.0/24`.

## Standard QA Workflow

1. Run `scripts/preflight.sh`.
2. Read the user's requested wiki/page text if provided or live. For already distilled pages, use the capability map below.
3. Attempt the wiki's steps as written first. Record exact command and exact failure.
4. If C++ camera access is involved:
   - stop camera-owning services;
   - use current seeed USB IP;
   - use `sudo`;
   - set `LD_LIBRARY_PATH=/mnt/system/lib:/mnt/system/usr/lib:/mnt/system/usr/lib/3rd`.
5. If Python/OpenCV UDP receiver is involved:
   - use the official receiver script from wiki/repo/Drive;
   - run it on `seeed`;
   - use Xvfb when SSH/headless;
   - record actual window via `ffmpeg x11grab`.
6. Apply fixes only after recording direct-wiki failure.
7. Collect evidence: sender logs, receiver logs, video/screenshot/frame, HTTP output, artifacts and exact command lines.
8. Restore services or reboot reCamera after camera demos.
9. Output a report and score.

## C++ Camera Runtime Baseline

Stop services before C++ camera demos:

```bash
/home/steven/.codex/skills/recamera/scripts/recamera_ssh.sh "printf 'recamera.1\n' | sudo -S /etc/init.d/S03node-red stop || true; printf 'recamera.1\n' | sudo -S /etc/init.d/S91sscma-node stop || true; printf 'recamera.1\n' | sudo -S /etc/init.d/S93sscma-supervisor stop || true"
```

Use this runtime library path:

```bash
LD_LIBRARY_PATH=/mnt/system/lib:/mnt/system/usr/lib:/mnt/system/usr/lib/3rd:$LD_LIBRARY_PATH
```

Restore by rebooting after aggressive process cleanup:

```bash
/home/steven/.codex/skills/recamera/scripts/recamera_ssh.sh "printf 'recamera.1\n' | sudo -S reboot"
```

Then verify:

```bash
sshpass -p 0 ssh seeed 'curl -s --max-time 5 http://192.168.42.1/api/version'
```

## Custom Model Conversion And NPU Demo Methodology

Use this when the user asks to deploy a new PyTorch/ONNX model onto reCamera's NPU or create a new non-wiki demo. The expected output is a working `cvimodel`, a reCamera-side C++ demo, real device evidence, and a short deployment report. Do not call a conversion "deployed" until it loads and runs on reCamera.

### Host Conversion Baseline

Preferred conversion stack:

- Docker image: `sophgo/tpuc_dev:v3.1`.
- Mount a real local TPU-MLIR install into the container at `/workspace/tpu-mlir`; the image's built-in path may be empty.
- Use `model_transform.py`, `run_calibration.py`, and `model_deploy.py`.
- Keep work under a task directory such as `/home/steven/work/recamera_<model>`.

Command shape:

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

Conversion decisions:

- Start with BF16 to prove graph support if the model may not quantize cleanly.
- If BF16 hits reCamera ION OOM, try INT8 calibration or a smaller input.
- Respect model architecture constraints. ViT-style models often need dimensions divisible by patch size, e.g. Depth Anything ViT uses multiples of `14`.
- Match `--input_shapes` to the exported ONNX graph, commonly NCHW for upstream models. With fused RGB preprocess, the reCamera runtime input may still be reported as packed NHWC `U8`.
- `--fuse_preprocess --customization_format RGB_PACKED` makes the runtime input raw `uint8` RGB NHWC. Do not feed normalized float NCHW in C++.
- Use `--quant_output` only when postprocess can use relative ordering or int8 logits, such as argmax/classification/segmentation masks. Avoid it for depth/regression/confidence-threshold outputs unless postprocess is rewritten for quantized outputs.
- A tiny calibration set is acceptable for a quick feasibility pass; for a quality claim, use representative frames from the target camera domain.

Depth Anything practical result to remember:

- Source checkpoint used: `/home/steven/下载/depth_anything_v2_vits.pth`.
- Workdir: `/home/steven/work/recamera_depth_anything`.
- `224x224` BF16 compiled but failed on reCamera with `ion ioctl fail:: Out of memory`.
- `168x168` BF16 ran, about `656 ms` NPU time.
- `224x224` INT8 with an 8-image minimal calibration set ran: model `/home/steven/work/recamera_depth_anything/models/depth_anything_v2_vits_224_int8_min8.cvimodel`, about `1494 ms` single-image and `1693 ms/frame` live camera.
- Report/evidence: `/home/steven/work/recamera_depth_anything/DEPLOY_REPORT.md`, `/home/steven/下载/recamera_depth_anything_live_224_int8_jpeg/recamera_live_depth_anything_224_int8_jpeg.mp4`.

### Device Runtime Pattern For Custom Models

If `ModelFactory` does not support the task type, use `ma::engine::EngineCVI` directly:

- `engine->init()`;
- `engine->load(model_path)`;
- inspect input/output `shape`, `type`, `size`, and quantization metadata;
- fill input tensor;
- `engine->setInput(0, tensor)`;
- `engine->run()`;
- `engine->getOutput(0)`;
- manually decode `F32`, `BF16`, `S8`, and `U8` outputs.

For fused-preprocess custom models, allocate CPU-packed input:

- `is_physical = false`;
- `tensor.data.data = rgb.data`;
- ensure contiguous `uint8` RGB NHWC buffer matching the engine input shape, commonly `[1,H,W,3]`.

For official detector demos that consume physical camera buffers, `is_physical = true` can be valid. Do not mix that path with CPU-decoded JPEG buffers.

### Camera Input And Visual Evidence

Direct RGB888 VPSS frames can look visually wrong when treated as packed OpenCV RGB. For custom demos that need trustworthy visual evidence:

- configure camera channel `1` as `MA_PIXEL_FORMAT_JPEG`, e.g. `640x480`;
- retrieve JPEG frames and decode with `cv::imdecode`;
- resize to model input;
- convert `BGR -> RGB` before NPU input;
- produce side-by-side evidence such as `input | heatmap/mask/detections`;
- save frames on reCamera, pull them back to the PC/seeed, then encode with `ffmpeg`.

OpenCV is already usable in `sscma-example-sg200x`; link only what is needed, usually `opencv_core`, `opencv_imgcodecs`, and `opencv_imgproc`. If OpenCV `cv` conflicts with `ma::cv`, use `::cv::`.

### C++ Build And Deployment Template

Build on the PC:

```bash
export SG200X_SDK_PATH=/home/steven/sg2002_recamera_emmc
export PATH=/home/steven/host-tools/gcc/riscv64-linux-musl-x86_64/bin:$PATH
cd /home/steven/sscma-example-sg200x/solutions/<demo_name>
cmake -B build -DCMAKE_BUILD_TYPE=Release .
cmake --build build -j$(nproc)
```

Deploy to a task directory on reCamera, for example `/home/recamera/<demo_name>`, then run with `sudo` and the standard `LD_LIBRARY_PATH` after stopping camera-owning services.

Validation ladder:

1. PyTorch/ONNX export plus ONNX Runtime shape check.
2. TPU-MLIR compile to `cvimodel`.
3. reCamera `EngineCVI` load/run with printed shapes, dtypes, timings, and failure text.
4. Actual device visual artifact from camera or representative input.
5. Restore services/reboot and verify `http://192.168.42.1/api/version`.

## Official Receiver Recording

On `seeed`, run official receiver scripts under Xvfb:

```bash
sshpass -p 0 ssh seeed 'nohup Xvfb :99 -screen 0 1280x720x24 >/tmp/recamera_xvfb.log 2>&1 & echo $! >/tmp/recamera_xvfb.pid'
sshpass -p 0 ssh seeed 'cd /home/seeed/recamera_wiki_recording && DISPLAY=:99 python3 -u ./udp_receiver.py'
sshpass -p 0 ssh seeed 'DISPLAY=:99 xwininfo -root -tree'
sshpass -p 0 ssh seeed 'ffmpeg -y -f x11grab -draw_mouse 0 -video_size 640x700 -framerate 24 -i :99.0+0,0 -t 30 out.mp4'
```

Use the actual window size/position from `xwininfo`. For the tested OpenCV Qt windows, `640x700+0+0` was correct.

## Scoring Rubric

- 9-10: runs as written. Minor wording/polish only.
- 7-8: runs after small obvious fixes, such as receiver IP, port clarification, or Linux receiver command.
- 5-6: runs only after nontrivial fixes such as missing `sudo`, missing library path, wrong model head, undocumented assets, or headless display workaround.
- 3-4: partial; program starts but expected output cannot be reproduced or evidence is weak.
- 1-2: failed/shit-level reproducibility; reasonable debugging exhausted or essential assets/hardware/credentials are undocumented/unavailable.

## Report Template

```markdown
## Wiki QA Report: <title>

Source:
- Wiki file / URL:
- Tested on:

Result:
- Direct wiki run:
- Final run after fixes:
- Score:

Evidence:
- Logs:
- Video/screenshot/frame:
- Device artifacts:

Direct-run findings:
- ...

Fixes applied:
- ...

What the wiki should change:
- ...

Verdict:
- ...
```

## Distilled Wiki Capability Map

This is the distilled knowledge from the reCamera wiki set. It is intentionally not a raw copy of the wiki. Use it to know what capability to exercise and how to verify it.

### Applications

`AI_Human_Detection_Meshtastic_Broadcast`
- Capability: human detection plus Meshtastic broadcast and UDP preview.
- Validate: local vision/UDP first; Meshtastic requires radio hardware and serial config.
- Score separately for vision and radio integration.

`AI_Remote_Wireless_Monitor_System`
- Capability: remote monitoring workflow.
- Validate: network path, cloud/remote prerequisites, camera stream, and credential clarity.

`Car_parking_management`
- Capability: parking detection/application workflow.
- Validate: required model/assets, camera scene, detection result, and output channel.

`Getting_started_for_Home_Assistant`
- Capability: Home Assistant integration.
- Validate: HA instance/version, endpoint, token, imported entity, and camera/event visibility.
- Missing HA credentials means `blocked`, not direct wiki fail.

`Getting_started_for_n8n`
- Capability: n8n workflow integration.
- Validate: n8n account/self-hosted instance, webhook, workflow import, test event.

`Getting_started_in_Telegram`
- Capability: Telegram bot integration.
- Validate: bot token/chat ID and message/image delivery.
- Missing credentials means `blocked`.

`Getting_started_in_Wechat_work`
- Capability: WeChat Work integration.
- Validate: enterprise app credentials/webhook and message delivery.
- Missing credentials means `blocked`.

`Integration_of_real-time_heat_map_with_Grafana_data_dashboard`
- Capability: Grafana dashboard integration.
- Validate: data source, dashboard import, live data feed, and heat map update.

`OpenClaw_reCamera-Gimbal`
- Capability: reCamera Gimbal plus OpenClaw control.
- Validate: gimbal/claw hardware, command path, movement evidence, and safety.

`UDP_Face_Analysis`
- Capability: C++ face detection plus age/gender/race/emotion and UDP receiver.
- Known result: pass with fixes, score 6/10.
- Assets: `/home/steven/sscma-example-sg200x/solutions/sesg-project/face_udp`.
- Official receiver: `udp_receiver.py`.
- Working command shape:

```bash
SEEED_USB_IP="$(/home/steven/.codex/skills/recamera/scripts/seeed_usb_ip.sh)"
sudo env LD_LIBRARY_PATH=/mnt/system/lib:/mnt/system/usr/lib:/mnt/system/usr/lib/3rd:$LD_LIBRARY_PATH \
  ./face_udp yolo-face_mixfp16.cvimodel age_gender_race_bf16.cvimodel emotion_bf16.cvimodel \
  single 0.7 1 "$SEEED_USB_IP" 5001 20
```

- For Steven's current distant/side-face office scene, `single 0.5 1` produced stable visual detection.
- Evidence from latest run: `/home/steven/下载/recamera_udp_face_wiki_visual.mp4`.
- Wiki issues found: missing `sudo`, missing `LD_LIBRARY_PATH`, unclear `single` vs `multi`, receiver/headless instructions incomplete, model filename typo risk.

`Use_the_body-sensing_function`
- Capability: body sensing feature.
- Validate: identify whether built-in Node-RED/model flow or C++ path; verify event output and UI/stream evidence.

`Using_Stream_Deck_to_control_reCamera_Gimbal`
- Capability: Stream Deck controls gimbal.
- Validate: Stream Deck hardware/software, gimbal hardware, action mapping, and movement evidence.

`reCamera_reSpeaker`
- Capability: reSpeaker integration.
- Validate: reSpeaker hardware, audio device detection, command/audio path.

`yolo_benchmark`
- Capability: YOLO11n detection/segmentation benchmark plus UDP receiver.
- Known result: pass with fixes, score 7/10.
- Assets from Drive: `recamera_benchmark`, `yolo11n_detection_cv181x_int8.cvimodel`, `yolo11n_segment_cv181x_int8.cvimodel`, `yolo_udp.py`.
- Official receiver: `yolo_udp.py`, fixed UDP port `5001`.
- Working command shape:

```bash
SEEED_USB_IP="$(/home/steven/.codex/skills/recamera/scripts/seeed_usb_ip.sh)"
sudo env LD_LIBRARY_PATH=/mnt/system/lib:/mnt/system/usr/lib:/mnt/system/usr/lib/3rd:$LD_LIBRARY_PATH \
  ./recamera_benchmark ./yolo11n_detection_cv181x_int8.cvimodel "$SEEED_USB_IP"
```

- Evidence from latest run: `/home/steven/下载/recamera_yolo_benchmark_wiki_visual.mp4`.
- Wiki issues found: Drive files not named in text, missing `sudo`, missing `LD_LIBRARY_PATH`, fixed port `5001` not documented clearly, Linux/headless receiver path missing, receiver IP must be rechecked after reboot.

### AI Model Deployment

`Custom_model_conversion`
- Capability: convert custom model to `.cvimodel`.
- Validate: host tools, model format, input size, calibration data, conversion command, final deployment and inference on reCamera.
- Do not claim reproduced unless conversion actually ran.

`model_conversion_guide`
- Capability: general model conversion reference.
- Validate: at least one full conversion path before scoring as runnable.
- Check whether calibration, quantization, and deployment steps are precise.

`on_device_model`
- Capability: deploy/use model on device.
- Validate: upload path, UI/Node-RED model selection, service restart, and inference output.

### Hardware And Product Docs

`reCamera_2002_Series/hardware_and_spec`
- Capability: hardware/spec reference.
- Validate: content consistency against actual device, ports, storage, camera, OS endpoint.

`reCamera_2002_Series/quick_start_guide`
- Capability: first boot/setup.
- Validate: power, USB/network, web UI init, SSH, and version endpoint.

`reCamera_2002_Series/reCamera_warranty`
- Capability: warranty/reference.
- Validate: content clarity and links; not a runnable demo.

`reCamera_Gimbal/get_started`
- Capability: gimbal setup.
- Validate: requires gimbal hardware; verify UI/control movement and service status.

`reCamera_Gimbal/gimbal_development_c`
- Capability: C gimbal CAN development.
- Validate: CAN interface, bitrate `100000`, frame format, command logs, and movement.

`reCamera_Gimbal/gimbal_node_red`
- Capability: gimbal Node-RED flow.
- Validate: flow import and movement if hardware exists.

`reCamera_Gimbal/PID_adjustment`
- Capability: gimbal tuning.
- Validate: hardware present, safe test procedure, parameter changes, movement result.

`reCamera_Gimbal/hardware_and_spec`
- Capability: gimbal hardware/spec reference.
- Validate: content QA unless hardware present.

`reCamera_HQ_POE/reCamera_hq_poe_start`
- Capability: HQ PoE quick start.
- Validate: only on HQ PoE hardware; otherwise hardware-blocked.

`reCamera_HQ_POE/reCamera_hq_poe_hardware`
- Capability: HQ PoE specs.
- Validate: content QA unless hardware present.

`reCamera_HQ_POE/reCamera_hq_poe_microscope_demo`
- Capability: microscope demo.
- Validate: requires HQ PoE and microscope setup; verify image stream/sample capture.

`reCamera_Pro/reCamera_Pro_Getting_Start`
- Capability: reCamera Pro setup.
- Validate: only on Pro hardware; otherwise hardware-blocked.

### Software Documents

`develop_with_c_cpp`
- Capability: C/C++ development baseline.
- Validate: toolchain, SDK path, sample build, deployment, runtime command.

`Real_time_YOLO_object_detection_using_reCamera_based_on_Cpp`
- Capability: C++ YOLO HTTP/API demo.
- Validate: build/deploy model detector, stop services, run with env, verify `http://192.168.42.1/modeldetector` JSON.

`Make_the_Cpp_program_auto_start_on_boot`
- Capability: SysVinit autostart.
- Validate only after demo is stable and user asks. Check script order, permissions, reboot behavior.

`configure_static_ip_on_recamera`
- Capability: network config.
- High risk. Backup config, verify current network, preserve SSH recovery path, apply only if requested.

`develop_with_nodered`
- Capability: Node-RED development.
- Validate: Node-RED UI, flow import/export, required nodes, service restart.

`linux_fundamentals`
- Capability: basic Linux usage.
- Validate: content QA or run commands if requested.

`os_structure`
- Capability: reCamera OS structure.
- Validate: filesystem paths, services, model locations, overlay/userdata behavior.

`os_version_control`
- Capability: OS update/version.
- High risk. Verify version endpoint and update path; do not upgrade unless requested.

`reCamera_connects_to_Xiao_via_HTTP`
- Capability: HTTP integration with XIAO.
- Validate: XIAO hardware/network, endpoint, request format, received action.

### FAQ

`faqs`
- Capability: troubleshooting/reference.
- Validate claims against actual device when relevant.

## Known Reports

Validated on 2026-06-05:

- UDP Face Analysis: direct wiki failed; final pass with fixes; score 6/10.
- YOLO11n Benchmark: direct Linux reproduction partial/fail; final pass with fixes; score 7/10.

Detailed report is in `references/reports-2026-06-05.md` and standalone output `/home/steven/下载/recamera_wiki_qa_score_report.md`.

## Guardrails

- Do not use `agent-reach` unless the user explicitly asks.
- Do not delete `/etc/init.d/S91sscma-node` or `/etc/init.d/S93sscma-supervisor` just because a wiki says so.
- Stop services for tests; reboot or restart services afterward.
- Back up before overwriting device files under `/home/recamera/demo-backups/YYYYMMDD-HHMMSS`.
- Node-RED/cloud demos may be blocked by missing credentials/hardware; report blockers precisely.
- For current/changed wiki pages, read the page text first, then use this distilled skill to reproduce and score it.
