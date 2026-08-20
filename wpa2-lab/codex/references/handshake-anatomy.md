# 4-Way Handshake Anatomy (with real captured hex)

Annotated field-by-field breakdown of the WPA2-PSK 4-way handshake captured during the 2026-08-20 lab session on seeed's `LAB-WPA2-TEST` AP. Source: hostapd v2.10 `-dd -K` debug dump (note: this is internal AP data, NOT what a real attacker captures — see honesty note below).

## The four parties

- **AP (Authenticator)**: BSSID `a8:93:4a:0b:51:27` (seeed wlp4s0, RTL8822CE)
- **STA (Supplicant)**: `de:b3:5c:e4:a6:7f` (Steven's phone)
- **SSID**: `LAB-WPA2-TEST`
- **Cipher**: WPA2-PSK / CCMP / HMAC-SHA1 MIC

## Derivation inputs (the cracker's required material)

| Field | Value (hex) | Role |
|-------|-------------|------|
| AP MAC (AA) | `a8934a0b5127` | PTK data, min/max sorted with SA |
| STA MAC (SA) | `deb35ce4a67f` | PTK data |
| ANonce (Nonce1, AP) | `9fcad81678002273d17ba89c51767b88bf91226dc91beb58e3ce9dd003ae2d44` | AP's nonce, in 1/4 frame |
| SNonce (Nonce2, STA) | `623543efe5bcb1f7d199fc1808f8f47de4505739377673cb5b51e703c926c1` | STA's nonce, in 2/4 frame |

## Derived keys (hostapd internal — attacker does NOT have these)

These are what the attacker must RECOMPUTE from each candidate password:

| Key | Value (hex) | Derivation |
|-----|-------------|------------|
| Passphrase | `XqFDQKQb` (8-char, known-answer test) | the secret |
| PMK | `9f0b6020a8ae867fdf33501bcce41f92e175c7ed7945eff76c400f7d2cc71e77` | PBKDF2-HMAC-SHA1(pass, SSID, 4096, 32) |
| PTK (48 bytes) | `c77fe0481393cd618ab94b0a09bedb9f78c00d9d9fe23d6376a3aabda283af033212bdf0eb8e5c81f2b98a6d4d4c97b3` | sha1_prf(PMK, label, data) |
| KCK (PTK[0:16]) | `c77fe0481393cd618ab94b0a09bedb9f` | used for MIC |
| KEK (PTK[16:32]) | `78c00d9d9fe23d6376a3aabda283af03` | used for key wrap |
| TK (PTK[32:48]) | `3212bdf0eb8e5c81f2b98a6d4d4c97b3` | actual encryption key |

## The 2/4 EAPOL-Key frame (121 bytes, STA → AP)

This is the frame whose MIC gets compared. Full hex:

```
01 03 00 75                          # EAPOL: Version=2 Type=3(Length=0x75=117)
02                                   # Key Descriptor Type = 2 (WPA key)
01 0a                                # Key Info = 0x0a01 (big-endian: bit1=MIC, bit3=ACK, bit7=Pairwise, key type 2)
00 00                                # Key Length = 0
00 00 00 00 00 00 00 01              # Replay Counter = 1
62 35 43 ef e5 bc b1 f7 d1 99 fc 18  # Key Nonce (SNonce, 32 bytes)
08 f8 88 f4 7d e4 50 57 79 37 76 73
cb 5b 51 e7 03 c9 26 c1
00 00 00 00 00 00 00 00 00 00 00 00  # Key IV (16 bytes, zero)
00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00              # Key RSC (8 bytes, zero)
00 00 00 00 00 00 00 00              # Key ID (8 bytes, zero)
c8 d5 86 81 ba 5c a3 31 2a e1 32 0e  # Key MIC (16 bytes) <-- the target MIC
b9 66 49 b5
00 16                                # Key Data Length = 22
30 14 01 00 00 0f ac 04 01 00 00 0f  # Key Data (RSN IE, 22 bytes)
ac 04 01 00 00 0f ac 02 00 00
```

**MIC field offset = 81** (count: 4 EAPOL hdr + 1 desc type + 2 key info + 2 key len + 8 replay + 32 nonce + 16 IV + 8 RSC + 8 ID = 81). Verified by direct byte read: `frame[81:97] == c8d58681ba5ca3312ae1320eb96649b5`.

## MIC computation

```
MIC = HMAC-SHA1(KCK, EAPOL_frame_with_MIC_field_zeroed)[:16]
```
i.e. take the 121-byte 2/4 frame, zero out bytes [81:97], HMAC-SHA1 it with KCK as key, take first 16 bytes. Must equal `c8d58681ba5ca3312ae1320eb96649b5`.

## Replay Counter matching

1/4 and 2/4 must share the same Replay Counter (here `1`). 3/4 and 4/4 use `2`. aircrack-ng enforces this pairing when recognizing a handshake from a pcap.

## Honesty note

All the hex above came from hostapd's internal debug log (`-dd -K`), which dumps the PMK/PTK/KCK directly. A **real attacker never sees these** — they only see the over-the-air EAPOL frames (the 2/4 frame hex + the MAC/nonce values extractable from it). The PMK/PTK must be recomputed from each candidate password. The internal log is useful only for validating your own cracker implementation.
