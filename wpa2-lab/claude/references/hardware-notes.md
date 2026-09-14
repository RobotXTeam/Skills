# Hardware Notes — WiFi cards for WPA2 attack lab

Field-tested observations on Steven's hardware for WPA2 monitor/injection work. Updated 2026-08-29 (qiang AX210 field test).

## seeed — Realtek RTL8822CE (PCI, wlp4s0)

- Driver: `rtw88` (`rtw_8822ce`).
- Supports interface modes: IBSS, managed, **AP**, AP/VLAN, **monitor**, mesh point. Confirmed via `iw phy phy0 info`.
- **CANNOT do AP + monitor on the same phy simultaneously.** Adding a `mon0` virtual interface (`iw phy phy0 interface add mon0 type monitor`) flips `wlp4s0` itself from `type AP` to `type monitor`, and hostapd fails with `nl80211: kernel reports: key not allowed`, `INTERFACE-DISABLED`, `Failed to set beacon parameters`. The AP is effectively killed.
- Implication: single RTL8822CE cannot be both the honeypot AP and the capture interface. Use two cards or two hosts.
- Good as: AP host (stable hostapd WPA2-CCMP).

## steven — Intel WiFi (PCI 8086:51f1, wlp0s20f3, iwlwifi)

- Supports monitor mode (confirmed `iw phy phy0 info` lists `* monitor`).
- **Monitor capture is UNRELIABLE for EAPOL.** In the 2026-08-20 session, an airodump-ng capture on channel 6 targeting the AP BSSID produced 11938 frames (beacons, ACKs, RTS, data) but **zero EAPOL frames** (`tcpdump -r cap 'ether proto 0x888e'` count = 0), even after aireplay-ng deauth bursts and a confirmed client reconnect. aircrack-ng reported `WPA (0 handshake)`.
- The chipset captures management/control frames fine but drops or misses the small EAPOL data frames. This is a known iwlwifi monitor weakness on some Intel consumer chips.
- Implication: do NOT use steven's built-in Intel WiFi for handshake capture. Use it as the hashcat CPU host instead (it has a 13th-gen i5-13500H).
- Injection: not reliable on iwlwifi either. Not tested further.

## qiang — Intel AX210 (PCI, wlp1s0, iwlwifi) — TESTED 2026-08-28/29, FAILED for cracking

The earlier "AX210 monitor OK" line was community lore. Field-tested against CMCC-xbxm (WPA2-CCMP, no PMF) over three ~5-minute monitor windows:

- Monitor switch works: `nmcli dev set wlp1s0 managed no; ip link down; iw set type monitor; ip link up; iw set channel N`. Auto-restore back to managed + `nmcli con up Qiang` works reliably (trap-based scripts).
- **Concurrent monitor vif**: `iw dev wlp1s0 interface add mon0 type monitor` SUCCEEDS (unlike most drivers), BUT the vif is channel-locked to the associated channel: `iw dev mon0 set channel 11` fails with `-16 Device or resource busy` while associated on ch6, and radiotap confirms mon0 only hears ch6. Useless for cross-channel capture without dropping the managed link. Delete vifs with `iw dev mon0 del` (NOT `ip link del` — that returns `Operation not supported`).
- **EAPOL capture: SYSTEMATIC M1/M2 LOSS.** Every captured handshake came through as M3/M4 only (M1+M2 missing both times in round 1; round 2 had zero EAPOL because injection died; round 3 saw no AP frames at all after the first minute). aircrack: `0 handshake`; hcxpcapngtool: "not enough M1 frames". The missing M1/M2 means no ANonce/SNonce/MIC → nothing crackable.
- `iw dev wlp1s0 set monitor flag fcsfail` → not supported by iwlwifi, so corrupted-frame recovery is not an option.
- **Injection: recipe-dependent** (see SKILL.md lesson 8). Worked once (airodump engine + aireplay -9 prime + broadcast deauth → 10355 frames out, clients kicked), died completely the next round (tcpdump engine + directed `-c` deauth + no prime → 0 frames out). Never trust `aireplay -9`'s ACK% on iwlwifi (no TX-ACK reporting in monitor mode); verify behaviorally (do you see the client's probe→auth→reassoc after the burst?).
- Implication: qiang's AX210 is NOT a usable handshake-capture card either. It can trigger reconnects (when injection works) but cannot collect the crackable frames. For real captures on qiang's side of the lab, a USB RTL8812AU/AR9271 card is still required — or AP-side capture on the owned router.

## Target behavior notes (CMCC-xbxm, 2026-08-28)

- Beacon RSN capabilities 0x000c → MFPC=0, MFPR=0: no 802.11w, deauth attacks land.
- Kicked clients reconnect fast: probe → open auth → REASSOC (PMKSA caching, not fresh ASSOC) → 4-way within ~2 s. Client MACs partially randomized (locally administered bit set) — expect MACs to rotate between sessions; directed deauth lists go stale.
- Round 3 anomaly (unresolved): after a normal prime, capture contained only ~28k control frames (BlockAck/ACK) and zero beacons/data from the target for 265 s — AP went silent or RX degraded to control-only. Needs re-testing if it matters.

## Raspberry Pi 4 — Cypress/Infineon CYW43455 (built-in)

- Driver: `brcmfmac` (fullmac). Firmware BCM4345/6 wl0 7.45.265.
- **Monitor mode: NOT SUPPORTED (verified 2026-08-26).** `iw phy phy0 info` lists only IBSS/managed/AP/P2P-client/P2P-GO/P2P-device — no monitor. `iw dev wlan0 set type monitor` fails with `-95 Operation not supported`. Valid interface combinations contain no monitor either. The older claim "Pi monitor STABLE" was untested community lore — FALSE.
- Injection: NOT supported by brcmfmac.
- Use case: WIRED attack box only (SSH over Ethernet), offline cracking host. On-Pi cracking: hashcat 6.2.5 + POCL crashed on aarch64 (`free(): invalid next size`, mode 22000, with and without `-O`) — use aircrack-ng with dictionary files or FIFO candidate streams instead.

## Raspberry Pi 5 — Cypress/Infineon CYW43456 (built-in)

- Driver: `brcmfmac` (fullmac) — same architecture as Pi 4, so expect the SAME no-monitor limitation (not separately verified). Adds 5GHz / 802.11ac support.
- Injection: NOT supported.
- Use case: wired attack box / cracking host, same as Pi 4.

## Recommended injection-capable USB cards (for active deauth)

- **Alfa AWUS036ACH** (RTL8812AU): gold standard, dual-band AC1200, ~¥250-400. Monitor + injection both solid.
- **Alfa AWUS036NHA** (AR9271): older but rock-solid, ~¥200.
- **TP-Link TL-WN722N v1** (AR9271): cheap (~¥50 used), black housing, **ONLY v1 supports injection**. v2/v3 use RTL8188EU and do NOT support injection — verify chip before buying.
- **Comfast CF-912AC** (RTL8812AU): cheap (~¥80), works.
- **Panda PAU05** (RT3070): ~¥100, reliable.

## Avoid

- RTL8821CU, RTL8822BU: driver mess, flaky monitor/injection.
- TP-Link TL-WN722N v2/v3 (RTL8188EU): no injection.
- Random no-name RTL8188EU sticks.

## Compute hosts (for offline brute-force, no WiFi card needed)

- AMD m780 / Radeon 780M (RDNA3, 12 CU): best available GPU-class on Steven's gear. ~150k-400k H/s WPA in hashcat. 8-digit numeric ~1 min, 8-char alphanumeric ~10-20h.
- Intel i5-13500H (steven): CPU only, ~2k-5k H/s. Slow but works for small dictionaries.
- Dedicated NVIDIA GPU would be ~10x faster than 780M but none currently on hand.

## Decision matrix

| Goal | Best hardware on hand |
|------|---------------------|
| Run the honeypot AP | seeed (RTL8822CE, stable hostapd) |
| Passive handshake capture | NO reliable monitor card on hand. Tried: seeed RTL8822CE (works but is the AP host, and seeed's location sees no CMCC APs at all), steven old Intel (misses EAPOL entirely), qiang AX210 (misses EAPOL M1/M2 — the crackable part), Pi (no monitor). Fallback: AP-side tcpdump on a self-owned hotspot, or buy RTL8812AU/AR9271. |
| Active deauth capture | NEED RTL8812AU / AR9271 USB card (none currently on hand). qiang AX210 injection is recipe-dependent flaky — can trigger reconnects but can't capture the result. |
| Offline brute-force (GPU) | AMD 780M laptop |
| Offline brute-force (CPU, small dict) | steven i5-13500H |
