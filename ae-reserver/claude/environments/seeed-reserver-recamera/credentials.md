# 凭据信息

## seeed-reserver 主机

- SSH 别名：`seeed-reserver`（Steven 本机 `~/.ssh/config` 已配置，且已加 Steven 公钥免密）
- 用户名：`seeed0`（注意：`seeed-reserver` 只是主机称呼/SSH 别名，登录用户名始终是 `seeed0`）
- 密码：`0`

## reCamera 设备

- SSH 用户名：`recamera`
- SSH 密码：**`kkk000++`**（2026-08-19 实测有效）；`recamera.1` 为备选（用户手动会话曾用过，自动化脚本实测被拒，保留兜底）
- 连接方式（在 seeed-reserver 上直接执行）：`ssh recamera@192.168.42.1`（USB gadget 默认地址 .1）
- 备用：LAN 地址 `192.168.2.102`（eth0，同网段直连）也可用；USB/LAN 任一路都可能瞬时不通，重试即可
- 封装脚本 `environments/seeed-reserver-recamera/scripts/recamera_ssh.sh` 已内置上述地址与密码（kkk000++ 优先）

## 安全注意事项

- 凭据以明文存储，仅用于开发/测试环境
- 生产环境应使用密钥认证
- 定期更换密码
