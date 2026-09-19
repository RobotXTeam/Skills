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
- **RAM: the 2GB spec is real but Android only gets 1468MB** — `androidboot.ddrsize=2048M` in /proc/cmdline, ~580MB carved out at boot for modem/CP + TrustZone/reserved. `MemFree` sits at ~20MB **by design** (Linux fills the slack with page cache; Cached ~420MB + zram 367MB is normal): always quote **`MemAvailable` (~460-500MB)** when reporting free memory, never MemFree. Total RSS of all processes ~3.6GB > RAM = shared mappings + swapped-out pages (zram compresses ~5:1).
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

## C-port / SIPA truth + the 192.168.1.x recipe (verified 2026-09-19)

**Why C口 always came out 192.168.0.x and never traversed OpenWrt:** in RNDIS mode the USB data plane is
`br0` (192.168.0.1/24) with bridge ports `sipa_usb0` + `wlan0`. The C port is therefore **L2-identical to the
hotspot** — both are just br0 ports. `tetherableUsbRegexs: [sipa_usb\d, rndis\d]`; the gadget function netdevs
(`usb0`/`ecm0`/`ncm0`) are NOT tetherable. Any script that "moved usb0 into the owrt netns" captured an
**unbound, zero-traffic** interface → container never saw client DHCP/traffic. Autostart was never the problem.

**Working design (end-to-end tested on-device: client got 192.168.1.210 / gw .1 / dns .1, ping 223.5.5.5 3/3 @41ms, DNS ok):**
container LAN = a veth **bridged into br0**, not a captured USB netdev.
- host end `owrt-br` (master br0) ↔ ns end `eth1` = 192.168.1.1/24, plus mgmt alias `192.168.0.2/24`,
  container default via **192.168.0.1** (Android) — the old `veth-wan` 192.168.9.0/24 leg now has broken
  unicast ARP (`192.168.9.1 FAILED` in container neigh, Android→9.2 100% loss); use `http://192.168.0.2` for LuCI.
- Silence Android's tether dnsmasq so only OpenWrt answers: `iptables -I INPUT -i br0 -p udp --dport 67 -j DROP`
  (works because br_netfilter is NOT loaded, so bridged DHCP still reaches the container). **Ordering matters and was
  a real bug:** the rule must go in only *after* the container's dnsmasq is listening, else clients in that window get
  no address at all (169.254) — `start.sh` now does this in `dhcp_takeover()` (polls `/proc/net/udp` `:0035` in the ns,
  max 6 s, and leaves Android serving if the container isn't up). Also `ensure()` must not call `stopc` unconditionally:
  its double `/proc` scan costs **~16 s** on the critical path — now gated on a stale `:53`/`:80` listener existing.
  The `service.d/owrt.sh` hook has **no sleeps**: it loops `ensure` every 1 s until the handoff is done. Measured boot
  (log at `/data/adb/owrt/owrt.log`, `grep -v '[sup]'`): hook@9-11 s → netns/veth/NAT same second → supervisor@16 s
  → **dhcp handoff@23 s** (was 47 s, then 38 s before the stopc fix).
- **Residual boot race (documented, not fixable from the device):** Android's br0 + tether dnsmasq come up before the
  container can answer, so a client whose link returns inside `[br0 up .. +23 s]` keeps a **192.168.0.x** lease. It can
  never be NAK'd — its renewals are unicast to `192.168.0.1` (br0's own MAC ⇒ delivered to Android's input path, never
  flooded to `owrt-br`) and simply get dropped — so it self-heals only at T2 (~21 h) or on reconnect. `f50_1x.sh status`
  prints `stale 0.x :` (br0 neighbours on 0.x excluding .1/.2) so this is visible; heal per client by replugging /
  WiFi toggle. Confirmed: the boot after the fix had an empty `stale 0.x` list and the PC came back on `1.129`.
- **Windows client-side heal:** `ipconfig /release|renew <if>` fails with *"no adapter is in the state permissible for
  this operation"* on the C-port adapter whenever **Windows 移动热点/ICS is sharing it** (that's also what the phantom
  `192.168.132.x` "WLAN 2/3" adapters are). Turn ICS off, or just replug.
- **MASQUERADE must live inside the container netns**, not on Android: br0 ingress is intercepted by the BPF
  `tether_upstream4_ether` before netfilter and 1.x never appears in Android FORWARD counters.
  `nsenter/chroot rootfs /usr/sbin/xtables-legacy-multi iptables -t nat -A POSTROUTING -s 192.168.1.0/24 -j MASQUERADE`
  (+ `-A FORWARD -s 192.168.1.0/24 -j ACCEPT`, needs `mount -t proc proc rootfs/proc` first).
- Order matters: the veth must exist & be up **before** `start.sh ensure` so dnsmasq binds eth1; `start.sh stop`
  destroys the netns and thus the veth pair, so LAN must be rebuilt after any full stop.
- Caveat: br0 has Android's IPv6 RA/prefix → clients also get a 240a: GUA + v6 default that bypasses OpenWrt.
  Either accept it or `ip6tables -A OUTPUT -o br0 -p icmpv6 --icmpv6-type router-advertisement -j DROP`.

**PERSISTENT since 2026-09-19 (reboot-tested):** the design lives in `start.sh`/`watch.sh` behind the flag file
`/data/adb/owrt/lan1x` (presence = ON).
- `start.sh` gained `lan1x_on`, `ensure_lan` (build veth `owrt-br`/`owrt-lan` → ns `eth1`, (re)enslave by checking
  `/sys/class/net/br0/brif/`, set 1.1, silence Android DHCP, delete the legacy Android-side 1.x NAT rule + ip rule),
  `lan_netconfig` (rewrites rootfs `/etc/config/network`, backup `.pre-lan1x`) and `lan_nat` (container-side
  MASQUERADE/FORWARD, runs after container start). `ensure()` = netns → veth-wan → android_side → **ensure_lan** →
  ensure_usb (no-op when lan1x) → container → **lan_nat**. `stop` now also removes the DHCP-drop rule + `owrt-br`.
- **netifd flushes addresses it doesn't own**: bolted-on `192.168.0.2` and the `default via 192.168.0.1` were being
  wiped at container start. They must be declared in `/etc/config/network` (lan = eth1, `list ipaddr` 192.168.1.1/24
  + 192.168.0.2/24, `option gateway 192.168.0.1`; wan = eth0 9.2 with **no** gateway) — `lan_netconfig` does this.
- `watch.sh` is now just: `start.sh ensure` (idempotent) every 60 s + health checks that actually mean something
  (`/proc/net/udp` `:0035` and `/proc/net/tcp` `:0050` **inside the netns**, and `owrt-br` still in `br0/brif` →
  full restart). The old `pgrep -x dnsmasq` check was always true (Android has its own dnsmasq in the default ns).
- **supervise 18 s restart loop root cause**: dnsmasq/uhttpd **daemonized**, so `alive $!` always failed → a new
  instance every cycle dying with "Address in use" (6147 spawns accumulated). Fix = `dnsmasq -n` + `uhttpd -f`;
  dnsmasq still re-parents to pid 1, so it is tracked by `pid-file=/var/run/dnsmasq.pid` instead of `$!`.
- Toggled by `sh /data/local/tmp/f50_1x.sh on|off|status` (on = touch flag + ensure; off = rm flag, undo rules,
  `ip link set owrt-br nomaster` so dnsmasq can't race Android's DHCP).
- IPv6 decision: **left alone on purpose.** Android's RA on br0 gives every client a real 240a: GUA + v6 default,
  which the F50's modem routes natively; the container has no v6 transit, so blocking the RA would only *remove*
  working IPv6. Result: v4 funnels through OpenWrt (1.x, managed), v6 goes direct.
- Verified post-reboot with a real dual-homed client (this PC): C-port RNDIS `192.168.1.129` and hotspot
  `192.168.1.197`, both gw/dns `192.168.1.1`, internet + DNS ok, and `192.168.0.1` (F50 admin/UFI-TOOLS) still
  reachable **through the container's NAT** — so network adb (`192.168.0.1:5555`) keeps working from 1.x clients
  even after the C cable moves to the Xiaomi router.
- Still open: TCP adbd 5555 is reachable by any br0/LAN client (`persist.service.adb.tcp.port=5555`), and the F50
  web admin still uses the factory `admin`/`admin`.
- Explains the permanent `load average ≈ 12` with ~660% CPU **idle** and zero D-state tasks: UFI-TOOLS
  (`com.minikano.f50_sms`) continuously execs its bundled `/data/data/com.minikano.f50_sms/files/adb` (avc
  `granted { execute }` lines flood dmesg at ~2/s) → fork/exec churn, not I/O or a leak. Nothing to do with lan1x;
  lower its polling/plugins if it matters.

**Windows-side dead ends (don't retry):** CDC-ECM and NCM gadget modes give **Code 28** on this PC
(rndismp6/usb8023 absent; usbncm.inf install section commented out) — RNDIS is the only usable USB mode.
`ipconfig /release` on the RNDIS adapter while Android's DHCP is silenced = 169.254 lockout, and after
gadget re-enumeration the miniport can sit at `MediaConnectionState=Disconnected` until a physical replug /
adapter disable-enable (needs admin).

**Pitfalls that cost time:** `adb push` from an MSYS `/tmp/...` path silently does nothing (stage to a real
Windows path, then rm-then-push and **compare md5**); `ip netns show | grep -qx owrt` is always false (toybox
prints `owrt (id: 0)`) → test with `ip netns exec owrt ip link show lo`; USB re-enumeration mid-script breaks the
USB adb serial → run long scripts detached (`setsid nohup sh x.sh >log 2>&1 </dev/null &`) and use
`adb -s 192.168.0.1:5555`; inside chroot always absolute paths (`/bin/busybox nslookup`, no `head`/`awk` in /bin).
On this PC's Git-Bash: `adb push x /data/...` mangles the REMOTE path to `C:/Program Files/Git/data/...` unless
`MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*'` is exported; toybox `tr -dc '\r'` counts literal `r`s (false CRLF
alarm); nested `$`/backticks in `powershell -Command` inside bash keep breaking — write a .ps1 file instead.

## Boot-window DHCP race + boot-hook optimization (2026-09-19 PM, reboot-tested)

- Verdict of the reboot test: lan1x comes up green on every boot, but a client that (re)connects in the first
  ~15-40 s leases from **Android** (192.168.0.x): Android's tether dnsmasq answers from ~15 s uptime, while
  service.d can't run before ~9 s and the container needs ~25 s more. **Residual race ≈ 15-20 s, not fully closable.**
- Proof trick: Windows `Get-NetIPAddress ... ValidLifetime` (24 h pool) pinpoints the grant time — the stale lease
  was granted ~35 s BEFORE the drop rule landed.
- Stale 0.x clients heal SLOWLY: RENEW is unicast to 0.1's MAC → bridge delivers locally → dropped by the rule,
  the container never sees it → no NAK possible. Only the T2 rebroadcast (~21 h into a 24 h lease) reaches the
  container → NAK (dhcp-authoritative) → fresh DISCOVER → 1.x. Immediate heal = client-side release+renew or
  replug. `f50_1x.sh status` now prints `stale 0.x :` (br0 ARP, minus .1/.2).
- Windows gotcha: `ipconfig /release <if>` fails with "no adapter is in the state permissible" when that adapter is
  shared by ICS/移动热点 — can't force the PC to rebind while hotspot-sharing through it.
- Hook rewritten (`/data/adb/service.d/owrt.sh`, md5 5825623b): no boot_completed wait, no `sleep 15`; logs
  `boot hook entered at uptime Ns` (measured **9 s** — service.d runs early), loops `start.sh ensure` every 1 s
  until the dhcp-drop rule is present (≤150 s), then starts watch.sh.
- `start.sh` restructured (md5 d5913622):
  - `ensure_lan` no longer installs the drop rule. New **`dhcp_takeover()`** runs at the END of `ensure()` and
    silences Android only after the container's dnsmasq is confirmed listening (`/proc/net/udp` `:0035` in ns,
    ≤6 s poll); otherwise logs WARN and leaves Android serving (connectivity > correct subnet). This closed a
    real 33 s hole where the rule landed long before any DHCP server could answer (clients → 169.254).
  - `stopc`'s double /proc scan costs **~16 s** on this box; `ensure()` now only runs it when `:0035`/`:0050`
    listeners still exist in the ns (stale generation). Cold boot is ~16 s faster.
- Post-rewrite timeline (15:34 reboot): hook 9 s → netns/veth/NAT 9 s → container start 26 s → supervisor 34 s →
  enslave + dhcp silenced 37 s → hook done 38 s (was: silenced 47 s, dnsmasq ready 80 s).
- Cold-boot quirk (observed on the splitter cold boot): container's mgmt alias 192.168.0.2 + default route can be
  missing for the first ~45-60 s until a watch/ensure pass re-asserts them (netifd race). Don't panic-fix; recheck
  after a minute. Client 1.x DHCP works before that.
- The stopc-skip variant booted once warm (15:38) + once cold (splitter boot) and served 1.x leases both times,
  but its timeline was never read line-by-line — compare `boot hook entered/done` uptimes at the next reboot.

## C-port is USB DUAL-ROLE: direct-to-PC vs 一分二 + RTL8153B wired-LAN mod (2026-09-19, UNRESOLVED)

- The C port switches role by CC detection; **gadget and host modes are mutually exclusive**:
  - Direct to PC: `[device]/[sink]`, `sys.usb.config=rndis,mtp,adb`, USB ID **19D2:0247** (MI_00 RNDIS,
    MI_02 MTP/WPD, MI_03 ADB→WinUSB). The known-good PC arrangement; Windows shows
    "Remote NDIS based Internet Sharing Device".
  - Y-splitter ("一分二": C-male into F50; female leg 1 = PD charging input; female leg 2 = data to an
    **RTL8153B** C-to-Ethernet dongle; dongle RJ45 → Xiaomi WAN): port latches `[host]/[source]`,
    `sys.usb.config` auto-flips to `ecm,mtp,adb`, and configfs-gadget UDC bind then fails EVERY SECOND with
    `write 'ecm,mtp,adb' -> 'No such device'` (EXPECTED in host role — not a bug, `stop/start adbd` can't fix it).
    F50 vanishes from any PC (it IS the host now). Hotspot + tethering + lan1x keep working (wlan0/br0 unaffected).
- Community mod (bilibili 中兴F50改有线 / xxshell.com tutorial): this exact splitter + RTL8153B + 上网协议=CDC-ECM
  gives the F50 a wired LAN port on br0. Kernel support confirmed present: **r8152 built-in**
  (`/lib/modules/5.4.254.../modules.builtin`), ax88179_178a/cdc_ether/cdc_ncm = modules (loadability unverified),
  xhci-hcd + MUSB HDRC host controllers exist.
- **The blocker:** with the port in host/source role, NO downstream device ever enumerated —
  `/sys/bus/usb/devices/` shows only root hubs (usb1/2/3), no eth*/usb*/enx* netdev, zero r8152/usb 1-1 dmesg
  lines, `ip monitor link` silent over 30+ s. Prime suspect = **VBUS/power**: F50 is batteryless, and on the
  splitter its network LED turns **RED** (5G modem browning out / re-registering), worst when the charging leg is
  fed from a PC USB port (500 mA). If VBUS sags, the 8153B never powers up. NEXT ATTEMPT: real 5V/2A+ wall
  charger on the charging leg, good cable.
- Logger planted for the next attempt: `/data/adb/service.d/usbmon.sh` → appends every 10 s to
  `/data/adb/owrt/usbmon.log`: data_role/power_role, downstream usb devices, eth*/usb*/enx* links, dmesg tail
  (r8152/overcurrent/vbus). Read it via network adb after replugging the splitter.
- If the NIC enumerates but Android doesn't bridge it: `tetherableUsbRegexs=[sipa_usb\d, rndis\d]` does NOT cover
  eth/usb NIC names, so framework auto-bridging is unlikely — try `ip link set <nic> master br0` and persist it in
  start.sh ensure_lan. (The tutorial claims setting 上网协议=CDC-ECM makes ZTE firmware handle it; unverified.)
- Xiaomi router behavior while its WAN gets no DHCP: falls back to its own **192.168.181.0/24** subnet (PC got
  .208, gw .164; no admin UI on .164/.1 at 80/443 — not explored). End-state plan once the link works: Xiaomi in
  有线中继/AP mode (bridge, DHCP off) so downstream clients lease 1.x straight from OpenWrt.

## UFI-TOOLS v4 HTTP API — the recovery channel when ALL adb is dead (verified 2026-09-19)

With the C port in host role (no USB adb) and tcp adbd down, the UFI-TOOLS app on **http://192.168.0.1:2333**
still answers (reachable from 1.x clients through the container's NAT). Source: github **kanoqwq/UFI-TOOLS**,
branch `http-server-version` (matches the installed v4.0.0 / 20260326).

- Every request needs headers `kano-t` = epoch-ms and `kano-sign`:
  `raw = "minikano" + METHOD + PATH(no query) + ts`; `h = HMAC-MD5(key="minikano_kOyXz0Ciz4V7wR0IeKmJFYFQ20jd", raw)`;
  `sign = sha256hex( sha256raw(h[:8]) ++ sha256raw(h[8:]) )`.
- **`authorization` header = sha256hex(token), NOT the raw token** (server compares
  constantTimeSha256Equals(header, storedHash)). Default token `admin` →
  `authorization: 8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918`.
  Bad/missing auth → bare **401 with empty body**. No-auth whitelist: `/api/version_info`, `/api/need_token`,
  `/api/get_custom_head`, `/api/get_theme`, `/api/SELinux`, `/api/uploads*`.
- Working helper script: `C:\Users\Steven\_stage\ufi.py` (python: sign/call/sh via curl --noproxy).
- Verified endpoints: `GET /api/adb_alive` → `{"result":"false"}`; `POST /api/adb_wifi_setting`
  `{"enabled":true,"password":"admin"}` (stores ADB_IP_ENABLED+ADMIN_PWD = network-adb autostart; did NOT raise
  :5555 immediately by itself); `GET /api/baseDeviceInfo` (battery/data/storage); `GET /api/smbPath?enable=1`
  (points the Samba share at the ROOT filesystem, takes 1-2 min — **massive hole, set enable=0 afterwards**);
  `POST /api/root_shell {"command","timeout"}` — **needs the 高级功能 socat socket**: fails with
  "没有找到 socat 创建的 sock" whenever the app's own local adb channel is dead; `GET /api/one_click_shell` =
  UI-automation via `adb -s localhost` → also needs working tcp adb. So with adb fully dead this API yields
  telemetry + settings, but NO shell.
- Samba (configs/SMBConfig.kt): shares `[F50]`→/data/SAMBA_SHARE, `[internal_storage]`→/sdcard/DCIM, guest ok.
  445/139 open, but Windows `net view \\192.168.0.1` → error 1702 and `net use \\192.168.0.1\F50` → error 67
  (name not found) even after smbPath enable=1 — possibly the config reload hadn't finished; UNRESOLVED
  (abandoned once USB came back). Untested idea: write `/data/adb/service.d/*.sh` via a working share + goform
  `REBOOT_DEVICE` to regain root at boot.
- **True last-resort recovery = physical:** direct plug to a PC with a DATA cable always restores USB adb
  (device role; MI_03 ADB binds WinUSB under both rndis and ecm protocol settings). The splitter's charging leg
  is power-only — a PC behind it enumerates NOTHING (this fooled us once: "接电脑了" but no 19D2 on the bus).
- Network adb is now durable: `persist.service.adb.tcp.port=5555` (+ runtime prop) set 2026-09-19 ~20:00,
  verified `LISTEN [::]:5555` and connect from a 1.x client via container NAT. Its earlier absence explains the
  "5555 actively refused after the splitter cold boot" mystery (previous boots only had the runtime prop).
  UFI-TOOLS keepalive re-connects to localhost:5555 in a loop — part of the permanent load ≈ 12.
- Port **8080** on the device = ZTE's secondary web UI (mobile-redirect HTML; UFI-TOOLS talks goform to
  `gateway_ip` default `192.168.0.1:8080`). goform without a login session returns
  `{"Error":"none secure connection"}`.
