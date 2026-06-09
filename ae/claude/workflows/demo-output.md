# Demo 输出工作流

## 目的

根据想法或开源项目，使用知识库部署到设备上，验证部署成功，录制运行效果，生成 Wiki 文档。

## 输入

- 项目想法或开源项目 URL
- 目标设备（reCamera）

## 工作流程

### 1. 搜索知识库

在 `knowhubs/reCamera_KnowHub/` 中搜索相关能力：
- 搜索 `capability-map.md` 中的类似项目
- 搜索 `model-conversion.md` 中的模型转换方法
- 搜索 `cpp-runtime.md` 中的运行时配置

### 2. 规划部署步骤

基于搜索结果规划部署步骤：
- 获取代码/模型
- 环境准备
- 编译/构建
- 部署到设备
- 运行和验证

### 3. 部署到设备

执行部署步骤：
- 使用环境配置连接到设备
- 按照规划的步骤操作
- 记录每个步骤的结果

### 4. 验证输出

验证部署是否成功：
- 截图查看输出内容
- 检查日志文件
- 验证功能是否正常

### 5. 录制视频流

录制设备的运行效果：
- 使用主机拉取设备的视频流
- 录制视频窗口
- 传回本机

### 6. 用户审核

在本机打开视频，由用户审核：
- 内容是否正确
- 效果是否通过
- 是否需要调整

### 7. 生成 Wiki 文档

如果用户审核通过，生成 Wiki 文档：
- 使用模板 `templates/demo-wiki.md`
- 按照现有 wiki 蒸馏格式
- 可以调用 AI 生成图片
- 使用效果图片和视频
- 写完传回本机

面向外部读者的文档硬性要求：
- README、Wiki、demo 文档和项目源码中的注释/示例命令不要出现 Steven 本机绝对路径，例如 `/home/steven/...`、`/home/steven/work/...`、`/home/steven/下载/...`。
- 用相对路径、环境变量或占位路径替代，例如 `$REPO_ROOT`、`$SDK_ROOT`、`$TOOLCHAIN_BIN`、`$DEMO_DIR`、`<path-to-model>`。
- 证据、日志、视频等本机验证产物可以写进内部部署报告，但公开 README/Wiki 只写相对位置或"see the generated evidence video"这类描述。
- 如果真实命令依赖 Steven 环境，公开文档中使用可迁移的伪命令，并在内部报告另行记录真实路径。
- 默认不要把 `.cvimodel`、`.onnx`、`.pth`、`.pt` 等大模型文件提交或推送到 GitHub 仓库。公开 README/Wiki 里写模型放置位置、下载链接、Release/LFS 方案或 `<path-to-model>` 占位说明；只有 Steven 明确要求"这次模型也上传"时才强制加入模型文件。

## 输出

- 设备上部署成功的项目
- 证据（截图、视频）
- Wiki 文档（公开读者可复现，不含 Steven 本机绝对路径）

## 引用

- 知识库：`knowhubs/reCamera_KnowHub/`
- 环境配置：`environments/seeed-recamera/`
- Demo 模板：`templates/demo-wiki.md`
