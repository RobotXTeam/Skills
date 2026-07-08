# Device Operations

## SSH Through seeed

Use the bundled wrapper:

```bash
/home/steven/.codex/skills/recamera/scripts/recamera_ssh.sh 'hostname; whoami'
```

Equivalent raw command:

```bash
sshpass -p '<recamera.1-or-kkk000++>' ssh \
  -o StrictHostKeyChecking=accept-new \
  -o PreferredAuthentications=password,keyboard-interactive \
  -o PubkeyAuthentication=no \
  -o ProxyCommand="sshpass -p 0 ssh -o StrictHostKeyChecking=accept-new seeed nc 192.168.42.1 22" \
  recamera@dummy 'command'
```

## Copy Files to reCamera

Use local `scp` with the same proxy:

```bash
sshpass -p '<recamera.1-or-kkk000++>' scp \
  -o StrictHostKeyChecking=accept-new \
  -o PreferredAuthentications=password,keyboard-interactive \
  -o PubkeyAuthentication=no \
  -o ProxyCommand="sshpass -p 0 ssh -o StrictHostKeyChecking=accept-new seeed nc 192.168.42.1 22" \
  local-file recamera@dummy:/home/recamera/
```

## Stop Camera-Owning Services

For C++ camera demos:

```bash
sudo /etc/init.d/S03node-red stop 2>/dev/null || true
sudo /etc/init.d/S91sscma-node stop 2>/dev/null || true
sudo /etc/init.d/S93sscma-supervisor stop 2>/dev/null || true
```

If `sudo` asks for a password, use the active reCamera password: usually `recamera.1`, but it may be `kkk000++`. Do not delete init scripts unless explicitly requested.

Restart after tests:

```bash
sudo /etc/init.d/S93sscma-supervisor start 2>/dev/null || true
sudo /etc/init.d/S91sscma-node start 2>/dev/null || true
sudo /etc/init.d/S03node-red start 2>/dev/null || true
```

## UDP Target IP

When the receiver runs on `seeed`, use `seeed`'s USB interface IP on the `192.168.42.0/24` network:

```bash
/home/steven/.codex/skills/recamera/scripts/seeed_usb_ip.sh
```

Pass that IP to reCamera UDP demos. This address can change after reCamera reboots or USB reconnects; always re-read it immediately before starting a sender.

## Tunnels and Screenshots

For web screenshots, use SSH local forwarding through `seeed`:

```bash
sshpass -p 0 ssh -N -L 18080:192.168.42.1:80 seeed
```

Then open `http://127.0.0.1:18080` with Playwright or a browser and save screenshots under `/tmp/recamera-*`.

## Official OpenCV Receiver Recording

For wiki QA evidence, prefer the official wiki/repository receiver script instead of a custom renderer. On `seeed`, use Xvfb plus `ffmpeg x11grab`:

```bash
sshpass -p 0 ssh seeed 'nohup Xvfb :99 -screen 0 1280x720x24 >/tmp/recamera_xvfb.log 2>&1 & echo $! >/tmp/recamera_xvfb.pid'
sshpass -p 0 ssh seeed 'cd /home/seeed/recamera_wiki_recording && DISPLAY=:99 python3 -u ./udp_receiver.py'
sshpass -p 0 ssh seeed 'ffmpeg -y -f x11grab -draw_mouse 0 -video_size 640x700 -framerate 24 -i :99.0+0,0 -t 30 out.mp4'
```

Record the actual window area shown by `DISPLAY=:99 xwininfo -root -tree`. If the user asks for visual proof, provide the MP4 path and a representative frame.
