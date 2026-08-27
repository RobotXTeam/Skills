# Safety and Rollback

## Risk levels

1. Local frontend preview: no device write.
2. Web asset deployment: replaces `/usr/share/supervisor/www`; no device reboot or service restart.
3. Supervisor binary deployment: restarts only Supervisor and can briefly interrupt management APIs/UI.
4. Runtime shell/init deployment: can affect boot, camera ownership and recovery; requires explicit `--include-runtime`. With that flag the deploy also overlays `/usr/share/supervisor/addons` (add-on control scripts) with the same backup/rollback guarantees.
5. Firmware flashing/network reconfiguration: outside this skill's routine deployment path and requires separate authorization.

## Mandatory backup contents

A deployment backup under `/userdata/local/backups/reweb-<timestamp>` must include, when relevant:

- `mode.before`
- `services.before`
- `processes.before`
- `supervisor` binary
- `www` directory
- `main.sh`
- `S93sscma-supervisor`
- `addons` directory (add-on control scripts/manifests, `--include-runtime`)
- deployment manifest and checksums

Keep the backup path in the final report.

## Mode preservation

Read `/userdata/local/apps/mode` before touching services. Normalize only for reporting: `nodered` stays `nodered`; an absent, legacy `console`, or invalid value behaves as `recamera-studio`. Do not rewrite it merely to simplify deployment; the versioned init migration owns persistent normalization.

A successful deployment must prove the effective mode is unchanged. The Supervisor init script reconciles services to that persisted mode when it starts. Do not manually arm Node-RED in reCamera Studio mode or park it in Node-RED mode merely to make a deployment easier.

## Web rollback

`deploy-web.sh` uploads and validates a staging directory, moves the current web root into the backup, then moves staging into place. Its remote trap restores the old web root if validation or replacement fails.

Manual rollback shape (use the exact backup path reported by the script):

```bash
sudo rm -rf /usr/share/supervisor/www.failed && sudo mv /usr/share/supervisor/www /usr/share/supervisor/www.failed && sudo cp -a /userdata/local/backups/reweb-<timestamp>/www /usr/share/supervisor/www
```

No reboot is needed. Reload the browser and verify `/` plus `/api/version` or another known Supervisor API.

## Supervisor rollback

`deploy-supervisor.sh` stages a binary/package, backs up current files, stops only Supervisor, replaces selected files, starts Supervisor, then verifies process, HTTP and mode. A failure invokes rollback before exiting.

Manual rollback shape:

```bash
sudo /etc/init.d/S93sscma-supervisor stop
```

```bash
sudo cp -a /userdata/local/backups/reweb-<timestamp>/supervisor /usr/local/bin/supervisor
```

If runtime files were included, restore `main.sh` and `S93sscma-supervisor` from the same backup. Then:

```bash
sudo /etc/init.d/S93sscma-supervisor start
```

Confirm the original mode and S/K service prefixes. Do not reboot until the management endpoint is reachable or an explicit recovery decision is made.

## Failure policy

- Upload failure: do not stop services.
- Build failure: do not connect for deployment.
- Backup failure: abort before replacement.
- Mode mismatch after deployment: rollback.
- Supervisor fails to start or HTTP remains unavailable: rollback.
- SSH session drops during replacement: reconnect, inspect backup and staged paths, then restore; do not blindly rerun install.
- Camera service conflict: preserve original mode and diagnose ownership; do not kill all processes unless the user authorizes a recovery operation.

Never use `git reset --hard`, delete user workspace changes, or treat a package install as permission to erase persistent `/userdata` content.
