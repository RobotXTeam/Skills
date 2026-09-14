---
name: ZTEWifi
description: Operational playbook for Steven's ZTE F50 5G pocket WiFi (storage edition, MU300HW1.0). Use for ANY work on this device: adb/shell, web admin goform API, flashing/downgrade/root/Magisk, UFI-TOOLS, the OpenWrt-in-netns container router (LuCI/DHCP/NAT), recovery/unbrick, USB networking, storage, or proxy plans. Invoke whenever the user mentions F50, 随身WiFi, UFI, the 192.168.0.1 / 192.168.1.1 pocket router, or "that 5G box".
---

# ZTE F50 (storage edition) playbook

All procedures verified on this exact device (adb serial 324950664950). Prefer these commands over re-deriving.

## Device facts

- ZTE F50 存储版: Unisoc T760, 4 cores, ~1.5GB RAM, 228GB userdata (**f2fs**, not FAT32 — >4GB files fine via adb push/MTP), Android 13, kernel **5.4.254**, embedded China Mobile SIM. No screen, **no power button**: plug USB = on, unplug = cold boot.
- Firmware **B09** `F50_FLYMODEM_ZYV1.0.0B09` (cr_version `MU300_ZYV1.0.0B09`), **Magisk v30.7 root, BL unlocked**, SELinux **Permissive**, slot_a.
- USB IDs: normal `19d2:1353` (ECM + MTP + ADB); bootrom/download `1782:4d00`.
- Kernel lacks: **CONFIG_PID_NS** (no pid namespaces → no procd/docker/runc), **CONFIG_NF_TABLES** (no nftables → iptables-legacy userland unavailable in 23.05 feeds; fw3/fw4 unusable). Has NET_NS, VETH, TUN, xtables NAT.
- Android /data is **nodev** → device nodes only work on tmpfs/devtmpfs mounts.
- Android keeps default route in **per-uid policy tables** (table sipa_eth8 etc.); forwarded (uid-less) packets need explicit `ip rule from <subnet> lookup sipa_eth8`.
- /proc mounted hidepid=2,gid=3009; fresh proc mounts inside new mount ns are unreliable → track daemons by `$!` pid + `kill -0`, never pgrep from inside container.

## Connect

- ADB over USB when `usb_port_switch=1`; root via `adb shell su -c '...'`. Magisk Superuser toggle for new apps: Magisk app → Superuser (screen 480x854; switch ~[410,220]).
- Web admin `http://192.168.0.1` user/pass **admin** (factory WiFi SSID `ZTE_<hex>`, pass `1234567890`).
- OpenWrt container LAN: **192.168.1.1** (LuCI login root/admin; uhttpd :80). Android mgmt veth subnet 192.168.9.0/24 (.1 android, .2 container WAN).
- Qiang host: F50 USB NIC `enx5c7dae3bdad3`, NM conn "有线连接 2" set `ipv4.never-default=yes` + `route-metric 2000` → plugging F50 never steals default route (WiFi stays primary).

## Web goform API (no browser)

Login hash UPPERCASE hex: `P=SHA256(SHA256(password)+LD)` via `goform_get_cmd_process?cmd=LD`, then `goformId=LOGIN&password=$P` (keep cookies). Write ops need `AD=SHA256(SHA256(wa_inner_version+cr_version)+JSESSIONID)`; refresh JSESSIONID via `cmd=RD`. Useful goformIds: `USB_PORT_SETTING` (usb_port_switch=1 → ADB iface), `REBOOT_DEVICE`, `PERFORMANCE_MODE_SETTING`, `SET_USB_NETWORK_PROTOCAL` (0 auto/1 RNDIS/2 CDC-ECM).

## OpenWrt-in-netns router (the main event)

Layout on device: rootfs `/data/adb/owrt/rootfs` (OpenWrt 23.05.6 armsr), scripts `/data/adb/owrt/{start.sh,watch.sh,supervise.sh(in rootfs/)}`, boot hook `/data/adb/service.d/owrt.sh`.

- `start.sh ensure|running|stopc|stop` — idempotent: netns `owrt`, veth-wan↔eth0, moves USB ECM netdev (usb0|rndis0|ecm0, or stranded eth1) into ns as eth1, Android-side NAT chain OWRT_NAT (MASQUERADE for 192.168.9.0/24 **and** 192.168.1.0/24 + FORWARD accepts + ip rules into sipa table), then container = `toybox unshare -mu` + bind /proc,/sys + chroot + `/init-container.sh` (tmpfs /dev with mknods, /tmp) → `/supervise.sh`.
- supervise (no procd!): starts ubusd, netifd, dnsmasq (static /etc/dnsmasq.conf: eth1+lo, 192.168.1.100-249), rpcd, uhttpd; tracks pids via `$!`. Container only forwards (`ip_forward=1`); **all MASQUERADE lives on Android**.
- uhttpd args that work: `-p 0.0.0.0:80 -h /www -x /cgi-bin -u /ubus -U /var/run/ubus.sock -t 60` with env `UBUS_SOCKET=/var/run/ubus.sock` (`-u` = URL prefix, `-U` = socket path; libubus default connect() returns null otherwise).
- LuCI 23.05 = ucode; **no procd ⇒ no `system` ubus object** → patched theme header `.../template/themes/bootstrap/header.ut` boardinfo with `?? {hostname:'f50owrt',...}` fallback; rpcd ucode plugin dir is `/usr/share/rpcd/ucode/` (a `system.uc` plugin lives there but rpcd ACL hides it; template fallback is what makes pages render).
- LuCI quirks: sends 403/500 without `Accept-Language` header only for curl — browsers fine; login POST `luci_username/luci_password` → 302. Device list = luci-rpc getDHCPLeases (works).
- opkg on device: feeds must be `src` (NOT `src/gz` — this opkg stores gz raw), `option check_signature 0`, `TMPDIR=/tmp` (Android TMPDIR leaks), one-shot helper `/opkgentry.sh` inside rootfs (mounts dev/tmpfs first!). 23.05 feeds have NO iptables-legacy → don't try firewall packages.
- Stale-generation hazard: killing supervise leaves daemons holding ports (uhttpd :80, dnsmasq :53) → new gen fails to bind while OLD broken one keeps serving. Always `start.sh stop` (kills all procs with rootfs root) before `ensure`; verify single pid per daemon.
- Reboot persistence verified: service.d hook → ensure + watch.sh (60s: re-move usb netdev, re-add NAT/rules, restart dead container). Daemon RSS total ~8MB.

## Flashing / recovery (Linux-native, no Windows)

- spd_dump: TomKing062/spreadtrum_flash fork (`make`, needs libusb-1.0 dev; plugdev group = no sudo). Catch bootrom: start listener with `--wait N --kickto 2` FIRST, then replug USB (soft reboot does NOT expose bootrom; bricked devices self-cycle bootrom ~every 2min).
- Backup: `spd_dump --wait 300 --kickto 2 exec path <dir> r all reset`. Flash: `... write_parts <romdir>/ e userdata reset` (`e userdata` = write boot-recovery into misc + erase persist = factory reset next boot). Root: `... w trustos f50b09_t.bin w boot magiskf50b09.img reset`.
- Assets: B08 full backup `/home/steven/work/f50/backups/` (75 parts), stock B09 ROM `/home/steven/work/f50/zte-f50-b09/`, magisk imgs `/home/steven/work/f50/`. Toolkit zip: github dikeckaan/zte-f50-toolkit release releasev1 (via proxy 127.0.0.1:7897).
- write_parts silently skips splloader + (on this unit) nr_phy_a/vbmeta_vendor_a → post-flash bootloop fix: rescue-route `exec_addr 0x65012f48 fdl fdl1-dl.bin 0x65000800 fdl fdl2-dl.bin 0xb4fffe00 exec w splloader ... w nr_phy_a ... w vbmeta_vendor_a ... reset`.
- veth/netns leftovers: netns delete strands renamed ifaces in default ns — ensure_usb handles stranded eth1; ensure_veth validates @ifindex pairing and recreates on mismatch.
- **Recovery rules**: never flash trustos alone; de-root/re-lock = full write_parts from backups/ (B08) or zte-f50-b09/ (B09). Never OTA. Never patch-modem/IMEI tools.

## Done / not-done

- Done: B08→B09 downgrade, root, UFI-TOOLS v4 (:2333, autostart), OpenWrt container router with LuCI + DHCP + NAT, boot persistence, watchdog.
- Not done: mihomo/proxy inside container (plan: mihomo arm64 + TPROXY in container netns; dashboard = metacubexd static via uhttpd); end-to-end LAN-client WAN test with a real second device; Clenix (provider OpenWrt-only client) never obtained — 23.05 fw3/fw4 dead on this kernel anyway, ask provider for mihomo/sing-box core instead.

## Addons installed 2026-09-06 (and hard limits found)

- **Argon theme**: deployed from jerrykuku/luci-theme-argon (ucode variant); `mediaurlbase=/luci-static/argon` in /etc/config/luci. **Repo htdocs/ == /www** (stage htdocs/* into rootfs /www, NOT root!). Statics live /www/luci-static/argon + /www/luci-static/resources/menu-argon.js. Cost: static files only, ~0 RAM. If LuCI renders unstyled HTML, check asset 404s first.
- **iptables-legacy v1.8.9**: cross-built on Qiang (aarch64-linux-gnu-gcc, dynamic glibc) + glibc libs copied to rootfs /lib (ld-linux-aarch64.so.1, libc.so.6, libm.so.6); /usr/sbin/xtables-legacy-multi with iptables* symlinks; rootfs needs `/run -> var/run` symlink for xtables.lock. Kernel legacy xtables built-in → works.
- **opkg on this device is unreliable**: many packages "download then not install" (luci-compat, ucode-mod-lua, liblua, lua, luci-lua-runtime...). Workaround: download ipk on host (ipk here = gzip tar, NOT ar!), extract data.tar.gz, push tarball, extract into rootfs manually.
- **Lua LuCI apps are PERMANENTLY BROKEN here**: libubus-lua `ubus.connect()` returns nil,err 9 inside the live container even though C `ubus` CLI and ucode ubus connect fine to the same socket. ⇒ OpenClash/M78 LuCI pages 500 forever. Don't retry this rabbit hole.
- **OpenClash**: files installed (/usr/share/openclash, luci pages) but UNRUNABLE: init needs procd (kernel has no PID_NS) and UI needs the broken lua-ubus. Verdict: dead on this device.
- **M78Accelerator (provider client)**: backend `/usr/bin/netflow` (static aarch64 Go, symlink netflow_aarch64) runs headless under supervise; listens 127.0.0.1:9190; exposed to LAN via container nat PREROUTING DNAT 192.168.1.1:9190→127.0.0.1:9190 + `route_localnet=1`. Config: /etc/config/netflow (uci, enable=1); mihomo core expected at /etc/netflow/mihomo/mihomo (backend fetches/spawns after provider v2board login via API 9190: actions login/subscribe/node/mode...).
- **metacubexd dashboard**: /www/metacubexd/ (http://192.168.1.1/metacubexd/) for the mihomo core once running (point it at mihomo external-controller).
- Debugging container internals: one-shot `chroot` does NOT see container tmpfs (/tmp,/var/run sockets)! Use `toybox nsenter -m -t <pid> -- chroot /proc/<pid>/root ...` to enter the live mount ns. /proc/net/* read via `ip netns exec owrt cat /proc/net/tcp` shows container netns sockets.
- Memory baseline: router daemons ~8MB + M78 backend ~15MB RSS; Android MemAvailable ~500MB of 1.5GB.

## Overview page "?" fields fix (2026-09-06)

- rpcd-mod-ucode is DEAD on this rootfs (scripts in /usr/share/rpcd/ucode/ never publish; the `luci` ubus object comes from rpcd-mod-luci C plugin). No `system` board/info object => LuCI overview showed "?".
- Fix: CGI `/www/cgi-bin/sysinfo` (shell, JSON: hostname/model/arch/release/kernel/localtime/uptime/load*65535/memory/swap from /proc) + replaced `/www/luci-static/resources/view/status/include/10_system.js` (fetch CGI instead of ubus system board/info) + added `20_memory.js` include (memory table from CGI). Overview = include modules in /www/luci-static/resources/view/status/include/*.js; add files there to add sections.
- Qiang dual-link SAFE config (do not regress): wifi con metric 600 = default route; "有线连接 2": never-default=yes, route-metric 2000 (mgmt only). NM adds +20000 base metric to usb-cdc-ether routes — cannot make it primary via metric; switching to 5G-primary needs `nmcli dev reapply` (no wifi reconnect) + user-present verification + instant rollback.
- Wired-client internet path verified via simulated client in container (dummy 192.168.1.200 → ping internet 3/3).

## ubus socket path + online devices + storage (2026-09-06 late)

- **libubus on this build is compiled with default socket `/var/run/ubus/ubus.sock`** (extra dir!). All daemons now use UBUS=/var/run/ubus/ubus.sock (supervise var); init-container mkdirs /var/run/ubus. UBUS_SOCKET env does NOT override this lib. Any "Failed to connect to ubus" from CLI/lua = wrong socket path.
- **在线设备 page ported from FriendlyWrt**: /www/luci-static/resources/view/status/online_devices.js + /usr/share/luci/menu.d/99-online-devices.json + /usr/share/rpcd/acl.d/luci-app-online-devices.json + /usr/libexec/online-devices-dump (lua; needs ubus CLI default socket + `ip neigh` on lan ifname auto-detected eth1). Menu: 状态 → 在线设备.
- **Storage stats**: container mount ns lacks /data; android-side watch.sh/ensure writes `df -k /data` line to `/www/.dfcache` (real dir visible in chroot); CGI sysinfo merges it as Internal storage (userdata 256G f2fs) + container tmpfs entries; 25_storage.js include renders from CGI.
- Container /bin lacks: head, awk?, env, stat, cat? (busybox subset differs) — write CGIs with shell builtins/awk-careful; test via nsenter chroot.

## Current state 2026-09-09

- F50 physically UNPLUGGED from Qiang since ~09-07 (no USB, adb empty). All device-side state persists on-device: B09+root, argon+zh_CN UI (footer stripped), storage/online-devices/overview fixes, M78 backend+LuCI page+OpenClash page, DNAT ports 9190/7890/9091.
- Qiang home WiFi subnet now 192.168.178.0/24 (gw .214) — was 192.168.26.0/24 before 09-06 outage. NM "有线连接 2" safe-config (never-default, metric 2000) still in place for when F50 replugs.
- M78 proxy INACTIVE pending user login: LuCI 服务→M78加速器 → account login → backend spawns mihomo (subscribe.enc from FriendlyWrt is device-bound, relogin required). OpenClash page renders but has no core; M78 is the designated engine.
- Reconnect checklist: plug USB → wait 60s → verify `adb devices`, DHCP .1.x on enx, luci 200, m78 :9190; if ADB missing: goform usb_port_switch=1 + reboot (see goform section).
