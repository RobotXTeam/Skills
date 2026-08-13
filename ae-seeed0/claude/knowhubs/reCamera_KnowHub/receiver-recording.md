# Official Receiver Recording

在 `seeed0` 上，在 Xvfb 下运行官方接收端脚本（Xvfb、ffmpeg 均已安装在 seeed0；SSH 别名 seeed0 已免密，无需 sshpass）：

```bash
ssh seeed0 'nohup Xvfb :99 -screen 0 1280x720x24 >/tmp/recamera_xvfb.log 2>&1 & echo $! >/tmp/recamera_xvfb.pid'
ssh seeed0 'cd /home/seeed0/sscma-example-sg200x/solutions/sesg-project/face_udp && DISPLAY=:99 python3 -u ./udp_receiver.py'
ssh seeed0 'DISPLAY=:99 xwininfo -root -tree'
ssh seeed0 'ffmpeg -y -f x11grab -draw_mouse 0 -video_size 640x700 -framerate 24 -i :99.0+0,0 -t 30 out.mp4'
```

使用 `xwininfo` 获取的实际窗口大小/位置。对于测试过的 OpenCV Qt 窗口，`640x700+0+0` 是正确的。

## 使用原则

- 做 wiki QA 证据时，优先使用官方 wiki/仓库自带的接收端脚本，不要用自绘渲染器替代。
- 用户要求视觉证明时，提供 MP4 路径和一张代表帧。
