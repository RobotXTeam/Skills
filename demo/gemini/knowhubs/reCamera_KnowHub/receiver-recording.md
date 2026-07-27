# 接收端录制

为质量门和证据采集，优先用官方 wiki/仓库的接收端脚本，而非自写渲染器。在接收端主机上用 Xvfb + ffmpeg x11grab 录制。

## 启动虚拟显示

```bash
nohup Xvfb :99 -screen 0 1280x720x24 >/tmp/recamera_xvfb.log 2>&1 & echo $! >/tmp/recamera_xvfb.pid
```

## 运行官方接收端

```bash
cd <receiver_dir> && DISPLAY=:99 python3 -u ./udp_receiver.py
```

## 录制窗口

```bash
DISPLAY=:99 xwininfo -root -tree   # 查实际窗口大小/位置
ffmpeg -y -f x11grab -draw_mouse 0 -video_size 640x700 -framerate 24 -i :99.0+0,0 -t 30 out.mp4
```

用 `xwininfo` 读到的实际窗口区域录制。对测试过的 OpenCV Qt 窗口，`640x700+0+0` 可用。需要可视证据时，提供 MP4 路径和一帧代表帧。
