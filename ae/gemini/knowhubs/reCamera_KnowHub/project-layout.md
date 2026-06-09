# reCamera Demo Project Layout

## Default Repository

Steven's active SG200X/reCamera C++ demo repository is now maintained on the `seeed` host:

```text
seeed:/home/steven/sscma-example-sg200x
```

Do not create, delete, or modify new reCamera demo code in the local PC copy unless Steven explicitly asks for local-only work. For normal demo development, SSH into `seeed` and edit the repository there.

## Demo Directory Rule

All new reCamera C++ demos and project experiments should be created under:

```text
/home/steven/sscma-example-sg200x/solutions/sesg-project/<demo_name>
```

Avoid adding new demos under `solutions/cosg-project` or directly under `solutions/` unless Steven explicitly requests that layout. Existing demos can remain in their original directories, but new work defaults to `sesg-project`.

## Current Migrated Demo

`depth_anything_npu` was migrated from:

```text
/home/steven/sscma-example-sg200x/solutions/depth_anything_npu
```

to:

```text
/home/steven/sscma-example-sg200x/solutions/sesg-project/depth_anything_npu
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

For model demos, place generated models and large evidence files outside the source tree unless they are intentionally part of the repository. Use `/home/steven/work/<demo_name>` on the active host for conversion artifacts, logs, and videos.

