# reCamera Demo Project Layout

## Default Repository

Steven's active SG200X/reCamera C++ demo repository — the single source of truth for both editing and building — lives on the `seeed` host:

```text
seeed:/home/seeed/work/sscma-example-sg200x
```

All reCamera demo code (the local repo) and all builds happen here. SSH into `seeed` and edit/build the repository there; there is no separate local-PC copy.

## Demo Directory Rule

All new reCamera C++ demos and project experiments should be created under:

```text
/home/seeed/work/sscma-example-sg200x/solutions/sesg-project/<demo_name>
```

Avoid adding new demos under `solutions/cosg-project` or directly under `solutions/` unless Steven explicitly requests that layout. Existing demos can remain in their original directories, but new work defaults to `sesg-project`.

## Current Migrated Demo

`depth_anything_npu` was migrated from:

```text
/home/seeed/work/sscma-example-sg200x/solutions/depth_anything_npu
```

to:

```text
/home/seeed/work/sscma-example-sg200x/solutions/sesg-project/depth_anything_npu
```

When syncing to `seeed`, keep this migrated path as the canonical location.

## Expected Demo Shape

A new demo directory should normally contain:

```text
solutions/sesg-project/<demo_name>/
  CMakeLists.txt
  main/
    CMakeLists.txt
    main.cpp
  rootfs/            # optional runtime service/package files
  control/           # optional package scripts
  README.md          # optional short local runbook
```

## GitHub Completeness Contract

Every demo pushed to `RobotXTeam/sscma-example-sg200x` must be complete source code for an external developer, not only the files needed by Steven's local machine.

The GitHub demo directory must include:

- all source files required to build the executable;
- the build entrypoint (`CMakeLists.txt`, `build.sh`, or equivalent) with executable bits set when scripts are invoked as `./script.sh`;
- any small headers, config files, startup scripts, service files, receiver scripts, and README/Wiki docs needed to understand and reproduce the demo;
- a small set of key evidence images/text files when useful for review.

The GitHub demo directory must not rely on:

- uncommitted files in `seeed:/home/seeed/work/sscma-example-sg200x`;
- Steven's local `/home/steven/...` files;
- hidden model files or libraries that are neither committed nor documented in Google Drive;
- undocumented CMake flags or manual environment changes.

After cloning GitHub and downloading the documented Google Drive assets, the user must be able to:

1. run the documented build command;
2. produce a reCamera-compatible RISC-V musl executable;
3. copy the executable plus documented model/runtime assets to reCamera;
4. run the documented command and reproduce the demo behavior.

For model demos, keep generated models, complete evidence images, and evidence videos outside of the GitHub source tree by default (no `.cvimodel`, `.onnx`, `.pth`, `.pt`, full evidence sets, evidence videos, or large runtime libraries in git). Publish them to the fixed Google Drive directories (`run/`, `model/`, `evidence/image/`, `evidence/video/` under `agent:reCamera_Shared/Wiki/<demo_name>/`) and document the fixed Wiki root public link, exact child paths, and exact file names in README/Wiki. Do not use GitHub Release/LFS as the default publishing path. Full directory constants and upload commands: see `environments/seeed-recamera/network.md` (云端资产发布).

## Post-Push Clean Verification

After pushing a demo from `seeed` to GitHub, verify the pushed version before finalizing the Wiki: clean clone -> build with public command -> `file` check -> pull Drive assets -> deploy to reCamera -> run and collect evidence. If any step fails, the demo is not complete — return to the repository, fix, push again, and repeat until the full loop passes.

The canonical 7-step procedure and failure handling live in `environments/seeed-recamera/development-policy.md` (Post-Push Verification Gate).

## Public Documentation Path Rule

README, Wiki, and demo docs are written for other developers, not only for Steven's local machine. Never include local absolute paths (`/home/steven/...`, `/home/seeed/...`); use relative paths or portable variables (`$REPO_ROOT`, `$SDK_ROOT`, `$TOOLCHAIN_BIN`, `$DEMO_DIR`, `<path-to-model>`). Real local validation paths belong in internal deployment reports only. The full rule set is in `templates/wiki-output.md` (关键规则 2：路径处理).
