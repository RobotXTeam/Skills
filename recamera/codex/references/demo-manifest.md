# Demo Manifest

Automation levels:

- L1: preflight only.
- L2: assets can be staged and command can be launched.
- L3: smoke-testable with logs/API/UDP packet.
- L4: visual or full end-to-end evidence can be captured.
- Blocked: requires unavailable hardware, credentials, or binary assets.

## Priority C++/System Demos

| Demo | Wiki | Type | Level | Notes |
|---|---|---:|---:|---|
| UDP Face Analysis | `Applications/UDP_Face_Analysis.md` | C++ + UDP video | L4 if frame captured | Local binary and models exist. Run receiver on `seeed`, sender on reCamera. |
| YOLO11n Benchmark | `Applications/yolo_benchmark.md` | C++ binary + UDP video | L4 | Requires Drive assets. `recamera_benchmark` hard-codes UDP port `5001` even though the wiki command only passes IP. |
| Real-time YOLO HTTP | `software_documents/Real_time_YOLO_object_detection_using_reCamera_based_on_Cpp.md` | C++ + HTTP | L3/L4 | Separate from benchmark. Needs `Realtime_detection_http.zip` and a YOLO `.cvimodel`. |
| Develop with C/C++ | `software_documents/develop_with_c_cpp.md` | C++ workflow | L3 | Use helloworld/video demo to verify toolchain. |
| Gimbal Deep C | `reCamera_Gimbal/gimbal_development_c.md` | C + CAN | L2/L3 | Requires gimbal hardware and care with stale motor protocol. |
| C++ Autostart | `software_documents/Make_the_Cpp_program_auto_start_on_boot.md` | SysVinit | L2 | Only apply after user asks for boot persistence. |

## Knowledge Docs

| Area | Wiki | Distilled Use |
|---|---|---|
| Quick start | `reCamera_2002_Series/quick_start_guide.md` | Network, web UI routes, USB/AP/Ethernet modes. |
| OS structure | `software_documents/os_structure.md` | Buildroot, supervisor, Node-RED/SSCMA services. |
| Linux basics | `software_documents/linux_fundamentals.md` | Device-side shell basics. |
| Static IP | `software_documents/configure_static_ip_on_recamera.md` | Network config tasks. |
| OS version control | `software_documents/os_version_control.md` | OTA/manual update tasks. |
| On-device models | `ai_model_deployment/on_device_model.md` | Official `.cvimodel` download links and class list. |
| Model conversion | `ai_model_deployment/model_conversion_guide.md`, `Custom_model_conversion.md` | YOLO/ONNX to CVI conversion planning. |
| Hardware/spec | `reCamera_2002_Series/hardware_and_spec.md`, `reCamera_HQ_POE/*`, `reCamera_Pro/*` | Device variant constraints. |

## Node-RED Deferred

Do not use these as runnable recipes yet:

- `software_documents/develop_with_nodered.md`
- `reCamera_Gimbal/gimbal_node_red.md`
- Most cloud/app integrations under `Applications/` that rely on Node-RED flows, cloud accounts, Telegram, WeChat Work, n8n, Home Assistant, Grafana, Stream Deck, Meshtastic, or OpenClaw.

They can be read as background only when the user specifically asks for them.

## Verified Findings on 2026-06-05

### UDP Face Analysis

Result: runs after fixes.

Wiki-as-written issues:

- It says stop Node-RED/SSCMA services, which is correct.
- It does not mention the required runtime library path: `LD_LIBRARY_PATH=/mnt/system/lib:/mnt/system/usr/lib:/mnt/system/usr/lib/3rd`.
- It does not explicitly say the binary should be run with `sudo`; without sudo, CVI runtime device memory initialization fails.
- The wiki example uses `multi`; Steven's available `yolo-face_mixfp16.cvimodel` requires `single`.
- The wiki omits the optional final `debug` parameter that exists in the local source usage.

Successful command shape:

```bash
SEEED_USB_IP="$(ip -4 -brief addr | awk '/192[.]168[.]42[.]/{sub(/\\/.*$/, "", $3); print $3; exit}')"
sudo env LD_LIBRARY_PATH=/mnt/system/lib:/mnt/system/usr/lib:/mnt/system/usr/lib/3rd:$LD_LIBRARY_PATH \
  ./face_udp yolo-face_mixfp16.cvimodel age_gender_race_bf16.cvimodel emotion_bf16.cvimodel \
  single 0.7 1 "$SEEED_USB_IP" 5001 20
```

Evidence:

- Official receiver video saved locally at `/home/steven/下载/recamera_udp_face_wiki_visual.mp4`.
- Runtime logs showed `UDP FPS` and YOLO timing. Face attribute output requires a clear face in the live camera view.

### YOLO11n Benchmark

Result: runs after standard environment fixes.

Wiki-as-written issues:

- Google Drive assets are accessible, but the wiki only shows a folder link and a screenshot; it does not name exact files in text.
- The executable requires `sudo` and the same `LD_LIBRARY_PATH` as other C++ camera demos.
- The second command argument is only the receiver IP. The UDP port is fixed internally to `5001`; receiver must listen on `5001`.
- The wiki says Windows terminal for `yolo_udp.py`; Linux/headless validation needs a save-frame receiver instead of `cv2.imshow`.

Successful command shape:

```bash
SEEED_USB_IP="$(ip -4 -brief addr | awk '/192[.]168[.]42[.]/{sub(/\\/.*$/, "", $3); print $3; exit}')"
sudo env LD_LIBRARY_PATH=/mnt/system/lib:/mnt/system/usr/lib:/mnt/system/usr/lib/3rd:$LD_LIBRARY_PATH \
  ./recamera_benchmark ./yolo11n_detection_cv181x_int8.cvimodel "$SEEED_USB_IP"
```

Evidence:

- Official receiver video saved locally at `/home/steven/下载/recamera_yolo_benchmark_wiki_visual.mp4`.
- Logs showed repeated detection timings around 49-58 ms total, matching the wiki's 50 ms / 20 FPS claim.
