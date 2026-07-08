# C++ Camera Runtime Baseline

## 停服务命令

在运行 C++ 摄像头 demo 前，需要停止占用摄像头的服务：

```bash
/home/steven/.codex/skills/ae/environments/seeed-recamera/scripts/recamera_ssh.sh "for p in 'recamera.1' 'kkk000++'; do printf '%s\n' \"\$p\" | sudo -S true 2>/dev/null && break; done; sudo /etc/init.d/S03node-red stop || true; sudo /etc/init.d/S91sscma-node stop || true; sudo /etc/init.d/S93sscma-supervisor stop || true"
```

## LD_LIBRARY_PATH 设置

使用以下运行时库路径：

```bash
LD_LIBRARY_PATH=/mnt/system/lib:/mnt/system/usr/lib:/mnt/system/usr/lib/3rd:$LD_LIBRARY_PATH
```

## 重启恢复

在激进的进程清理后，通过重启恢复：

```bash
/home/steven/.codex/skills/ae/environments/seeed-recamera/scripts/recamera_ssh.sh "for p in 'recamera.1' 'kkk000++'; do printf '%s\n' \"\$p\" | sudo -S true 2>/dev/null && break; done; sudo reboot"
```

然后验证：

```bash
sshpass -p 0 ssh seeed 'curl -s --max-time 5 http://192.168.42.1/api/version'
```
