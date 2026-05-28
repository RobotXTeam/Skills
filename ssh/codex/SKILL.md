---
name: ssh
description: SSH into Steven's devices using the host inventory. Use when the user asks to SSH, connect, remote into, or run commands on any of the known hosts (openwrt, orangepi, qiang, seeed, steven, recamera, jetson, rv1126b, rk3588, etc).
---

# SSH Skill

Connect to Steven's devices via SSH. Use the host table below to find the correct host alias, then connect with `ssh <alias>`.

Default execution stance: Codex should perform the SSH connection and remote commands directly. Do not give the user commands to copy-paste; execute them yourself and report results.

## Host inventory

| Alias | IP | User | Password | X11 | Notes |
|-------|-----|------|----------|-----|-------|
| openwrt | 100.90.115.46 | root | pi | no | Tailscale |
| orangepi | 100.122.52.107 | orangepi | 1 | no | Tailscale |
| qiang | 100.78.97.65 | steven | 1 | no | Tailscale |
| seeed | 100.76.45.91 | seeed | 0 | no | Tailscale |
| steven | 100.108.64.20 | steven | 1 | no | Tailscale |
| recamera | 192.168.42.1 | recamera | - | no | Direct LAN |
| recamera-10 | 192.168.2.10 | recamera | kkk000++ | no | LAN |
| recamera-11 | 192.168.2.11 | recamera | kkk000++ | no | LAN |
| recamera-12 | 192.168.2.12 | recamera | kkk000++ | no | LAN |
| recamera-nom | 192.168.2.15 | recamera | kkk000++ | no | LAN |
| recamera-200 | 192.168.2.200 | recamera | kkk000++ | no | LAN |
| recamera-201 | 192.168.2.201 | recamera | kkk000++ | no | LAN |
| recamera pro | 192.168.2.141 | root | 1 | yes | LAN |
| jetson | 192.168.2.30 | jetson | 1 | yes | LAN |
| rv1126b | 192.168.2.51 | root | 1 | yes | LAN |
| openwrt-lan | 192.168.2.1 | root | pi | yes | LAN duplicate |
| rk3588 | 192.168.5.50 | orangepi | 1 | yes | LAN |

## How to connect

All hosts are configured in `~/.ssh/config`. Connect by alias:

```bash
ssh <alias>
```

For example: `ssh orangepi`, `ssh jetson`, `ssh recamera-11`.

## Password handling

Passwords are listed above for reference. If SSH key auth is not set up, use `sshpass` for non-interactive login:

```bash
sshpass -p '<password>' ssh <alias>
```

## Running remote commands

Pass commands as arguments to run non-interactively:

```bash
ssh <alias> 'command here'
```

## File transfer

Use scp or rsync with the alias:

```bash
scp localfile.txt <alias>:/path/to/dest/
rsync -avz ./dir/ <alias>:/path/to/dest/
```

## Notes

- Tailscale hosts (100.x.x.x) are reachable from anywhere via Tailscale mesh.
- LAN hosts (192.168.x.x) require being on the same local network.
- `recamera` at 192.168.42.1 is the direct USB/ethernet connection to the recamera device.
- `openwrt` appears twice — Tailscale IP 100.90.115.46 and LAN IP 192.168.2.1. Prefer the Tailscale address for remote access.
