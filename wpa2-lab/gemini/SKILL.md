---
name: wpa2-lab
description: "WPA2-PSK penetration learning lab on Steven's own devices. Trigger when the user asks to crack/test/break WPA2 WiFi passwords, set up a WPA2 honeypot, capture 4-way handshakes, run aircrack-ng/hashcat dictionary or mask attacks, evaluate WiFi security, or learn WPA2 attack principles. Covers: 4-way handshake theory, monitor mode capture, deauth, offline PMK/PTK/MIC derivation, dictionary vs mask brute-force, hardware capability matrix (Intel/Realtek/Cypress/Pi), and honest attacker-perspective workflow. Legal scope: only Steven's own networks and devices."
---

# WPA2-PSK Penetration Learning Lab

## Purpose

This skill is a **legal self-owned** WPA2 penetration learning environment. Only use it on Steven's own networks and devices. Never use it against networks you do not own or have explicit authorization to test.

The goal is to understand the full WPA2-PSK attack chain — theory + hands-on — so Steven can:
1. Grasp *why* WPA2 can be offline-brute-forced (the 4-way handshake is capturable, PMK derivation is offline).
2. Know *what hardware* can do which step (monitor capture vs injection vs compute).
3. Run the full honest chain: capture handshake → offline brute-force → key found (or honestly fail).
4. Make real security decisions: why password length beats complexity, why auto-connect is a risk, why WPA3/SAE changes the game.

## Core Principles (must internalize before acting)

### WPA2 brute-force is OFFLINE, not online

WPA2-PSK cannot be cracked by repeatedly trying passwords against the AP like a web login. The AP rate-limits and logs. The real attack is:

1. **Capture** one 4-way handshake (4 EAPOL frames) between a client and the AP.
2. **Go fully offline**: for each candidate password, derive `PMK = PBKDF2(pass, SSID, 4096)`, then `PTK = PRF(PMK, "Pairwise key expansion", min/max(AA,SA) || min/max(ANonce,SNonce))`, then `KCK = PTK[0:16]`, then compute EAPOL MIC with KCK and compare to the captured MIC. Match == correct password. No further contact with the AP.

So "the attacker doesn't know the password" is the *premise* of brute-force, not an obstacle. Knowing it would make brute-force pointless.

### The handshake only happens at the moment of (re)association

The 4-way handshake is a *transient event* at connection time, not continuous. To capture it you need a client to (re)connect while you are listening. This is why:
- **Auto-connect** phones are the best target — entering signal range triggers reconnect → handshake.
- **deauth attack** (forged deauth frames) kicks a connected client off so it auto-reconnects → new handshake. This is the standard active trigger.
- No client + no reconnect = no handshake = no brute-force possible. This is a real-world gate, not a script bug.

### Length beats complexity

WPA2 brute-force cost scales as `charset^length`:
- 8-digit numeric (1e8): any GPU seconds-to-minutes.
- 8-char alphanumeric (2.8e12): GPU hours.
- 12-char alphanumeric (4.7e18): GPU centuries. Practically uncrackable.
Each +1 char ~70x cost. A long random password is the single best defense. The 8-character WPA2 minimum is dangerously weak.

## Fixed Environment (Steven's known hosts)

Use with the `ssh` skill. Relevant devices for this lab:

- `seeed` @ 192.168.2.113 — Ubuntu 22.04, RTL8822CE WiFi (wlp4s0), supports AP+monitor but NOT simultaneously on same phy (rtw88 driver). sudo password `0`. AP/honeypot host.
- `seeed0` @ 192.168.2.194 — Ubuntu 24.04, no WiFi card. Useful as wired attack box only.
- `steven` (local) — Ubuntu, Intel WiFi (wlp0s20f3, iwlwifi). sudo password `1`. monitor capture is UNRELIABLE for EAPOL (Intel weakness). Good hashcat CPU host.
- Raspberry Pi 4/5 (when available) — Cypress CYW43455/43456. monitor capture STABLE, injection NOT supported. Slow hashcat.
- AMD m780 (Radeon 780M RDNA3) laptop — best GPU-class compute host when available (~150k-400k H/s WPA).

Intel AX210 (if available) — monitor STABLE (better than old Intel), injection UNRELIABLE. Acceptable for passive capture.

## Hardware Capability Matrix (critical — read before choosing a card)

| Card | monitor capture (EAPOL) | packet injection (deauth) | Notes |
|------|------------------------|---------------------------|-------|
| Realtek RTL8822CE (seeed built-in) | OK | NOT tested, rtw88 driver | cannot do AP+monitor at same time on one phy |
| Intel old (AX201 etc, iwlwifi) | UNRELIABLE — captures beacons but misses EAPOL | unreliable | the exact failure seen on steven |
| Intel AX210 | OK | unreliable | passive capture acceptable |
| Raspberry Pi 4/5 built-in (Cypress brcmfmac) | OK/stable | NOT supported | passive only |
| Alfa AWUS036ACH (RTL8812AU) | OK | OK | community gold standard, ~¥250-400 |
| Alfa AWUS036NHA / TP-Link TL-WN722N v1 (AR9271) | OK | OK | cheap, ~¥50-200, watch WN722N v1 only |
| RTL8821CU/8822BU | flaky | flaky | avoid, driver mess |

**Decision rule:**
- Passive capture only (user manually reconnects phone) → any monitor-capable card works (Pi built-in, AX210, even RTL8822CE on a second box).
- Full active attack with auto deauth → MUST have an injection-capable USB card (RTL8812AU / AR9271).

## Honest Attacker Workflow

This is the canonical sequence. Each step has a real failure mode; do not skip honesty.

### Step 1 — Honeypot AP (the target, self-owned)

On seeed (192.168.2.113), set up hostapd with WPA2-CCMP and a chosen password. Script: `scripts/setup_ap.sh` on the AP host.

```bash
# On seeed
bash /home/seeed/wpa2_lab/setup_ap.sh   # generates config + random 8-char pass, starts hostapd+dnsmasq
```

To set a specific password (e.g. for a known-answer test), edit `wpa_passphrase=` in `/home/seeed/wpa2_lab/hostapd.conf` and restart hostapd.

For honest attacker mode: do NOT run hostapd with `-dd -K` — that dumps internal PMK/PTK/EAPOL from inside the AP, which a real attacker cannot access. Using it = cheating. Only use `-dd -K` when validating your own crack implementation.

### Step 2 — Capture handshake (the hard part)

On the attack box, put WiFi card into monitor mode and capture EAPOL frames directed at the AP BSSID.

```bash
# On attack box (steven / Pi / AX210 box)
sudo nmcli dev set WLAN managed no
sudo ip link set WLAN down
sudo iw dev WLAN set type monitor
sudo ip link set WLAN up
sudo airodump-ng -c 6 --bssid AP_MAC -w capture WLAN
```

Trigger a handshake:
- **Passive (no injection)**: ask the user to tap the SSID on their phone to (re)connect. A failed reconnect with stale password still emits 1/4 and 2/4 — enough to crack.
- **Active (needs injection card)**: `sudo aireplay-ng -0 5 -a AP_MAC WLAN` deauths the client, forcing auto-reconnect.

Verify capture: `aircrack-ng capture-01.cap` must show `WPA (1 handshake)`. If `0 handshake`, the card missed EAPOL — retry, or change card. This is the most common failure point.

### Step 3 — Offline brute-force

Once a pcap with `1 handshake` exists, the AP is no longer needed. Run on any compute host.

Dictionary attack:
```bash
aircrack-ng -w wordlist.txt -e SSID -b AP_MAC capture-01.cap
```

Mask attack (GPU, hashcat mode 22000 modern / 2500 deprecated):
```bash
# Convert capture to hashcat hash (aircrack can export)
aircrack-ng -J hash capture-01.cap        # old hccap
# For mode 22000 (WPA-PMKID-EAPOL), use hcxtools:
hcxpcapngtool -o hash.hc22000 capture-01.cap
hashcat -m 22000 hash.hc22000 ?d?d?d?d?d?d?d?d   # 8-digit numeric
hashcat -m 22000 hash.hc22000 -a 0 wordlist.txt  # dictionary
```

### Step 4 — Honest result

- If dictionary/mask covers the password → KEY FOUND. This proves the chain works.
- If not covered → honest fail. This proves the password is strong against that dictionary. Both outcomes are valid learning.

## Key Derivation Reference (for implementing/auditing a crack)

This is the exact algorithm aircrack-ng/hashcat implement. Verified against hostapd v2.10 source (`src/common/wpa_common.c` `wpa_pmk_to_ptk` + `src/crypto/sha1-prf.c`) and confirmed by the known-answer test vector in `crypto_module_tests.c`.

```
PMK = PBKDF2-HMAC-SHA1(passphrase, SSID_bytes, 4096, 32)
data = min(AA,SA) || max(AA,SA) || min(ANonce,SNonce) || max(ANonce,SNonce)
PTK = for counter 0,1,2...: HMAC-SHA1(PMK, "Pairwise key expansion\x00" || data || counter) concatenated, take first 48 bytes
KCK = PTK[0:16]
MIC = HMAC-SHA1(KCK, EAPOL_frame_with_MIC_field_zeroed)[:16]   # for WPA2-CCMP (HMAC-SHA1)
match MIC against captured 2/4-frame MIC
```

Critical details that bite implementations:
- The label includes a trailing NUL byte: `b"Pairwise key expansion\x00"`.
- Input order to HMAC is `label_with_NUL || data || counter` (counter is the LAST byte, not first). A common bug is putting counter first.
- MAC pair and nonce pair are sorted min/max per the IEEE 802.11i spec, NOT taken in role order.
- MIC field offset in the EAPOL-Key frame = 81 for the standard 2/4 frame (EAPOL hdr 4 + KeyDescriptorType 1 + KeyInfo 2 + KeyLength 2 + ReplayCounter 8 + KeyNonce 32 + KeyIV 16 + KeyRSC 8 + KeyID 8).
- For WPA2-CCMP the MIC algorithm is HMAC-SHA1 (not AES-CMAC). `PRF(SHA1)` confirmed in hostapd log.

A correct Python reference is in `scripts/crack_ptk.py` with a built-in hostapd sha1_prf known-answer self-test.

## Known Hardware Failures Encountered (lessons logged)

1. **steven Intel wlp0s20f3 + iwlwifi**: captures 11938 frames including beacons/ACK/RTS but **0 EAPOL frames** in monitor mode. Intel's monitor implementation on this chipset is unreliable for EAPOL. Do not use steven's built-in WiFi for handshake capture. (2026-08-20)
2. **seeed RTL8822CE rtw88**: cannot run AP + monitor virtual interface on the same phy simultaneously. Adding `mon0` flips `wlp4s0` from AP to monitor and breaks hostapd (`key not allowed`, `INTERFACE-DISABLED`). One card cannot be both AP and capture interface here. (2026-08-20)
3. **Single-card same-phy AP+monitor**: generally unreliable across consumer drivers. Prefer two cards (one AP, one monitor) or two hosts.
4. **hand-crafted pcap frame headers**: the 802.11 FC byte order and address-field assignment (ToDS/FromDS → A1/A2/A3 roles) is easy to get wrong, producing `0 handshake` or garbled BSSIDs. If constructing pcap from raw EAPOL hex (e.g. from hostapd -dd -K logs as a fallback), use the verified `scripts/make_pcap.py`.

## Legal & Ethical Rules

- Only run against Steven's own networks and devices.
- Never run deauth or capture against networks you do not own.
- The honeypot password and any "known answer" tests are for validating the toolchain only. Honest attacker-perspective tests must NOT put the password in the dictionary.
- If a real attacker perspective is requested, the password must live only in the AP's `hostapd.conf` on the AP host, never in any file on the attack box.

## Helper Scripts

- `scripts/setup_ap.sh` — on AP host (seeed): generate WPA2-CCMP hostapd+dnsmasq config with random 8-char password, start AP. Writes `/home/seeed/wpa2_lab/`.
- `scripts/stop_ap.sh` — on AP host: stop hostapd/dnsmasq, return WiFi to NetworkManager.
- `scripts/capture.sh` — on attack box: switch WiFi to monitor, run airodump on a BSSID/channel, write pcap. Passive mode.
- `scripts/deauth.sh` — on attack box with injection card: aireplay-ng -0 deauth to force client reconnect.
- `scripts/crack_ptk.py` — standalone Python WPA2 PMK→PTK→MIC derivation with hostapd sha1_prf self-test; can brute-force a dictionary without aircrack/hashcat.
- `scripts/make_pcap.py` — build a valid 802.11 pcap (linktype 105) from raw EAPOL hex + MAC/nonce fields, for feeding aircrack-ng when only hostapd logs are available (fallback path).
- `scripts/to_hashcat.sh` — convert airodump pcap to hashcat mode 22000 hash via hcxtools.

## References

- `references/handshake-anatomy.md` — annotated 4-way handshake field-by-field with the actual captured hex from the 2026-08-20 experiment.
- `references/hardware-notes.md` — detailed per-chip monitor/injection behavior and driver gotchas.
- `references/session-2026-08-20.md` — full lab session log: what worked, what failed, the two "cheats" identified, and the honest-mode plan.
