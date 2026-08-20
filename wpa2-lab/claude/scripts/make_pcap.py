#!/usr/bin/env python3
"""
make_pcap.py — 从原始 EAPOL hex + MAC/nonce 字段构造合法 802.11 pcap
用途: 当只能拿到 hostapd -dd -K 日志的 hexdump 而没真实抓包时, 重建 pcap 喂 aircrack-ng
诚实提醒: 真实攻击者拿不到这些内部数据, 此脚本仅供算法验证/教学补全.
"""
import struct, re, sys, binascii

def build_pcap(ap_mac, sta_mac, anonce, snonce, eapol_2_4_hex, mic_hex, essid, outfile):
    AP  = binascii.unhexlify(ap_mac)
    STA = binascii.unhexlify(sta_mac)
    ANONCE = binascii.unhexlify(anonce)
    EAPOL2 = bytes.fromhex(re.sub(r"\s+", "", eapol_2_4_hex))
    MIC = binascii.unhexlify(mic_hex)

    # 重建 1/4 帧 (AP->STA). KeyInfo=0x008a (ACK, pairwise). KeyNonce=ANonce, 无 MIC, 无 KeyData
    eapol_1 = b"\x02\x03" + struct.pack(">H", 0x005f)   # EAPOL ver=2 type=3 len=95
    eapol_1 += b"\x02"                                    # KeyDescriptorType=2 (matches 2/4)
    eapol_1 += struct.pack(">H", 0x008a)                  # KeyInfo: 1/4 with ACK
    eapol_1 += struct.pack(">H", 32)                      # KeyLength
    eapol_1 += bytes.fromhex("0000000000000001")          # ReplayCounter=1
    eapol_1 += ANONCE                                     # KeyNonce
    eapol_1 += b"\x00"*16 + b"\x00"*8 + b"\x00"*8         # IV + RSC + ID
    eapol_1 += b"\x00"*16                                 # MIC (1/4 has none)
    eapol_1 += struct.pack(">H", 0)                      # KeyDataLength=0

    def make_80211_frame(to_ds, from_ds, bssid, src, dst, payload):
        # FC byte0=0x08 (Data type2 subtype0), byte1=ToDS|FromDS flags
        fc = bytes([0x08, (to_ds & 1) | ((from_ds & 1) << 1)])
        if to_ds == 1 and from_ds == 0:      # STA->AP: A1=BSSID, A2=SA, A3=DA
            a1, a2, a3 = bssid, src, dst
        elif to_ds == 0 and from_ds == 1:     # AP->STA: A1=DA, A2=BSSID, A3=SA
            a1, a2, a3 = dst, bssid, src
        else:
            a1, a2, a3 = bssid, src, dst
        hdr = fc + b"\x00\x00" + a1 + a2 + a3 + b"\x00\x00"
        llc = bytes.fromhex("aaaa03000000888e")  # LLC SNAP EAPOL
        return hdr + llc + payload

    # 1/4: AP->STA (FromDS). bssid=AP, src=AP, dst=STA
    f1 = make_80211_frame(0, 1, AP, AP, STA, eapol_1)
    # 2/4: STA->AP (ToDS). bssid=AP, src=STA, dst=AP
    f2 = make_80211_frame(1, 0, AP, STA, AP, EAPOL2)

    pcap = struct.pack("<IHHIIII", 0xa1b2c3d4, 2, 4, 0, 0, 65535, 105)  # linktype 105 = 802.11
    import time; ts = int(time.time())
    for fr in [f1, f2]:
        pcap += struct.pack("<IIII", ts, 0, len(fr), len(fr)) + fr
        ts += 1
    with open(outfile, "wb") as f:
        f.write(pcap)
    print(f"pcap 写入 {outfile}: 2 帧 ({len(f1)}+{len(f2)} bytes)")
    print("验证: aircrack-ng 应显示 WPA (1 handshake)")

if __name__ == "__main__":
    # 内置 2026-08-20 实验数据
    build_pcap(
        ap_mac="a8934a0b5127",
        sta_mac="deb35ce4a67f",
        anonce="9fcad81678002273d17ba89c51767b88bf91226dc91beb58e3ce9dd003ae2d44",
        snonce="623543efe5bcb1f7d199fc1808f8f47de4505739377673cb5b51e703c926c1",
        eapol_2_4_hex=("01 03 00 75 02 01 0a 00 00 00 00 00 00 00 00 00 01 "
                       "62 35 43 ef e5 bc b1 f7 d1 99 fc 18 08 f8 88 f4 7d e4 50 57 79 37 76 73 cb 5b 51 e7 03 c9 26 c1 "
                       "00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "
                       "c8 d5 86 81 ba 5c a3 31 2a e1 32 0e b9 66 49 b5 "
                       "00 16 30 14 01 00 00 0f ac 04 01 00 00 0f ac 04 01 00 00 0f ac 02 00 00"),
        mic_hex="c8d58681ba5ca3312ae1320eb96649b5",
        essid="LAB-WPA2-TEST",
        outfile="/tmp/handshake_reconstructed.pcap",
    )
