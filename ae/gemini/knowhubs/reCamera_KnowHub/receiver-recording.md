# Official Receiver Recording

在 `seeed` 上，在 Xvfb 下运行官方接收端脚本：

```bash
sshpass -p 0 ssh seeed 'nohup Xvfb :99 -screen 0 1280x720x24 >/tmp/recamera_xvfb.log 2>&1 & echo $! >/tmp/recamera_xvfb.pid'
sshpass -p 0 ssh seeed 'cd /home/seeed/recamera_wiki_recording && DISPLAY=:99 python3 -u ./udp_receiver.py'
sshpass -p 0 ssh seeed 'DISPLAY=:99 xwininfo -root -tree'
sshpass -p 0 ssh seeed 'ffmpeg -y -f x11grab -draw_mouse 0 -video_size 640x700 -framerate 24 -i :99.0+0,0 -t 30 out.mp4'
```

使用 `xwininfo` 获取的实际窗口大小/位置。对于测试过的 OpenCV Qt 窗口，`640x700+0+0` 是正确的。
