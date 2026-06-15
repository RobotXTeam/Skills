# reCamera Demo Project Layout

## Default Repository

Steven's active SG200X/reCamera C++ demo repository — the single source of truth for both editing and building — lives on the `seeed` host:

```text
seeed:/home/seeed/sscma-example-sg200x
```

All reCamera demo code (the local repo) and all builds happen here. SSH into `seeed` and edit/build the repository there; there is no separate local-PC copy.

## Demo Directory Rule

All new reCamera C++ demos and project experiments should be created under:

```text
/home/seeed/sscma-example-sg200x/solutions/sesg-project/<demo_name>
```

Avoid adding new demos under `solutions/cosg-project` or directly under `solutions/` unless Steven explicitly requests that layout. Existing demos can remain in their original directories, but new work defaults to `sesg-project`.

## Current Migrated Demo

`depth_anything_npu` was migrated from:

```text
/home/seeed/sscma-example-sg200x/solutions/depth_anything_npu
```

to:

```text
/home/seeed/sscma-example-sg200x/solutions/sesg-project/depth_anything_npu
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

For model demos, keep generated models, complete evidence images, and evidence videos outside the source tree unless they are intentionally part of the repository. Publish demo assets through Steven's rclone Google Drive remote:

```text
agent:reCamera_Shared/Wiki/<demo_name>/model/
agent:reCamera_Shared/Wiki/<demo_name>/evidence/image/
agent:reCamera_Shared/Wiki/<demo_name>/evidence/video/
```

Public README/Wiki docs must include the generated Google Drive public links from:

```bash
https://drive.google.com/drive/folders/1GOQUMCel7fapbJCWzEEynDIvIt-6Wf5p?usp=drive_link
```

Also document the exact child paths:

```text
/reCamera_Shared/Wiki/<demo_name>/model/
/reCamera_Shared/Wiki/<demo_name>/evidence/image/
/reCamera_Shared/Wiki/<demo_name>/evidence/video/
```

By default, do not commit or push large model binaries such as `.cvimodel`, `.onnx`, `.pth`, or `.pt`, complete evidence image sets, or evidence videos to GitHub repositories. Upload them to the fixed Google Drive asset directories and document the verified Wiki root public link, exact child paths, and exact file names in README/Wiki. Do not use GitHub Release/LFS as the default publishing path.

## Public Documentation Path Rule

README, Wiki, demo docs, and source-code example comments are written for other developers, not only for Steven's local machine. Do not include local absolute paths such as:

```text
/home/steven/...
/home/steven/work/...
/home/steven/下载/...
```

Use portable forms instead:

```text
$REPO_ROOT/solutions/sesg-project/<demo_name>
$SDK_ROOT
$TOOLCHAIN_BIN
$DEMO_DIR
<path-to-model>
docs/evidence/<file>
```

Real local validation paths can be recorded in internal deployment reports, but public README/Wiki/demo docs should use relative paths, environment variables, placeholders, or pseudo commands.
