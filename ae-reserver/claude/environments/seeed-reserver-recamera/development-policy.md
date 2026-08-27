# seeed-reserver Host Development Policy

## Canonical Edit Location

For reCamera C++ demos, the single canonical working repository — local repo, build location, and source of truth — is:

```text
seeed-reserver:/home/seeed0/sscma-example-sg200x
```

Default behavior for all AE demo work:

- SSH into `seeed-reserver`.
- Create, edit, move, delete, build, and package demo code on `seeed-reserver`.
- Everything (the local repository AND every build) lives under `/home/seeed0/sscma-example-sg200x`. There is no separate local-PC copy of the repo to keep in sync.
- The repository, toolchain, and all build directories stay on the NVMe SSD. The HDD mounted at `/media/seeed/新加卷` holds bulk data only (models, evidence, datasets) — never executables, build trees, or docker storage.

## New Demo Placement

Create all new reCamera demos under:

```text
/home/seeed0/sscma-example-sg200x/solutions/sesg-project/<demo_name>
```

Avoid `solutions/cosg-project` for new demos unless Steven specifically requests it.

## GitHub CLI

`gh` is installed on `seeed-reserver` and already logged in as `congchin38-coder` (credentials in `~/.config/gh/hosts.yml`); `gh auth setup-git` has been run. GitHub is reachable directly from seeed-reserver — no proxy of any kind, and never set `git config http.proxy` / `https.proxy`. The repository remote is currently an https URL with an embedded PAT (carried over in the migration); keep it as-is.

Check auth state with:

```bash
gh auth status
```

After a demo is finished and Steven approves the effect, commit and push from `seeed-reserver` directly to GitHub. Do not push demo work before Steven approval.

## Post-Push Verification Gate

Pushing to GitHub is not the end of a demo. A demo is complete only after the pushed GitHub version passes a clean verification loop.

Required sequence after `git push origin main`:

1. Clone the latest GitHub `main` into a clean temporary verification directory. Do not reuse the working repository.
2. Confirm the clean clone commit is the commit just pushed from `seeed-reserver`.
3. Build the demo using only the public README/Wiki command. The command must not require undocumented flags or private absolute paths.
4. Verify the executable with `file`; it must be a reCamera-compatible RISC-V musl ELF.
5. Pull the required `run/`, `model/`, and runtime library assets from Steven's Google Drive remote paths documented for the demo.
6. Deploy the clean-clone executable and Drive assets to reCamera.
7. Run the demo with the documented public command and collect evidence.

If this loop fails at any step, return to:

```text
seeed-reserver:/home/seeed0/sscma-example-sg200x
```

Fix the source, scripts, README/Wiki, or Google Drive asset publication, then commit, push, and repeat the clean verification loop. Do not finalize or publish the Wiki until the loop passes.

The GitHub repository must contain complete buildable source code. Large models, complete evidence sets, evidence videos, and large runtime libraries can live in Google Drive, but every such external asset must be listed in README/Wiki with exact filenames and fixed child paths.

## run/ Ready-to-Run Package (Core Requirement)

Google Drive is where users fetch everything needed to run a demo. **Every demo must have a `run/` folder so that a user who fetches `run/` + `model/` can run the demo directly on reCamera — no compilation, no files outside Google Drive.** `run/` contents:

- **reCamera executable** (cross-compiled RISC-V ELF, e.g. `onvif_yolo`, `gb28181_client`, `ppocr-reader`). Normally one executable is enough.
- **`README.md`**: a concise ready-to-run guide — which files to download (including the models in `../model/`), where to place them on the device, which services to stop, the full run command (threshold uses the best-tested value; prefer starting tuning from a relatively low confidence), and how to verify. Written for users who "fetch it and run it after a quick read".
- **Runtime dependencies**: only when system libraries are insufficient. For example GB28181 needs SIP libraries `lib/libeXosip2.so.* libosip2.so.* libosipparser2.so.*` plus one-click scripts such as `run_rtmp.sh` / `run_on_device.sh`. Normal demos can rely on the device's own `/mnt/system/lib` and need nothing extra.
- The executable does not have to be stripped, but it must be the device architecture (`file` must show `RISC-V ... ld-musl-riscv64*`).
- Models stay in `model/`; do not duplicate them into `run/`. The README tells the user to place both in the same device directory.

## Sync Note

The `seeed-reserver` repository at:

```text
seeed-reserver:/home/seeed0/sscma-example-sg200x
```

is the source of truth for all demo source edits, builds, and commits. Do not maintain a parallel local-PC copy.
