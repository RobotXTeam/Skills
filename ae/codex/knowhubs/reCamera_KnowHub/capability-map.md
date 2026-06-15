# Distilled Wiki Capability Map

这是从 reCamera wiki 集合中蒸馏的知识。它有意不是 wiki 的原始副本。使用它来了解要执行什么能力以及如何验证它。

## Repository Locations

### 本机环境

- 工作目录：`~/work/reCamera_demo/<demo_name>/`
- 仓库目录：`/home/seeed/sscma-example-sg200x/solutions/sesg-project/<demo_name>/`
- Claude skills：`~/.claude/skills/ae/`

现有 demo：
- `~/work/reCamera_demo/depth_anything/` - Depth Anything 深度估计
- `~/work/reCamera_demo/ppocr_v4/` - PP-OCRv4 文字识别

### seeed 设备环境

- 工作目录：`~/reCamera_demo/<demo_name>/`
- 仓库目录：`/home/seeed/sscma-example-sg200x/solutions/sesg-project/<demo_name>/`
- 远程：`https://github.com/RobotXTeam/sscma-example-sg200x.git`
- 认证：GitHub CLI（用户 congchin38-coder）
- 代理：需要配置 `http://127.0.0.1:7890`（Clash）

### 同步流程

开发完成后，将本地仓库同步到 seeed，再推送到 GitHub：

```bash
# 1. 本机同步到 seeed
rsync -avz --exclude='.git' --exclude='*.cvimodel' --exclude='*.onnx' \
  ~/work/reCamera_demo/<demo_name>/ seeed:~/reCamera_demo/<demo_name>/

# 2. seeed 上复制到仓库
ssh seeed "
  cd /home/seeed/sscma-example-sg200x
  mkdir -p solutions/sesg-project/<demo_name>/wiki
  mkdir -p solutions/sesg-project/<demo_name>/evidence
  cp ~/reCamera_demo/<demo_name>/<demo_name>_Demo_Wiki.md solutions/sesg-project/<demo_name>/wiki/
  cp ~/reCamera_demo/<demo_name>/DEPLOY_REPORT.md solutions/sesg-project/<demo_name>/wiki/
  cp ~/reCamera_demo/<demo_name>/evidence/frame_*.png solutions/sesg-project/<demo_name>/evidence/
"

# 3. seeed 上提交并推送
ssh seeed "
  cd /home/seeed/sscma-example-sg200x
  git add solutions/sesg-project/<demo_name>/
  git commit -m 'Add <demo_name> demo with wiki and evidence'
  git push origin main
"
```

## Applications

`AI_Human_Detection_Meshtastic_Broadcast`
- 能力：人体检测加 Meshtastic 广播和 UDP 预览。
- 验证：先本地视觉/UDP；Meshtastic 需要无线电硬件和串口配置。
- 分别为视觉和无线电集成评分。

`AI_Remote_Wireless_Monitor_System`
- 能力：远程监控工作流。
- 验证：网络路径、云/远程前置条件、摄像头流和凭据清晰度。

`Car_parking_management`
- 能力：停车检测/应用工作流。
- 验证：所需模型/资产、摄像头场景、检测结果和输出通道。

`Getting_started_for_Home_Assistant`
- 能力：Home Assistant 集成。
- 验证：HA 实例/版本、端点、令牌、导入的实体和摄像头/事件可见性。
- 缺少 HA 凭据意味着 `blocked`，而不是直接 wiki 失败。

`Getting_started_for_n8n`
- 能力：n8n 工作流集成。
- 验证：n8n 账户/自托管实例、webhook、工作流导入、测试事件。

`Getting_started_in_Telegram`
- 能力：Telegram 机器人集成。
- 验证：机器人令牌/聊天 ID 和消息/图片传递。
- 缺少凭据意味着 `blocked`。

`Getting_started_in_Wechat_work`
- 能力：企业微信集成。
- 验证：企业应用凭据/webhook 和消息传递。
- 缺少凭据意味着 `blocked`。

`Integration_of_real-time_heat_map_with_Grafana_data_dashboard`
- 能力：Grafana 仪表板集成。
- 验证：数据源、仪表板导入、实时数据馈送和热图更新。

`OpenClaw_reCamera-Gimbal`
- 能力：reCamera Gimbal 加 OpenClaw 控制。
- 验证：云台/夹爪硬件、命令路径、运动证据和安全。

`UDP_Face_Analysis`
- 能力：C++ 人脸检测加年龄/性别/种族/情绪和 UDP 接收器。
- 已知结果：修复后通过，评分 6/10。
- 资产：`/home/seeed/sscma-example-sg200x/solutions/sesg-project/face_udp`。
- 官方接收器：`udp_receiver.py`。
- 工作命令模板：

```bash
SEEED_USB_IP="$(/home/steven/.claude/skills/ae/environments/seeed-recamera/scripts/seeed_usb_ip.sh)"
sudo env LD_LIBRARY_PATH=/mnt/system/lib:/mnt/system/usr/lib:/mnt/system/usr/lib/3rd:$LD_LIBRARY_PATH \
  ./face_udp yolo-face_mixfp16.cvimodel age_gender_race_bf16.cvimodel emotion_bf16.cvimodel \
  single 0.7 1 "$SEEED_USB_IP" 5001 20
```

- 对于 Steven 当前的远距离/侧面面部办公室场景，`single 0.5 1` 产生了稳定的视觉检测。
- 最新运行的证据：`/home/steven/下载/recamera_udp_face_wiki_visual.mp4`。
- 发现的 wiki 问题：缺少 `sudo`、缺少 `LD_LIBRARY_PATH`、不清晰的 `single` vs `multi`、接收器/headless 说明不完整、模型文件名拼写错误风险。

`Use_the_body-sensing_function`
- 能力：人体感应功能。
- 验证：识别是内置 Node-RED/模型流还是 C++ 路径；验证事件输出和 UI/流证据。

`Using_Stream_Deck_to_control_reCamera_Gimbal`
- 能力：Stream Deck 控制云台。
- 验证：Stream Deck 硬件/软件、云台硬件、动作映射和运动证据。

`reCamera_reSpeaker`
- 能力：reSpeaker 集成。
- 验证：reSpeaker 硬件、音频设备检测、命令/音频路径。

`yolo_benchmark`
- 能力：YOLO11n 检测/分割基准加 UDP 接收器。
- 已知结果：修复后通过，评分 7/10。
- Drive 资产：`recamera_benchmark`、`yolo11n_detection_cv181x_int8.cvimodel`、`yolo11n_segment_cv181x_int8.cvimodel`、`yolo_udp.py`。
- 官方接收器：`yolo_udp.py`，固定 UDP 端口 `5001`。
- 工作命令模板：

```bash
SEEED_USB_IP="$(/home/steven/.claude/skills/ae/environments/seeed-recamera/scripts/seeed_usb_ip.sh)"
sudo env LD_LIBRARY_PATH=/mnt/system/lib:/mnt/system/usr/lib:/mnt/system/usr/lib/3rd:$LD_LIBRARY_PATH \
  ./recamera_benchmark ./yolo11n_detection_cv181x_int8.cvimodel "$SEEED_USB_IP"
```

- 最新运行的证据：`/home/steven/下载/recamera_yolo_benchmark_wiki_visual.mp4`。
- 发现的 wiki 问题：Drive 文件未在文本中命名、缺少 `sudo`、缺少 `LD_LIBRARY_PATH`、固定端口 `5001` 文档不清楚、Linux/headless 接收器路径缺失、接收器 IP 重启后必须重新检查。

## AI Model Deployment

`Custom_model_conversion`
- 能力：将自定义模型转换为 `.cvimodel`。
- 验证：主机工具、模型格式、输入大小、校准数据、转换命令、最终在 reCamera 上部署和推理。
- 除非转换实际运行，否则不要声称已复制。

`model_conversion_guide`
- 能力：通用模型转换参考。
- 验证：在评分可运行之前至少有一个完整转换路径。
- 检查校准、量化和部署步骤是否精确。

`on_device_model`
- 能力：在设备上部署/使用模型。
- 验证：上传路径、UI/Node-RED 模型选择、服务重启和推理输出。

## Hardware And Product Docs

`reCamera_2002_Series/hardware_and_spec`
- 能力：硬件/规格参考。
- 验证：内容与实际设备、端口、存储、摄像头、OS 端点的一致性。

`reCamera_2002_Series/quick_start_guide`
- 能力：首次启动/设置。
- 验证：电源、USB/网络、Web UI 初始化、SSH 和版本端点。

`reCamera_2002_Series/reCamera_warranty`
- 能力：保修/参考。
- 验证：内容清晰度和链接；不是可运行的 demo。

`reCamera_Gimbal/get_started`
- 能力：云台设置。
- 验证：需要云台硬件；验证 UI/控制运动和服务状态。

`reCamera_Gimbal/gimbal_development_c`
- 能力：C 云台 CAN 开发。
- 验证：CAN 接口、比特率 `100000`、帧格式、命令日志和运动。

`reCamera_Gimbal/gimbal_node_red`
- 能力：云台 Node-RED 流。
- 验证：流导入和运动（如果硬件存在）。

`reCamera_Gimbal/PID_adjustment`
- 能力：云台调优。
- 验证：硬件存在、安全测试程序、参数更改、运动结果。

`reCamera_Gimbal/hardware_and_spec`
- 能力：云台硬件/规格参考。
- 验证：除非硬件存在，否则内容 QA。

`reCamera_HQ_POE/reCamera_hq_poe_start`
- 能力：HQ PoE 快速开始。
- 验证：仅在 HQ PoE 硬件上；否则硬件阻塞。

`reCamera_HQ_POE/reCamera_hq_poe_hardware`
- 能力：HQ PoE 规格。
- 验证：除非硬件存在，否则内容 QA。

`reCamera_HQ_POE/reCamera_hq_poe_microscope_demo`
- 能力：显微镜 demo。
- 验证：需要 HQ PoE 和显微镜设置；验证图像流/样本捕获。

`reCamera_Pro/reCamera_Pro_Getting_Start`
- 能力：reCamera Pro 设置。
- 验证：仅在 Pro 硬件上；否则硬件阻塞。

## Software Documents

`reCamera_demo_project_layout`
- 能力：Steven 当前 reCamera C++ demo 目录规范和项目归档规则。
- 默认仓库：`seeed:/home/seeed/sscma-example-sg200x`。
- 新 demo 默认目录：`solutions/sesg-project/<demo_name>`。
- 参考：`project-layout.md`。

`develop_with_c_cpp`
- 能力：C/C++ 开发基线。
- 验证：工具链、SDK 路径、示例构建、部署、运行时命令。

`Real_time_YOLO_object_detection_using_reCamera_based_on_Cpp`
- 能力：C++ YOLO HTTP/API demo。
- 验证：构建/部署模型检测器、停止服务、使用环境运行、验证 `http://192.168.42.1/modeldetector` JSON。

`Make_the_Cpp_program_auto_start_on_boot`
- 能力：SysVinit 自启动。
- 仅在 demo 稳定且用户要求时验证。检查脚本顺序、权限、重启行为。

`configure_static_ip_on_recamera`
- 能力：网络配置。
- 高风险。备份配置、验证当前网络、保留 SSH 恢复路径、仅在请求时应用。

`develop_with_nodered`
- 能力：Node-RED 开发。
- 验证：Node-RED UI、流导入/导出、所需节点、服务重启。

`linux_fundamentals`
- 能力：基本 Linux 使用。
- 验证：内容 QA 或在请求时运行命令。

`os_structure`
- 能力：reCamera OS 结构。
- 验证：文件系统路径、服务、模型位置、overlay/userdata 行为。

`os_version_control`
- 能力：OS 更新/版本。
- 高风险。验证版本端点和更新路径；除非请求，否则不要升级。

`reCamera_connects_to_Xiao_via_HTTP`
- 能力：与 XIAO 的 HTTP 集成。
- 验证：XIAO 硬件/网络、端点、请求格式、接收动作。

## FAQ

`faqs`
- 能力：故障排除/参考。
- 在相关时根据实际设备验证声明。
