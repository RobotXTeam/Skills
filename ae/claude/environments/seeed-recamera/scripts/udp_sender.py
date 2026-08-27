#!/usr/bin/env python3
"""UDP MJPEG frame sender (reCamera device side, fire-and-forget).

Watches a directory of frame_NNNN.jpg produced by any reCamera demo, fragments
each NEWEST COMPLETE JPEG into UDP datagrams, and blasts them to a target
host:port (the local PC's viewer, or a relay). No TCP backpressure: a late frame
is simply superseded by the next, which is ideal for low-latency live preview.

Only complete JPEGs are sent: a frame still being written by the demo (no EOI
marker yet) is retried on the next tick, never skipped — this is the key fix
that stops corrupt/truncated frames (file sizes that are multiples of 4096 are
a tell-tale of a half-written file).

Datagram layout (big-endian, 10-byte header):
  magic u16 (0xB0C0) | frame_id u16 | frag_idx u16 | frag_count u16 | frag_len u16 | payload(<=1390)

Run on the device (as root, so it can read root-owned demo frames):
  sudo python3 udp_sender.py <frame_dir> <target_host> <target_port>
Example:
  sudo python3 udp_sender.py /home/recamera/<demo>/live 192.168.2.101 9200
"""
import os
import sys
import time
import struct
import socket

MAGIC = 0xB0C0
HEAD = struct.Struct(">HHHHH")  # magic, frame_id, frag_idx, frag_count, frag_len
MTU = 1400  # safe under common path MTU; small datagrams also dodge PMTU black holes


def main(frame_dir, target_host, target_port):
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF, 1 << 20)
    except OSError:
        pass
    frag_len = MTU - HEAD.size
    frame_id = 0
    last_path = ""
    mtime_cache = {}
    sent = 0
    t0 = time.time()
    print(f"udp_sender -> {target_host}:{target_port} dir={frame_dir}", flush=True)
    while True:
        try:
            names = os.listdir(frame_dir)
        except OSError:
            time.sleep(0.01)
            continue
        # Pick the NEWEST file by mtime, not by name: frame counters grow past
        # 10000 and restart at 0 across demo runs, both of which break lexicographic
        # "max". stat results are cached per filename (frames are written once), so
        # this stays cheap even with thousands of files in the directory.
        best = ""
        best_mt = -1.0
        seen = set()
        for nm in names:
            if not (nm.startswith("frame_") and nm.endswith(".jpg")):
                continue
            seen.add(nm)
            mt = mtime_cache.get(nm)
            if mt is None:
                try:
                    mt = os.path.getmtime(os.path.join(frame_dir, nm))
                except OSError:
                    continue
                mtime_cache[nm] = mt
            if mt > best_mt:
                best, best_mt = nm, mt
        if len(mtime_cache) > len(seen) + 512:
            mtime_cache = {k: v for k, v in mtime_cache.items() if k in seen}
        if not best or best == last_path:
            time.sleep(0.005)
            continue
        path = os.path.join(frame_dir, best)
        try:
            with open(path, "rb") as fh:
                data = fh.read()
        except OSError:
            time.sleep(0.005)
            continue
        # Only send complete JPEGs. Do NOT advance last_path on an incomplete
        # frame so we retry the same file once the demo finishes writing it.
        if not data or data[:2] != b"\xff\xd8" or data[-2:] != b"\xff\xd9":
            time.sleep(0.005)
            continue
        last_path = best
        total = len(data)
        nfr = (total + frag_len - 1) // frag_len
        frame_id = (frame_id + 1) & 0xFFFF
        for i in range(nfr):
            chunk = data[i * frag_len:(i + 1) * frag_len]
            try:
                sock.sendto(HEAD.pack(MAGIC, frame_id, i, nfr, len(chunk)) + chunk,
                            (target_host, target_port))
            except OSError:
                break
        sent += 1
        now = time.time()
        if now - t0 >= 2.0:
            print(f"sent {sent} frames, {sent/(now-t0):.1f} fps, last_size={total}", flush=True)
            sent = 0
            t0 = now


if __name__ == "__main__":
    frame_dir = sys.argv[1] if len(sys.argv) > 1 else "."
    host = sys.argv[2] if len(sys.argv) > 2 else "127.0.0.1"
    port = int(sys.argv[3]) if len(sys.argv) > 3 else 9200
    raise SystemExit(main(frame_dir, host, port))
