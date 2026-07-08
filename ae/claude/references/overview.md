# reCamera Overview

## Wiki Scope

The skill distills the reCamera wiki set from:

`Seeed-Studio/wiki-documents/sites/en/docs/Edge/reCamera` on branch `docusaurus-version`.

The raw wiki markdown copies are intentionally not part of the skill. The distilled capability map is written directly in `SKILL.md`. For a new or changed wiki page, read the page itself, then apply this skill's distilled workflows.

Node-RED demos are not runnable recipes in this skill yet. C++ and system knowledge are distilled.

## Device Access

- USB/direct IP: `192.168.42.1`.
- Web UI: `http://192.168.42.1`.
- Key web routes: `/#/init`, `/#/workspace`, `/#/network`, `/#/security`, `/#/terminal`, `/#/system`, `/#/power`.
- Original Node-RED UI: `http://192.168.42.1:1880`.
- SSH user/password: `recamera` / `recamera.1` or `kkk000++`; prefer bundled wrappers, which try both unless `RECAMERA_PASSWORD` is set.
- Steven's bridge host: `seeed` at Tailscale `100.76.45.91` and LAN `192.168.4.7`, password `0`.

## OS and Services

reCamera OS is Buildroot-based and uses SysVinit scripts under `/etc/init.d`.

Common services:

- `S03node-red`: Node-RED.
- `S91sscma-node`: camera/model service used by Node-RED.
- `S93sscma-supervisor`: supervisor and web/backend service.
- `S98ttyd`: web terminal.
- `S50sshd`: SSH.

C++ camera demos usually need `S03node-red`, `S91sscma-node`, and `S93sscma-supervisor` stopped so the camera is not occupied.

## Model Knowledge

reCamera uses Sophgo CV181x/SG200X `.cvimodel` files.

Known wiki model downloads:

- `yolo11n_cv181x_int8.cvimodel`: `https://files.seeedstudio.com/wiki/reCamera/models/yolo11n_cv181x_int8.cvimodel`
- `yolov8n_cv181x_int8.cvimodel`
- `person_cv181x_int8.cvimodel`
- `gender_cv181x_int8.cvimodel`
- `gesture_cv181x_int8.cvimodel`
- `digital_meter_cv181x_int8.cvimodel`
- `yolo11n_drone_int8_sym.cvimodel`

`UDP_Face_Analysis` uses:

- `yolo-face_mixfp16.cvimodel`
- `age_gender_race_bf16.cvimodel`
- `emotion_bf16.cvimodel`

These are available from `RobotXTeam/sscma-example-sg200x` release `v1.0.1` and are also present locally in Steven's repo.

## Local Development Roots

Check these before downloading:

- `/home/seeed/sscma-example-sg200x`
- `/home/seeed/桌面/sg2002_recamera_emmc`
- `/home/seeed/桌面/host-tools`
- `/home/seeed/work/risc-v/recamera`
- `/home/seeed/reCamera-OS`

## Evidence Expectations

When asked to "run through" a demo, collect evidence appropriate to the demo:

- HTTP demo: response body plus server log.
- UDP video demo: a received frame saved as PNG/JPG plus sender stats.
- Web UI demo: screenshot through a local tunnel.
- Hardware demo: command log and exact hardware/credential blockers if any.
