# Demo Wiki 模板

## 模板结构

```markdown
---
title: 使用 reCamera 的 [功能] 演示
description: 本文档介绍了使用 reCamera 的基于 AI 的 [功能] 演示，展示了 [核心功能描述]。
keywords:
  - [英文关键词1]
  - [英文关键词2]
  - reCamera
  - AI Edge Vision
  - [其他相关词]
slug: /recamera_[demo_name]
sku: 102991897,102991896
image: https://files.seeedstudio.com/wiki/reCamera/[demo_name]/demo.gif
sidebar_position: [序号]
last_update:
  date: YYYY-MM-DDT00:00:00.000Z
  author: Steven
createdAt: 'YYYY-MM-DD'
updatedAt: 'YYYY-MM-DD'
url: https://wiki.seeedstudio.com/cn/recamera_[demo_name]/
---

# 使用 reCamera 的 [功能] 演示

## 简介

[2-3句话描述应用场景和需求]

本项目提供了一个开箱即用的演示，专注于以下应用功能：

- **[功能1]**：[描述]
- **[功能2]**：[描述]
- **[功能3]**：[描述]

<div align="center"><img width={600} src="https://files.seeedstudio.com/wiki/reCamera/[demo_name]/demo.gif" /></div>

## 硬件准备

要运行此演示，只需要**一台 reCamera 设备**。
支持所有 reCamera 变体。

您可以根据部署需求选择**任何版本的 reCamera**：

- reCamera 2002 系列（Wi-Fi）
- reCamera Gimbal（云台）
- reCamera HQ PoE（以太网 + PoE）

<table align="center">
 <tr>
  <th>reCamera 2002 系列</th>
  <th>reCamera Gimbal</th>
  <th>reCamera HQ PoE</th>
 </tr>
 <tr>
  <td>
    <div style={{textAlign:'center'}}>
      <img src="https://files.seeedstudio.com/wiki/reCamera/recamera_banner.png" style={{width:300, height:'auto'}}/>
    </div>
  </td>
  <td>
    <div style={{textAlign:'center'}}>
      <img src="https://files.seeedstudio.com/wiki/reCamera/Gimbal/reCamera-Gimbal.png" style={{width:300, height:'auto'}}/>
    </div>
  </td>
  <td>
    <div style={{textAlign:'center'}}>
      <img src="https://files.seeedstudio.com/wiki/reCamera/reCamera_hq_poe/1-100029708-reCamera-2002-HQ-PoE-8GB.jpg" style={{width:300, height:'auto'}}/>
    </div>
  </td>
 </tr>
 <tr>
  <td>
    <div class="get_one_now_container" style={{textAlign: 'center'}}>
      <a class="get_one_now_item" href="https://www.seeedstudio.com/reCamera-2002w-8GB-p-6250.html" target="_blank">
        <strong><span><font color={'FFFFFF'} size={"4"}> 立即购买 </font></span></strong>
      </a>
    </div>
  </td>
  <td>
    <div class="get_one_now_container" style={{textAlign: 'center'}}>
      <a class="get_one_now_item" href="https://www.seeedstudio.com/reCamera-gimbal-2002w-optional-accessories.html" target="_blank" rel="noopener noreferrer">
        <strong><span><font color={'FFFFFF'} size={"4"}> 立即购买 </font></span></strong>
      </a>
    </div>
  </td>
  <td>
    <div class="get_one_now_container" style={{textAlign: 'center'}}>
      <a class="get_one_now_item" href="https://www.seeedstudio.com/reCamera-2002-HQ-PoE-64GB-p-6557.html" target="_blank" rel="noopener noreferrer">
        <strong><span><font color={'FFFFFF'} size={"4"}> 立即购买 </font></span></strong>
      </a>
    </div>
  </td>
 </tr>
</table>

## 软件准备

- reCamera OS 0.2.3+
- 主机工具链（用于交叉编译 C++ 程序）
- Python 3.x（用于 PC 端接收脚本）

:::note
本演示使用的模型文件已提供在 [Google Drive]([wiki_root_google_drive_link])，请进入 `/reCamera_Shared/Wiki/[demo_name]/model/` 下载，无需自行转换。

如需自行转换模型，请参考：[reCamera AI 模型部署指南](https://wiki.seeedstudio.com/cn/recamera_ai_model_deployment/)
:::

## 搭建演示

### 步骤 1：配置 reCamera

首先，请按照官方入门指南完成 reCamera 的基本配置：[reCamera 基本配置](https://wiki.seeedstudio.com/cn/recamera_getting_started/)

完成初始设置后，确保设备已通电并正确连接到网络。

:::warning
在运行 C++ 程序之前，必须停止默认的 Node-RED 服务，因为它们会占用相机资源。请通过 SSH 运行以下命令：
:::

```bash
sudo /etc/init.d/S03node-red stop
sudo /etc/init.d/S91sscma-node stop
sudo /etc/init.d/S93sscma-supervisor stop
```

### 步骤 2：下载模型和代码

从 [Google Drive]([wiki_root_google_drive_link]) 进入 `/reCamera_Shared/Wiki/[demo_name]/model/`，下载本演示所需的模型文件：

- `model1.cvimodel` - [模型1描述]
- `model2.cvimodel` - [模型2描述]

下载后将模型放到 demo 目录的 `model/` 文件夹中：

```bash
mkdir -p model
# 将下载的 .cvimodel 文件复制到 model/
ls model/
```

从 GitHub 克隆代码仓库：

```bash
git clone https://github.com/RobotXTeam/sscma-example-sg200x.git
cd sscma-example-sg200x/solutions/sesg-project/[demo_name]
```

### 步骤 3：编译 C++ 程序

设置交叉编译环境：

```bash
export SG200X_SDK_PATH=[SDK路径]
export PATH=[工具链路径]/bin:$PATH
```

编译项目：

```bash
rm -rf build && mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
make -j$(nproc)
```

编译后的可执行文件位于：`build/[demo_name]`

### 步骤 4：部署到 reCamera

将可执行文件和模型上传到 reCamera：

```bash
scp build/[demo_name] recamera@192.168.42.1:/home/recamera/[demo_name]/
scp *.cvimodel recamera@192.168.42.1:/home/recamera/[demo_name]/models/
```

设备上的目录结构：

```text
/home/recamera/[demo_name]/
├── [demo_name]              # 可执行文件
├── models/                  # 模型文件
│   ├── model1.cvimodel
│   └── model2.cvimodel
└── [其他资源文件]
```

### 步骤 5：运行演示

SSH 登录 reCamera 并运行：

```bash
cd /home/recamera/[demo_name]
chmod +x [demo_name]
sudo ./"[demo_name]" [参数1] [参数2]
```

#### 参数说明

| 参数 | 描述 | 默认值 |
|------|------|--------|
| `[参数1]` | [描述] | [默认值] |
| `[参数2]` | [描述] | [默认值] |

#### 示例命令

```bash
# 基础用法
sudo ./"[demo_name]" [参数]

# 完整用法
sudo ./"[demo_name]" [参数1] [参数2] [参数3]
```

## 预期输出

### 在 reCamera 终端上

运行成功后，终端将显示：

```text
[预期输出示例]
```

### 在 PC 端（如适用）

如果演示包含 PC 端显示，运行 Python 接收脚本：

```bash
cd sscma-example-sg200x/solutions/sesg-project/[demo_name]
python3 receiver.py
```

<div align="center"><img width={500} src="https://files.seeedstudio.com/wiki/reCamera/[demo_name]/pc_output.png" /></div>

### 证据文件

本演示的完整证据图片和视频已上传到 Google Drive：

- Google Drive 根目录：[Google Drive]([wiki_root_google_drive_link])
- 证据图片路径：`/reCamera_Shared/Wiki/[demo_name]/evidence/image/`
- 证据视频路径：`/reCamera_Shared/Wiki/[demo_name]/evidence/video/`

关键文件：

- `[evidence_image_1]` - [图片说明]
- `[evidence_video_1]` - [视频说明]

## 故障排查

### 相机访问错误

如果看到 "No camera" 错误：
- 确保 Node-RED 服务已停止（参见步骤 1）
- 检查相机连接

### 模型加载错误

如果模型加载失败：
- 确认模型文件已正确上传
- 使用 `ls -la` 检查文件权限
- 确保有足够的存储空间

### 内存不足错误

如果出现 ION 内存错误：
- 停止其他占用内存的服务
- 检查是否有其他程序在运行

## 恢复服务

演示完成后，恢复默认服务：

```bash
sudo /etc/init.d/S03node-red start
sudo /etc/init.d/S91sscma-node start
curl -sS http://127.0.0.1/api/version
```

## 技术支持与产品讨论

感谢您选择我们的产品！如果您需要特定定制目标的指导或想要进一步扩展工作流，请随时联系我们。我们在这里为您提供不同的支持，确保您使用我们产品的体验尽可能顺畅。我们提供多种沟通渠道以满足不同的偏好和需求。

<div class="button_tech_support_container">
<a href="https://forum.seeedstudio.com/" class="button_forum"></a>
<a href="https://www.seeedstudio.com/contacts" class="button_email"></a>
</div>

<div class="button_tech_support_container">
<a href="https://discord.gg/eWkprNDMU7" class="button_discord"></a>
<a href="https://github.com/Seeed-Studio/wiki-documents/discussions/69" class="button_discussion"></a>
</div>
```

## 关键规则

### 1. Frontmatter 必填字段

每个 Wiki 文件**必须**包含以下 frontmatter：

```yaml
---
title: 使用 reCamera 的 [功能] 演示
description: 本文档介绍了使用 reCamera 的基于 AI 的 [功能] 演示，展示了 [核心功能描述]。
keywords:
  - [英文关键词]
  - reCamera
  - AI Edge Vision
slug: /recamera_[demo_name]
sku: 102991897,102991896
image: https://files.seeedstudio.com/wiki/reCamera/[demo_name]/demo.gif
sidebar_position: [序号]
last_update:
  date: YYYY-MM-DDT00:00:00.000Z
  author: Steven
createdAt: 'YYYY-MM-DD'
updatedAt: 'YYYY-MM-DD'
url: https://wiki.seeedstudio.com/cn/recamera_[demo_name]/
---
```

### 2. 路径处理

**绝对禁止**出现本机路径：
- ❌ `/home/steven/...`
- ❌ `/home/seeed/...`
- ❌ `C:\Users\...`

**正确做法**：
- 使用相对路径：`build/[demo_name]`
- 使用占位符：`[SDK路径]`、`[工具链路径]`
- 使用设备路径：`/home/recamera/[demo_name]/`

### 3. 模型文件

**不要**在 Wiki 中描述模型转换过程。

**正确做法**：
- 指向固定 Wiki 根目录链接，占位符使用 `[wiki_root_google_drive_link]`
- 固定链接为 `https://drive.google.com/drive/folders/1GOQUMCel7fapbJCWzEEynDIvIt-6Wf5p?usp=drive_link`
- 写明模型云端目录：`/reCamera_Shared/Wiki/[demo_name]/model/`
- 列出每个需要下载的模型文件名和用途
- 在生成最终 Wiki 前，用 `curl -L -I "[wiki_root_google_drive_link]"` 确认未登录用户能访问
- 提供自行转换的参考链接

### 4. 效果演示

**不要**直接使用 MP4 视频。

**正确做法**：
- 将 MP4 转换为 GIF
- 上传到 Seeed 文件服务器
- 在 Wiki 中使用 `<div align="center"><img width={600} src="[链接]" /></div>`
- 证据原始图片和视频仍需上传到 Google Drive
- 证据图片和视频默认使用固定 Wiki 根目录链接 `[wiki_root_google_drive_link]` 加子路径说明
- 图片子路径：`/reCamera_Shared/Wiki/[demo_name]/evidence/image/`
- 视频子路径：`/reCamera_Shared/Wiki/[demo_name]/evidence/video/`
- 在生成最终 Wiki 前，用 `curl -L -I "[wiki_root_google_drive_link]"` 确认未登录用户能访问

### 5. 语言风格

**面向小白用户**：
- 使用简单易懂的中文
- 每个步骤都要详细说明
- 提供完整的命令示例
- 解释参数的含义

### 6. 可复现性

**确保用户能复现**：
- 提供完整的命令
- 说明预期输出
- 列出常见问题和解决方案
- 提供恢复服务的步骤
