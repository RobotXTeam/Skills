#!/usr/bin/env python3
"""UDP MJPEG live OSD viewer (local PC / Steven side).

Receives fragmented UDP datagrams (see udp_sender.py), reassembles by frame_id,
decodes with cv2.imdecode, and shows the LATEST decoded frame in a continuously
updating window. Stale/incomplete frames are dropped automatically: latency
stays low and a lost datagram just skips a frame (no stall, no TCP head-of-line
blocking). Reader thread decodes+stores latest; main thread just imshows.

Run on the local PC (needs X11/Wayland + opencv):
  DISPLAY=:0 python3 udp_viewer.py [port] [title]
Example:
  DISPLAY=:0 python3 udp_viewer.py 9200 "reCamera live OSD"
"""
import sys
import time
import struct
import socket
import threading

import cv2
import numpy as np

MAGIC = 0xB0C0
HEAD = struct.Struct(">HHHHH")  # magic, frame_id, frag_idx, frag_count, frag_len


def main(port, title):
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 4 << 20)
    except OSError:
        pass
    sock.bind(("0.0.0.0", port))
    print(f"udp_viewer :{port}", flush=True)
    cv2.namedWindow(title, cv2.WINDOW_NORMAL)
    cv2.resizeWindow(title, 720, 540)

    lock = threading.Lock()
    state = {"frame": None, "id": -1, "pkts": 0, "complete": 0, "t0": time.time()}

    def reader():
        frags = {}
        while True:
            try:
                pkt, _ = sock.recvfrom(65535)
            except OSError:
                continue
            state["pkts"] += 1
            if len(pkt) < HEAD.size:
                continue
            magic, fid, idx, cnt, flen = HEAD.unpack(pkt[:HEAD.size])
            if magic != MAGIC:
                continue
            body = pkt[HEAD.size:HEAD.size + flen]
            if fid not in frags:
                if len(frags) > 8:  # drop very stale partial frames
                    frags.clear()
                frags[fid] = {}
            frags[fid][idx] = body
            if len(frags[fid]) == cnt:
                data = b"".join(frags[fid][k] for k in sorted(frags[fid].keys()))
                frags.pop(fid, None)
                arr = np.frombuffer(data, dtype=np.uint8)
                img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
                if img is not None:
                    with lock:
                        if fid > state["id"]:
                            state["frame"] = img
                            state["id"] = fid
                    state["complete"] += 1
            now = time.time()
            if now - state["t0"] >= 2.0:
                print(f"pkts={state['pkts']} complete={state['complete']}", flush=True)
                state["pkts"] = 0
                state["complete"] = 0
                state["t0"] = now

    threading.Thread(target=reader, daemon=True).start()
    t0 = time.time()
    shown = 0
    while True:
        with lock:
            frame = state["frame"]
        if frame is not None:
            cv2.imshow(title, frame)
            shown += 1
        key = cv2.waitKey(1) & 0xFF
        if key == ord("q") or key == 27:
            return 0
        try:
            if cv2.getWindowProperty(title, cv2.WND_PROP_VISIBLE) < 1:
                return 0
        except cv2.error:
            return 0
        now = time.time()
        if now - t0 >= 2.0:
            print(f"shown {shown}/{now-t0:.1f}s", flush=True)
            shown = 0
            t0 = now
    return 0


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 9200
    title = sys.argv[2] if len(sys.argv) > 2 else "reCamera live OSD"
    raise SystemExit(main(port, title))
