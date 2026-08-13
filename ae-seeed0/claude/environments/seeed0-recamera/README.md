# Seeed reCamera 测试环境

这是当前的 reCamera 测试环境配置，基于 seeed0 主机和 reCamera 设备。

## 网络拓扑

```
PC → seeed0 (SSH) → reCamera (USB/LAN)
```

## 文件说明

- `network.md` - 网络配置（IP 地址、动态 IP 处理）
- `credentials.md` - 凭据信息（SSH 密码等）
- `toolchain.md` - 工具链配置（SDK、编译器路径）
- `development-policy.md` - seeed0 主机开发和仓库操作规则
- `scripts/` - 辅助脚本目录（其中 `scripts/preflight.sh` 是部署前一键体检：检查 seeed0/reCamera 连通性、设备状态、模型/工具链就绪情况，部署新 demo 前建议先跑）

## 使用方法

在 AE Agent 的工作流中，通过相对路径引用此环境配置：

```
environments/seeed0-recamera/network.md
```

## 替换环境

如果需要使用不同的测试环境，可以创建新的环境目录（如 `environments/new-host-device/`），并保持相同的文件结构。
