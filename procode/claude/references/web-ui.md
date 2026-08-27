# Web UI 栈（React 前端 + C++ CGI 后端 + nginx）

## 请求链路

```
浏览器 → nginx(:80, /oem/usr/www 静态 SPA)
  ├─ /cgi-bin/entry.cgi/<资源> → unix:/run/fcgiwrap.sock → entry.cgi（C++14 FastCGI）
  │       └─ socket_client → /var/tmp/rkipc（与 rkipc 通信）
  ├─ /ws/system/logs      → 127.0.0.1:8765（websocket_log.py）
  ├─ /ws/system/terminal  → 127.0.0.1:7681（ttyd）
  ├─ /ws/inference/results→ 127.0.0.1:8123（notify server）
  ├─ /go2rtc/             → 127.0.0.1:1984（WebRTC 实时视频）
  ├─ services API → /dev/shm/*.sock（gmgr/skt2ws/tmir/rcisd 的 unix 代理）
  ├─ /storage/relay/ → /var/www/rc_relay（vigil 录像文件）
  └─ SenseCraft 云反代（sensecraft.conf）
所有 WS/视频端点经内部 /_jwt_verify 子请求（重入 entry.cgi /auth_verify）做 JWT 门控
```

**WS 和实时视频不经过 entry.cgi**——只有 REST 走 FastCGI。

## 两个后端，别混淆

| | recamera_web_backend（现役） | new-mini_ipcweb-backend（遗留） |
|---|---|---|
| 目录 | `linux-app-web-recamera_web_backend` | `linux-app-web-new-mini_ipcweb-backend` |
| 开关 | `RK_APP_RECAMERA_WEB=y`（reCamera2 BoardConfig 已设） | `RK_APP_IPCWEB_BACKEND=y` / `RK_ENABLE_WEB_BACKEND=y` |
| 前端 | React SPA（源码在 recamera_web_react） | 预编译 www-rkipc（.gz，无源码，无法重建） |
| 模块 | network/video/audio/image/system/osd/event/peripherals/**model/notify/record(vigil)/config**/ftp/web + auth_verify | network/storage/video/audio/stream/image/system/osd/roi/event/peripherals |
| JWT | 默认 ON | 默认 OFF |

另注意：React 仓库内的 `backend/`（FastAPI, :8000）只是**本地开发 mock**，设备上跑的永远是 C++ entry.cgi。

## 前端（linux-app-web-recamera_web_react）

- **React 18 + CRA（react-scripts 5.0.1，不是 Vite）**、react-router-dom v7、axios、xterm.js、Tailwind 4、javascript-obfuscator（产物混淆，别指望可读）
- package 名 `ai-camera-web`。Node 未显式 pin（react-scripts 5 ⇒ Node 16/18 可用）
- 关键文件：
  - `src/App.js` — 路由：/preview /device-info /live-view /record-settings /ai-inference /terminal
  - `src/contexts/API.js` — axios 实例；baseURL `/cgi-bin/entry.cgi/`；dev 模式 `host.replace('3000','8000')` 指向 mock——**不要"修复"这行**，生产 bundle 里 host 无 :3000 自然走相对路径
  - `src/contexts/urls.js` — 全部 API 路由表 + WS URL
  - `src/pages/LiveView.js` + `src/components/live_feed/Player.js` — go2rtc WebRTC
  - `AGENTS.md` — 铁律：任何 UI 改动必须过 i18n(zh/en) + 明暗主题 + 响应式检查；完成前必须 `npm run build`
- 仓库根 `nginx.conf` 是"本地 :3000 dev server 对接真机 API"的 CORS 配方（Access-Control-Allow-Origin、OPTIONS 预检、暴露 File-Id/Content-Range）——对真机 nginx 改这套即可联调

## 后端（linux-app-web-recamera_web_backend）

- C++14，CMake 交叉编译（cgicc、nlohmann_json、jwt-cpp、MiniLogger；链 rkdb/gdbus/IPCProtocol）；`-DUSE_RKIPC=ON`、`ENABLE_JWT=ON`
- 入口 `src/main.cpp` → `ApiEntry::getInstance().run()`；`src/rest_api.cpp` 解析 PATH_INFO 分发（新增资源 = 注册 HandlerEntry）
- JWT：secret `/userdata/config/system/jwt_secret.key`；localhost 旁路（nginx geo → `HTTP_X_INTERNAL_FROM_LOCALHOST`；经 LAN 代理来的**不算** localhost）
- `ipcweb-env-rv1126b/` = staging tarball：etc/nginx/*.conf、etc/init.d/S55fcgiwrap、usr/bin/cgi-fcgi、usr/sbin/fcgiwrap、include/{cgicc,nlohmann}——**预编译二进制，视为只读依赖**；arm64 时用 usr-arm64
- HTTPS 是 80 端口配置的 overlay：条件 include `/userdata/config/system/ssl/{https_enable,rewrite_enable}.conf`

## 构建流程

> 前提：以下 SDK 构建命令都要求**嵌套树**（project/app/recamera_web 及其嵌套子仓库已按 tree.txt 组装，见 build.md）；平铺检出里唯一能直接跑的是 React 仓库内的 npm 命令。

mk 包装（`linux-ipc-project-app-mk_recamera_web`，挂载点 `project/app/recamera_web/`，recamera_web_backend 与 recamera_web_react 为其嵌套子目录）：

```
ipcweb-build:
  1. 拷 ipcweb-env-rv1126b/{usr|usr-arm64}/. → out/usr/
  2. cmake 后端（-DCMAKE_*_COMPILER=$(RK_APP_CROSS)-gcc/g++ -DCMAKE_INSTALL_PREFIX=out
     -DCMAKE_BUILD_TYPE=Release -DUSE_RKIPC=ON）→ make install → out/www 移到 out/usr/www
  3. 拷 ipcweb-env etc/ → out/etc（nginx confs + S55fcgiwrap）
  4. make -C recamera_web_react：check-node → npm install --legacy-peer-deps（失败再裸 install）
     → npm run build → build/* 拷入 ../out/usr/www（**保留 cgi-bin/**，find ... ! -name 'cgi-bin' -exec rm）→ chmod 775
  5. MAROC_COPY_PKG_TO_APP_OUTPUT → app_out → rootfs/oem 打包
```

## 开发迭代方式

```bash
# 仅前端改动（最快路径）
cd linux-app-web-recamera_web_react && npm run build
# 把 build/* 拷到设备 /oem/usr/www（千万别删 cgi-bin/），nginx 立即生效

# 本地全栈（无设备）
npm start                                    # CRA dev server :3000
pip install -r requirements.txt              # backend/（FastAPI mock）
python -m app  # uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

# 对真机联调（本机 :3000 + 真机 API）：按仓库根 nginx.conf 的 CORS 配方改设备 nginx

# 后端改动：编辑 src/*_api.cpp → ./build.sh app（或 make -C project/app/recamera_web）→ ./build.sh firmware

# 设备上重载 nginx
nginx -c /oem/usr/etc/nginx/nginx.conf -s reload
```

## 关键坑

1. **CRA 不是 Vite**——没有 vite.config，只能 `npm run build`；主机必须有 node/npm（Makefile check-node 目标）。
2. 前端拷贝步骤刻意保留 `out/usr/www/cgi-bin`——在设备上裸 `rm -rf www` 重部署会杀掉 API。
3. 新增 WS 端点要**同时**改 nginx（common_relay.conf / svc_*.conf include）和 JWT 门控。
4. nginx 1.24.0 + nginx-http-flv-module 由 `linux-ipc-media-nginx_mk` 在构建时从互联网 wget——离线构建需预放 tarball。
5. 仓库根 nginx.conf 里 listen 1935 的 RTMP/FLV 块是遗留 demo 配置；设备上实际生效的是 ipcweb-env 里的 nginx.conf（无 rtmp 块）。
6. entry.cgi ↔ rkipc 的 unix socket 协议（`src/socket_client/socket.h`，CS_PATH=/var/tmp/rkipc）是硬编码的，客户端服务端必须同步改。
7. 后端需要 `RK_APP_BUILDROOT_STAGING`（librtmp 等来自 buildroot staging）。
8. 前端仓库曾为迁移 SG2002 做过修改（本仓库是 RV1126B 原版）；登录密码 AES-128-ECB 等测试细节见项目记忆。

## 关键文件索引

- `linux-app-web-recamera_web_react/{Makefile, package.json, AGENTS.md, nginx.conf}`
- `linux-app-web-recamera_web_react/src/{App.js, contexts/API.js, contexts/urls.js}`
- `linux-app-web-recamera_web_backend/src/{main.cpp, rest_api.cpp, common.cpp, vigil_api.cpp(/record/* → vg_http_api_*)}`
- `linux-app-web-recamera_web_backend/ipcweb-env-rv1126b/etc/nginx/{nginx.conf, common_relay.conf, svc_*.conf, rc_relay.conf, sensecraft.conf}`
- `linux-ipc-project-app-mk_recamera_web/Makefile`
- `linux-ipc-media-nginx_mk/{Makefile, S56nginx}`
