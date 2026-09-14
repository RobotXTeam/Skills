---
name: phone-speaker
description: WiFi Phone Speaker（把 Android 手机变成 Windows 无线音箱）项目的完整上下文。涵盖 PSA v1 UDP 协议（magic 0x50534131，9877 发现/9878 会话端口，8 种消息类型）、Windows 端 Rust（WASAPI loopback→Opus→UDP）mingw 交叉编译、Android 端 Kotlin/Compose + libopus JNI、构建与测试命令、国内镜像环境坑、排障要点。当用户提到 phone speaker、手机音箱、Windows 无线音箱、PSA 协议、9877/9878 端口、phone-speaker.exe、WiFi 音箱，或需要修改 /home/steven/phone-speaker 仓库时触发。
---

# WiFi Phone Speaker 项目完整上下文

## 1. 项目概述

把 Android 手机变成 Windows 的无线音箱。数据链路：

```
WASAPI loopback 采集(48kHz s16 双声道, 20ms/960采样) → Opus 编码 → UDP(PSA v1) → WiFi →
Android DatagramSocket → JitterBuffer(按 seq 索引) → libopus 解码(JNI) → AudioTrack 播放(blocking write 定 20ms 节奏)
```

- **仓库**: `/home/steven/phone-speaker`（非 GitHub 远程；4 个提交：`78b6066` M1 实现 → `7ec8f33` M2 独立验证+跨语言 fixture → `0cff746` M3 对抗审查修复（26 项） → `c3491de` M4 完整 README/REPORT）
- **协议**: PSA v1，唯一真源 `protocol/protocol.md`（FINAL，Windows+Android 双方必须一致）
- **当前状态**: MVP 完成 + 对抗式审查修复（里程碑3）。57 个 Rust `#[test]` + 73 个 Kotlin `@Test` 全绿；`phone-speaker.exe` 交叉编译成功（~3.5 MB）；APK 构建成功（app-debug.apk ~11.1 MiB，含 arm64-v8a/armeabi-v7a/x86_64 三 ABI 的 libpsaopus.so）；**实机试听未进行**（无 Windows/Android 实机）。已修 26 项审查确认问题：REPLACE 限同 peer、Android 绑定预期 peer、Kotlin 强制 §2 session_id 规则、控制面 panic 加固、重采样器接线、`--allow-ip/--allow-cidr`、限流等。
- 技术选型：Windows 端 Rust (edition 2021) + `audiopus`（vendored libopus）+ `windows` crate（raw WASAPI）+ 无 async；Android 端 Kotlin（minSdk 26 / targetSdk 34）+ Compose + NDK/CMake 编译 vendored libopus 1.5.2 + 薄 JNI。无 Docker/服务端/数据库。
- 许可 MIT。根目录尚无 README.md / REPORT.md（architecture.md §3 规划由 docs/验收 agent 补写）。

## 2. 目录结构

```
phone-speaker/
├── protocol/protocol.md     PSA v1 协议 FINAL 规格（唯一真源，改协议先改这里）
├── docs/architecture.md     架构决策（技术选型、并发契约、错误/日志规范、各模块职责）
├── docs/audio-pipeline.md   端到端音频管线与延迟预算说明
├── docs/testing.md          测试矩阵、BLOCKED 项、复跑命令（实测结果）
├── windows/                 Windows 主机（Rust crate "phone-speaker"）
│   ├── Cargo.toml           无默认 features；sim feature 换测试音源；[profile.release] lto="thin"
│   ├── build.rs             windows-gnu 链接 libssp（vendored opus 的 __stack_chk_fail 修复）
│   ├── src/                 main.rs / config.rs / proto.rs / session.rs / net.rs /
│   │                        discovery.rs / control.rs / encoder.rs / pipeline.rs / ui.rs / lib.rs
│   │                        audio/{mod,wasapi,sim,convert,resample}.rs
│   └── tests/               fixtures.rs（生成跨语言 fixture）/ integration_sim.rs（loopback 全链路）/
│                            lossy_audio.rs（丢包注入）/ common/mod.rs / fixtures/*.psa
├── android/                 Android 应用（rootProject "psa-speaker"，仅 :app 模块）
│   ├── settings.gradle.kts  阿里云镜像在前，google/mavenCentral 兜底
│   ├── build.gradle.kts     AGP 8.2.2 + Kotlin 1.9.24
│   ├── gradle/wrapper/      distributionUrl 指向腾讯镜像 gradle-8.7-bin.zip
│   └── app/
│       ├── build.gradle.kts compileSdk/targetSdk 34, minSdk 26, cmake 3.22.1,
│       │                    abiFilters [arm64-v8a, armeabi-v7a, x86_64], Compose BOM 2024.05.00
│       └── src/main/
│           ├── cpp/CMakeLists.txt   vendored opus 1.5.2（静态/浮点/OPUS_HARDENING ON）+ psaopus.so
│           ├── cpp/opus/            vendored libopus 源码树
│           ├── cpp/psa_opus_jni.c   薄 JNI：create / decode(fec|plc) / destroy
│           ├── AndroidManifest.xml  8 个权限 + SpeakerService(foregroundServiceType=mediaPlayback)
│           └── java/dev/psa/speaker/ 见 §7
├── scripts/build-windows.sh  交叉编译 → dist/phone-speaker.exe
├── scripts/build-android.sh  gradle assembleDebug → dist/phone-speaker.apk
└── dist/                     产物目录（gitignore；当前磁盘不存在，构建脚本会自动创建）
```

## 3. PSA v1 协议速查

传输 UDP/IPv4，多字节整数全大端。头 20 字节固定：

| Offset | Size | 字段 |
|---|---|---|
| 0 | 4 | magic u32 = `0x50534131`（ASCII "PSA1"） |
| 4 | 1 | version u8 = 0x01 |
| 5 | 1 | type u8（1..8） |
| 6 | 2 | payload_len u16（头之后字节数） |
| 8 | 4 | session_id u32（DISCOVER/ACK/CONNECT_REQ 为 0；CONNECT_ACCEPT 起为服务端分配的随机非零值） |
| 12 | 4 | seq u32（仅 AUDIO：每会话从 0 递增；控制消息恒 0） |
| 16 | 4 | timestamp u32（AUDIO 捕获时间 ms，单调钟 mod 2^32；仅信息性，双方时钟不同步） |

消息类型（id 1–8）：

| id | 名称 | 方向 | payload 要点 |
|---|---|---|---|
| 1 | DISCOVER | Android→Windows | client_version u8 + name_len u8 + name；广播 `255.255.255.255:9877` 或单播 `<ip>:9877` |
| 2 | DISCOVER_ACK | Windows→Android | server_version u8 + session_port u16 + name + sample_rate u32=48000 + channels u8=2 + frame_ms u16=20；单播回发送方 |
| 3 | CONNECT_REQ | Android→Windows | client_version u8 + profile u8(0/1/2) + bitrate_kbps u16 + name |
| 4 | CONNECT_ACCEPT | Windows→Android | server_version u8 + profile u8(有效值) + sample_rate u32 + channels u8 + frame_ms u16 + bitrate_kbps u16（有效值）；session_id 在头里 |
| 5 | CONNECT_REJECT | Windows→Android | reason u8(1=busy, 2=version_unsupported, 3=invalid_request) + reason_len+text |
| 6 | AUDIO | Windows→Android | 一个 20ms Opus 帧原始字节 |
| 7 | KEEPALIVE | Android→Windows | rx_packets u32 + rx_lost u32 + jitter_ms u16 + buffer_ms u16 |
| 8 | DISCONNECT | 双向 | reason u8(1=user_request, 2=shutdown, 3=protocol_error) |

关键常量：FRAME_MS 20、48kHz、2ch、960 采样/帧、MAX_DATAGRAM 2048（5.0 超大数据报丢弃）、MAX_PAYLOAD 2000；码率集合 `{64,96,128,160,192}`，请求值被 clamp，默认 128。

关键超时/节奏：
- 发现：DISCOVER 广播每 **1000ms** 一次；发现的主机 **5000ms** 无 ACK 过期
- CONNECT_REQ 重试每 **500ms**，最多 **10 次**
- KEEPALIVE 间隔 **1000ms**（流期间）；Windows KEEPALIVE_TIMEOUT **10s** 过期会话
- STREAM_TIMEOUT **3s**（Android 判定流丢失 → RECONNECTING）
- 重连最多 **15 轮**失败后回到 SEARCHING（UI 报错）
- RESYNC_GAP **15 帧 (300ms)** seq 跳变触发 jitter buffer resync
- Windows 流期间恒定 **50 包/秒**（静音也发零帧，协议 §6.3 强制：WASAPI loopback 系统静音时不输出缓冲，Windows 必须合成零 PCM 保证节奏——这是 Android 侧存活信号）
- Opus 编码配置：APPLICATION_AUDIO、complexity 10、inband FEC 开、packet loss hint 5%、DTX 关
- Jitter buffer（Android 规范行为）：容量 40 帧 (800ms)；目标填充 Low=3 / Balanced=6（默认）/ Stable=10 帧（60/120/200ms）；重连/resync 后缓冲达到目标才开始播；乱序按 seq 归一放置、重复丢、迟到丢；缺帧先 FEC 解码下一帧，否则 PLC（NULL payload）；溢出（>2×目标+10 帧）丢最旧到目标；指标 EMA α=0.05

校验规则（§9，双方 MUST）：<20B 或 >2048B 丢、magic 错丢、version≠1 对 CONNECT_REQ 回 REJECT(2)、type 非 1..8 丢、payload_len 不匹配丢、控制载荷最小长（DISCOVER≥2 / DISCOVER_ACK≥12 / CONNECT_REQ≥5 / CONNECT_ACCEPT≥11 / KEEPALIVE=12 / DISCONNECT=1）不符丢、会话消息 session_id 不匹配丢。未知 type 静默丢弃并计数。

状态机：Windows 为单会话服务器（IDLE / STREAMING；STREAMING 时新 CONNECT_REQ 直接替换旧会话并告警）；Android 为 DISCONNECTED / SEARCHING / FOUND / CONNECTING / STREAMING / RECONNECTING。后台播放靠前台服务；进程死亡后下次启动重连。

## 4. 构建方法与测试命令

### Windows 交叉编译（Linux 主机 → x86_64-pc-windows-gnu）

```bash
cd /home/steven/phone-speaker
./scripts/build-windows.sh
```

脚本内部等同：
```bash
export CC_x86_64_pc_windows_gnu=x86_64-w64-mingw32-gcc
export AR_x86_64_pc_windows_gnu=x86_64-w64-mingw32-ar
export CFLAGS_x86_64_pc_windows_gnu="-fno-stack-protector -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0"
rustup target add x86_64-pc-windows-gnu   # 未安装则加
cd windows && cargo build --release --target x86_64-pc-windows-gnu
cp target/x86_64-pc-windows-gnu/release/phone-speaker.exe ../dist/
```

- **CFLAGS 修复原因**：Ubuntu mingw gcc 默认 `-fstack-protector-strong` + FORTIFY，vendored libopus（audiopus_sys，CMake 构建，其默认 OPUS_STACK_PROTECTOR）会产生 `__stack_chk_fail` / `__memcpy_chk` 引用，mingw libc 不提供 → C 代码禁用这些默认（Rust 代码保持加固）。
- **build.rs 链接 libssp**：对 windows-gnu 目标 `rustc-link-lib=ssp` + `rustc-link-arg=-lssp`（顺序关键：libssp 须在 libopus 之后，raw flag 追加到链接行尾）。
- **thin-LTO（已确认可用）**：Cargo.toml `[profile.release] lto="thin"`，多次干净重建均成功产出 exe（含里程碑3后 3,555,461 字节）。若未来 mingw 链接报 `.drectve`/符号问题，优先检查 build.rs 的 -lssp 顺序，再临时关 thin-LTO。

### Android APK

```bash
cd /home/steven/phone-speaker
./scripts/build-android.sh
```

脚本内部等同：写 `android/local.properties`（`sdk.dir=$ANDROID_HOME`，默认 `~/Android/Sdk`）→ `~/tools/gradle-8.7/bin/gradle :app:assembleDebug --console=plain` → 拷 `app/build/outputs/apk/debug/app-debug.apk` 到 `dist/phone-speaker.apk`。

- **NDK 版本**：`android/app/build.gradle.kts` 现已显式 `ndkVersion = "26.3.11579264"`（里程碑3后固定）。机器上同时装有 25.1.8937393（AGP 8.2.2 默认）与 26.3.11579264；不声明时 AGP 会用默认 25.1，在只有 26.3 的机器上会失败，故必须保持显式声明。
- gradle 二进制：`~/tools/gradle-8.7/bin/gradle`；wrapper 指向腾讯镜像。

### 测试

```bash
cd /home/steven/phone-speaker/windows && cargo test --features sim   # Rust 全量（57 个 #[test]：54 单元 + fixtures + integration_sim + lossy_audio）
cd /home/steven/phone-speaker/android && ~/tools/gradle-8.7/bin/gradle :app:testDebugUnitTest   # Kotlin 全量（73 个 @Test）
# Android 测试文件：ProtocolTest 31（含 200 例随机 fuzz）、JitterBufferTest 19、ConnectionStateTest 17、CrossLanguageFixtureTest 6
```

fixture 重生成：`cargo test --features sim` 中的 fixtures.rs 会写 `windows/tests/fixtures/`（容器格式：每包 `[len: u32 LE][datagram]` 串接），Kotlin 端测试解析同一批字节——**改动生成逻辑必须双边协调**。

## 5. 环境与镜像坑（未来会话必踩）

- **~/.cargo/config.toml** 已配 USTC sparse 镜像（crates-io → `sparse+https://mirrors.ustc.edu.cn/crates.io-index/`，git-fetch-with-cli=true）。static.crates.io 直连不通，**勿改**。
- rustup 官方源慢：必要时 `export RUSTUP_DIST_SERVER=https://mirrors.ustc.edu.cn/rust-static`。
- services.gradle.org 慢：wrapper 已指向腾讯镜像 `mirrors.cloud.tencent.com/gradle/gradle-8.7-bin.zip`；settings.gradle.kts 里阿里云 maven（gradle-plugin/google/public）在前，google()/mavenCentral() 兜底。阿里云是部分同步，个别 androidx 包 404 会自动回退 google()——不要因此改仓库顺序。
- xiph.org / github 下载慢但可达（opus 是 vendored 的，一般无需再下）。
- rust-version = 1.70；ringbuf 0.3 / windows 0.58 / audiopus 0.3.0-rc.0（vendored opus，Linux 与 mingw 均可构建）。

## 6. 测试现状与 BLOCKED 项

PASS（Linux 主机全绿）：
- Rust：proto 编解码、§9 全部畸形包拒绝、opus 编解码 roundtrip、resampler/converter DSP（sine/DC/impulse）、session FSM、fixture 生成、**Linux loopback 集成仿真**（SimSource→真实 Opus→real UDP 127.0.0.1→解析→解码→960 采样验证）、lossy_audio 丢包注入
- Kotlin：Protocol 往返 + 200 例随机 fuzz、JitterBuffer 重排/重复/丢包/FEC/PLC/resync/溢出/prebuffer/指标、连接状态机含重连上限、跨语言 fixture 兼容（解析 Rust 生成的 .psa 字节）
- 构建门：exe 交叉编译链接成功；assembleDebug 成功且 APK 内含 3 ABI 的 libpsaopus.so

BLOCKED（文档明示不要当已通过）：
- 真实 WASAPI 采集（需 Windows 主机）
- 真机扬声器试听（需 Android 设备）
- WiFi 射频真实丢包/漫游测试（需两台物理设备）
- Android 运行时行为（AudioTrack underrun、前台服务行为；无模拟器，KVM 不可用）

稳定性：业主明确本里程碑不要求 30min/2h 浸泡测试；浸泡 harness（integration 测试+计数器）已就位，留待真机。

## 7. 关键实现位置速查

| 功能 | 位置 |
|---|---|
| PSA 协议编解码 | Rust: `windows/src/proto.rs`（纯逻辑、主机可测，12 测试）；Kotlin: `engine/Protocol.kt`（镜像实现，31 测试） |
| WASAPI loopback 采集 + 静音补帧 | `windows/src/audio/wasapi.rs`（仅 `#[cfg(windows)]`，Linux 上不编译） |
| 合成音源（测试用） | `windows/src/audio/sim.rs`（sim feature；非生产路径） |
| 混音格式转换 / 重采样 | `windows/src/audio/convert.rs`（f32/s16/s24/s32、下混）、`resample.rs`（混合率≠48k 时线性插值） |
| Windows 会话状态机 | `windows/src/session.rs`（IDLE/STREAMING，替换式连接）；控制线程 `control.rs`、发现应答 `discovery.rs`、UDP `net.rs` |
| Android 状态机 | `engine/ConnectionStateMachine.kt` + `ConnectionManager.kt`（CONNECT_REQ 重试/重连循环） |
| Jitter buffer | `engine/JitterBuffer.kt`（19 测试） |
| 网络接收线程 | `engine/NetworkReceiver.kt`（只解析入队，不解码；SO_TIMEOUT 200ms，线程名 "psa-net"） |
| 播放线程 | `engine/AudioPlayer.kt`（线程名 "psa-play"；AudioTrack MODE_STREAM 48k/立体声/s16，USAGE_MEDIA + PERFORMANCE_MODE_LOW_LATENCY；blocking write 定 20ms；underrun 定时记录） |
| JNI 层 | `cpp/psa_opus_jni.c` + `cpp/CMakeLists.txt`（vendored opus 在 `cpp/opus`）；Kotlin 侧 `engine/OpusDecoder.kt`（System.loadLibrary("psaopus")） |
| 前台服务 | `service/SpeakerService.kt`（foregroundServiceType=mediaPlayback；WakeLock partial + WifiLock WIFI_MODE_FULL_HIGH_PERF；音频焦点获取/释放；通知带 stop 动作） |
| UI | `MainActivity.kt` + `ui/SpeakerScreen.kt` + `ui/Theme.kt` + `model/UiState.kt`（状态单向流：服务端 StateFlow 快照） |
| 命令行入口 | `windows/src/main.rs`（clap：`--bitrate --profile --bind --port --verbose`；tray 在 feature "tray" 后面） |

## 8. 排障要点

- **Windows 无声**：确认 exe 用 `--bind <ip>` 绑定可达 IP，且 Windows 防火墙放行 UDP 9877/9878（README 需说明防火墙弹窗与仅限局域网意图）。
- **Android 连不上**：先确认同一 WiFi；UI 支持手动输入 IP 单播发现作回退。见错误文案（架构规范，UI 应显示）：搜索中 "Searching for PC…"；10s 无主机 "No PC found. Make sure Windows and Android are on the same WiFi."；断流 "Connection lost — reconnecting…"。
- **重连机制**：Android 侧 `ConnectionManager.kt`——无 AUDIO 3s → RECONNECTING → 500ms 一轮 CONNECT_REQ，最多 15 轮 → SEARCHING。
- **日志级别**：Rust 用 tracing + env filter，默认 INFO，`RUST_LOG=debug` 开包级调试；Kotlin 用 `engine/L.kt` 小包装，默认 INFO，debug 构建允许 VERBOSE 包日志（build.gradle.kts 注明）。**任何平台不得在 INFO 级逐包记日志**，计数器至少 5s 一次。
- **Default 设备切换/睡眠恢复（Windows）**：WASAPI 失效路径自动重建采集，流不中断（audio-pipeline.md）。
- **会话被无缝替换**：Windows 是单会话设计，第二个手机连接会顶掉第一个——这是协议规定行为（§5.1），不是 bug。

## 9. Roadmap（来自文档）

- 认证/加密：v1 无（protocol.md §12 明文列为 roadmap item；`--bind` 是当前唯一收口手段）
- Windows 托盘：架构 P2（`main.rs` 已有 tray feature 占位），当前 CLI-first（结构化日志+状态）
- 多手机并发：当前单会话、新连接替换旧会话（§5.1）；并发需求需先改协议
- 真实设备验证清单：全在 testing.md "BLOCKED" 节——live WASAPI、实机播放、WiFi 射频、Android 运行时（underrun/前台服务/续航），达标后跑 30min/2h 浸泡
- 文档补齐：README.md / REPORT.md 尚未创建（architecture.md §3 归 docs/验收 agent）

## 重要原则

- 协议或 fixture 的任何变动：双方实现（windows/proto.rs ↔ engine/Protocol.kt）与 `windows/tests/fixtures/` 须同步，README.txt 警告过要双边协调。
- 音频线程永不阻塞于 UI/日志；ring buffer 溢出丢最旧不丢最新；Kotlin 音频路径禁 runBlocking，JitterBuffer 锁内只做短临界区。
- 硬件未到之前，一切"无声/接不上"类论断属于未验证，测试文档要求 BLOCKED 项永不标 PASS。