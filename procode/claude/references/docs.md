# 文档仓库与 manifest 版本管理

## linux-ipc-docs-rv1126b（挂载 docs/）

Rockchip 上游官方文档镜像：**90 个 PDF（en 38 + zh 52）+ 1 个 MD，按 en/ 和 zh/ 分类**（audio/bsp/ipc/isp/media/security，zh 另加 npu_iva/wifibt）。⚠️ **不含任何 reCamera 专属内容**（全文零 "recamera" 命中）。

常用入口：

| 文档 | 用途 |
|---|---|
| `en/ipc/Rockchip_RV1126B_Quick_Start_Linux_IPC_SDK_EN.pdf`（V1.7.0，linkfile 到 SDK 根） | 构建/烧录/部署总流程 |
| `en/media/Rockchip_Developer_Guide_MPI_C_EN.pdf`（98MB，最大） | MPI C 媒体 API |
| `en/isp/Rockchip_Tuning_Guide_ISP35_EN.pdf`（86MB）+ Development_Guide_ISP35（76MB） | ISP 调优 |
| `en|zh/ipc/..._Release_V1.0.0_20250620_*.pdf` | SDK release notes |

其他权威文档散布在各子仓库：`linux-rockit/mpi/doc/Rockchip_Developer_Guide_MPI_CN.pdf`、`linux-bsp-rkadk/docs/`、`rk-rknn-llm/doc/Rockchip_RKLLM_SDK_{CN,EN}_1.2.3.pdf`、`linux-ipc-app-lib-vigil/README.txt` + `docs/minimal-http-api.md`、`linux-app-web-recamera_web_react/AGENTS.md`。

产品 release notes：`linux-ipc-demo_cfg_recamera2/RECAMERA2-IPC-RELEASE-NOTES.md`（linkfile 到 SDK 根）。

坑：仓库 1.8GB 里 1.1GB 是 .git；**别盲目 grep PDF**，用 pdftotext 定点提取。git remote URL 内嵌 oauth2 token——**不要把 `git remote -v` 打进日志/分享输出**。

## rv1126b-manifests（SDK 组成的蓝图）

git-repo manifest 仓库（Seeed 私有 GitLab：iteam-gitlab.seeed.cn/rockchip/）：

| 文件 | 作用 |
|---|---|
| `recamera_v2_dev.xml` | dev manifest：80 个 project 全跟 main 分支（浮动）+ linkfiles（build.sh、rkflash.sh、RECAMERA2-IPC-RELEASE-NOTES.md、快速上手 PDF 挂到 SDK 根） |
| `recamera_v2_release.xml` | lock_manifest.py 生成的钉版 manifest（当前 **v1.1.2**，2026-07-29 生成） |
| `release/recamera_v2_v*.xml` | 19 个历史版本（v0.1.0 … v1.1.2） |
| `tree.txt` | **子仓库→嵌套路径的权威映射**（generate_project_tree.py 生成；略滞后于 XML——rkllm-inference 等新挂载未收录） |
| `lock_manifest.py` | 发布流程：版本号自动读 BoardConfig_Recamera2 的 RK_OTA_VERSION；脏树/未推送预检；归档到 release/ |
| `release/manifest_diff_changelog.py` | 两版 manifest diff + 逐仓库 git log → Markdown changelog |
| `CHANGELOG.md` / `CHANGELOG_UPSTREAM.md` | Seeed 侧变更 / 对 RK 上游的逐仓库差异 |

### 发版工作流

```
改子仓库并推送 → python3 lock_manifest.py <ver>（SDK 根）
  → recamera_v2_release.xml 钉住全部 SHA + release/recamera_v2_<ver>.xml
  → repo init -b <ver> -m recamera_v2_<ver>.xml 复现该版本
```

CHANGELOG 要点：2025-09-18 加入 recamera2 专属仓库（recamera_ipc/web/BoardConfig_Recamera2）；2025-10-27 同步 RK v1.1.0（新增 rkai/testdemo/AVS_tool/kmpp 分支/rknn-llm，移除 rkpostisp，security 移入 sysdrv/tools/board/security/）。

### repo 拉取方法（README.md）

```bash
mkdir RV1126B_Linux_IPC_SDK && cd RV1126B_Linux_IPC_SDK
repo init --repo-url https://github.com/GerritCodeReview/git-repo \
  -u git@iteam-gitlab.seeed.cn:rockchip/rv1126b-manifests.git \
  -b main -m recamera_v2_dev.xml
.repo/repo/repo sync --no-clone-bundle -c --no-tags -j4
```

## 不在 dev manifest 里的目录（平铺检出里的"编外"成员）

- `vqe_app` — 独立 VQE 音频 demo，任何 manifest 都没有（手工放的参考代码）
- `linux-ipc-app-RkPostISP` — AIISP 预编译库；dev/release manifest 均无（2025-10-27 v1.1.0 已移除），仅 media-pipeline.md 提及其关闭状态
- `rtos-rt-thread-docs` — 旧版 manifest（v0.1.0）曾挂 mcu/docs，现被 linux-ipc-bsp-mcu_docs 取代
- `linux-app-rkipc` — 遗留 rkipc fork（tuya/battery 变体）；dev manifest 里**有** linux-ipc-app-rkipc（project/app/rkipc/rkipc），注意区分
