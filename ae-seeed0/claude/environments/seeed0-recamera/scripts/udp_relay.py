#!/usr/bin/env python3
"""UDP datagram relay (seeed0 side) — fallback when the device is NOT on the same
L2 subnet as the local PC.

Receives UDP datagrams from the reCamera (USB link) on a local port and
forwards each datagram unchanged to the local PC's viewer. Fire-and-forget: no
reassembly, no backpressure, lowest latency. Use ONLY when direct device->PC
UDP is not possible (device reachable only via seeed0 USB, or routed path has a
PMTU black hole that kills large TCP segments but passes small UDP datagrams).

Prefer direct device->PC UDP when the device shares a subnet with the PC
(check: `ip route get <PC_IP>` on the device shows `dev <iface> src <same_subnet_IP>`
with NO `via <gateway>`).

Run on seeed0:
  python3 udp_relay.py <local_recv_port> <target_host> <target_port>
Example:
  python3 udp_relay.py 9100 192.168.2.101 9200
  # device sender targets seeed0's USB IP:<local_recv_port> (discover seeed0's
  # USB IP on seeed0 with scripts/seeed0_usb_ip.sh)
"""
import socket
import sys


def main(local_port, target_host, target_port):
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 2 << 20)
    except OSError:
        pass
    sock.bind(("0.0.0.0", local_port))
    print(f"udp_relay :{local_port} -> {target_host}:{target_port}", flush=True)
    target = (target_host, target_port)
    while True:
        try:
            data, _ = sock.recvfrom(65535)
            sock.sendto(data, target)
        except OSError:
            continue


if __name__ == "__main__":
    lp = int(sys.argv[1])
    th = sys.argv[2]
    tp = int(sys.argv[3])
    raise SystemExit(main(lp, th, tp))
