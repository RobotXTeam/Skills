# C++ 运行时与编译基线

## 交叉编译基线

reCamera 无本地 C/C++ 构建环境，需在 Linux 主机交叉编译后把可执行程序拷到设备。

环境变量（用变量，不要写死绝对路径）：

```bash
export SG200X_SDK_PATH=$SDK_ROOT
export PATH=$TOOLCHAIN_BIN:$PATH
```

构建：

```bash
cd $REPO_ROOT/solutions/<demo>
rm -rf build && mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_FLAGS="-std=c++17" ..
make -j$(nproc)
```

验证产物架构是 RISC-V/musl 而非 x86_64：

```bash
file build/<binary>
```

## 部署模式

1. 在 reCamera 创建 `/home/recamera/<demo>`。
2. 拷贝可执行程序、模型、脚本（scp 见 `device-ops.md`）。
3. `chmod +x` 可执行程序。
4. 停止占用摄像头的服务（见下）。
5. 用显式 UDP 目标或 HTTP 端口运行。
6. 采集日志和证据。
7. 除非用户要求 demo 留驻，否则测试后重启服务。

## 停服务命令

运行 C++ 摄像头 demo 前，停止占用摄像头的服务：

```bash
sshpass -p "$RECAMERA_PASSWORD" ssh recamera@192.168.42.1 \
  'sudo /etc/init.d/S03node-red stop 2>/dev/null || true; \
    sudo /etc/init.d/S91sscma-node stop 2>/dev/null || true; \
    sudo /etc/init.d/S93sscma-supervisor stop 2>/dev/null || true'
```

`sudo` 要密码时用你自己的 reCamera 密码（`RECAMERA_PASSWORD`）。不要删除 init 脚本除非明确要求。

## LD_LIBRARY_PATH

```bash
LD_LIBRARY_PATH=/mnt/system/lib:/mnt/system/usr/lib:/mnt/system/usr/lib/3rd:$LD_LIBRARY_PATH
```

## 重启恢复

激进清理进程后用重启恢复：

```bash
sshpass -p "$RECAMERA_PASSWORD" ssh recamera@192.168.42.1 'sudo reboot'
```

重启后验证设备就绪：

```bash
curl -s --max-time 5 http://192.168.42.1/api/version
```
