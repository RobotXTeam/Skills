# 产品边界：确认是 reCamera Pro，不是别的东西

Steven 名下有多个 reCamera 相关项目，**搞错对象会做出完全没用的东西**。
动手前先确认仓库路径。

## 归属判定表

| 线索 | 归属 | 用什么 |
|---|---|---|
| 仓库是 `linux-app-web-recamera_web_react` | **reCamera Pro WebUI（本 skill）** | `reCameraPro_web` |
| 用户提到「应用中心」「画面设置」「AI推理」「终端」等中文导航 | **reCamera Pro WebUI** | `reCameraPro_web` |
| 提到 RV1126B、recamera2、ipcweb | **reCamera Pro** | `reCameraPro_web` |
| 仓库是 `sscma-example-sg200x` | reCamera Studio（SG200X） | `reweb` |
| 提到 Node-RED、Supervisor、Studio、Vite、USB-RNDIS | reCamera Studio | `reweb` |
| 提到 wiki 校验、NPU demo、CVIMODEL 转换 | reCamera 文档/模型侧 | `recamera` |
| 提到 reCamera 2002 / 2003 等其它型号 | **都不是本 skill** | 先问清楚仓库 |

## 仓库路径

**前端（UI 的真实来源）**

```
/home/steven/work/RV1126B/仓库/完整的/rockchip/linux-app-web-recamera_web_react
```

同目录下的兄弟仓库（同一 RV1126B SDK 集合，用 `find` 或 `ls` 确认）：

- `linux-app-web-recamera_web_backend` — 真实设备侧后端（C/C++）
- `linux-app-web-new-mini_ipcweb-backend` — 旧 ipcweb 后端
- 大量 `linux-ipc-*`、`rk-*`、`rtos-*` — SDK 组件

**注意**：这些仓库由 `仓库/完整的/clone_rockchip.py` 从 Seeed 内网 GitLab
（`iteam-gitlab.seeed.cn/rockchip/`）批量克隆，目录名是「仓库类型-组件名」的扁平形式。

## 前端的两个后端，别混淆

| | 位置 | 用途 |
|---|---|---|
| **内置 Mock 后端** | `<前端仓库>/backend/`（Python + FastAPI） | 本地跑界面用；`app/api/*.py` 里定义 `/cgi-bin/entry.cgi/...` 接口 |
| 真实设备后端 | `linux-app-web-recamera_web_backend`（C/C++ + CMake） | 设备上真正跑的 |

做 UI 演示时，接口在 **Mock 后端**里加即可。
真实设备端的接口契约需要另外写文档给研发——**演示不代表设备端已实现**。

## 真实设备接口文档

- `<前端仓库>/backend/reCamera_API.txt` — 真实设备 API 说明（纯文本）
- `<前端仓库>/backend/reCamera WEB API.pdf` — 同上 PDF
- `<前端仓库>/backend/INFERENCE_API_CHANGES.md` — 推理相关接口变更

**新功能如果涉及设备接口，一定先查这三份**，确认设备端有没有对应能力。
若没有，要在交付 README 里明确「设备端接口尚未实现」。

## 已知的导航结构（reCamera Pro WebUI）

侧边栏：实时预览 / 设备信息 / 画面设置 / 录制设置 / 应用中心 / 终端

- **画面设置**（`/live-view`）→ 标签：基础设置 / 显示设置 / OSD设置 / AI结果
  - 基础设置里有：视频设置、**音频设置**（编码+码率）、音频存储设置
- **应用中心**（`/app-center`）→ 安装应用管理 + 应用商店 + 系统内置应用
- 已有"专家模式"先例：画面设置里有 `expertMode`（mixnr）

改动前先在这些页面里找**同类控件**，照抄它的位置与交互，别自创。