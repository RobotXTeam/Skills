# Hardware Notes — WiFi cards for WPA2 attack lab

Field-tested observations on Steven's hardware for WPA2 monitor/injection work. Updated 2026-08-20.

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

## Intel AX210 (planned, not yet tested on Steven's gear)

- Driver: `iwlwifi` (newer firmware).
- Monitor mode: community reports it as MORE stable than older Intel chips for EAPOL capture. Acceptable for passive capture.
- Injection: Intel never officially supports injection; AX210 is "monitor OK, injection unreliable" per aircrack-ng wiki.
- Use case: passive capture with manual phone reconnect trigger.

## Raspberry Pi 4 — Cypress/Infineon CYW43455 (built-in)

- Driver: `brcmfmac`.
- Monitor mode: STABLE, captures EAPOL reliably. aarch64 + aircrack-ng well-supported in community.
- Injection: NOT supported by brcmfmac.
- Use case: passive capture host. Pair with a wired connection for SSH (Pi 4 has Ethernet).

## Raspberry Pi 5 — Cypress/Infineon CYW43456 (built-in)

- Driver: `brcmfmac`.
- Monitor mode: STABLE. Adds 5GHz / 802.11ac support.
- Injection: NOT supported.
- Use case: same as Pi 4, plus 5GHz AP capture.

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
| Passive handshake capture | Raspberry Pi 4/5 built-in, or AX210 if available |
| Active deauth capture | NEED RTL8812AU / AR9271 USB card (none currently on hand) |
| Offline brute-force (GPU) | AMD 780M laptop |
| Offline brute-force (CPU, small dict) | steven i5-13500H |
