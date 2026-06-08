# 网络配置

## 网络拓扑

- PC -> `seeed`：SSH 别名 `seeed`，用户 `seeed`，密码 `0`。
- seeed LAN：`192.168.4.7`。
- seeed Tailscale：`100.76.45.91`。
- seeed OS：Ubuntu 22.04。
- `seeed` -> reCamera：直接 USB/LAN `192.168.42.1`。
- reCamera SSH：用户 `recamera`，密码 `recamera.1`。
- reCamera OS API：`http://192.168.42.1/api/version`，最后验证 `0.2.3`。
- reCamera OS：Buildroot 2021.05，Linux 5.10.4 RISC-V。

## 动态 IP 处理

重要：seeed 在 `192.168.42.0/24` 上的 USB IP 在 reCamera 重启或 USB 重连后会变化。永远不要硬编码旧值如 `192.168.42.197`。总是运行：

```bash
/home/steven/.claude/skills/ae/environments/seeed-recamera/scripts/seeed_usb_ip.sh
```
