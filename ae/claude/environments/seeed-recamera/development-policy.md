# seeed Host Development Policy

## Canonical Edit Location

For reCamera C++ demos, the single canonical working repository — local repo, build location, and source of truth — is:

```text
seeed:/home/seeed/sscma-example-sg200x
```

Default behavior for all AE demo work:

- SSH into `seeed`.
- Create, edit, move, delete, build, and package demo code on `seeed`.
- Everything (the local repository AND every build) lives under `/home/seeed/sscma-example-sg200x`. There is no separate local-PC copy of the repo to keep in sync.

## New Demo Placement

Create all new reCamera demos under:

```text
/home/seeed/sscma-example-sg200x/solutions/sesg-project/<demo_name>
```

Avoid `solutions/cosg-project` for new demos unless Steven specifically requests it.

## GitHub CLI

`gh` is installed on `seeed`:

```text
/usr/bin/gh
gh version 2.4.0+dfsg1 (Ubuntu 22.04 universe package)
```

The official GitHub CLI apt source was tested but package download from `cli.github.com` stalled in this environment, so the working installed package is Ubuntu's `gh` package. It is sufficient for `gh auth login`, `gh auth status`, and normal GitHub repo operations. Upgrade later if a newer CLI feature is required and the official package source is reachable.

Steven will log in with his own GitHub account:

```bash
gh auth login
gh auth status
```

After a demo is finished and Steven approves the effect, commit and push from `seeed` directly to GitHub. Do not push demo work before Steven approval.

## Post-Push Verification Gate

Pushing to GitHub is not the end of a demo. A demo is complete only after the pushed GitHub version passes a clean verification loop.

Required sequence after `git push origin main`:

1. Clone the latest GitHub `main` into a clean temporary verification directory. Do not reuse the working repository.
2. Confirm the clean clone commit is the commit just pushed from `seeed`.
3. Build the demo using only the public README/Wiki command. The command must not require undocumented flags or private absolute paths.
4. Verify the executable with `file`; it must be a reCamera-compatible RISC-V musl ELF.
5. Pull the required `run/`, `model/`, and runtime library assets from Steven's Google Drive remote paths documented for the demo.
6. Deploy the clean-clone executable and Drive assets to reCamera.
7. Run the demo with the documented public command and collect evidence.

If this loop fails at any step, return to:

```text
seeed:/home/seeed/sscma-example-sg200x
```

Fix the source, scripts, README/Wiki, or Google Drive asset publication, then commit, push, and repeat the clean verification loop. Do not finalize or publish the Wiki until the loop passes.

The GitHub repository must contain complete buildable source code. Large models, complete evidence sets, evidence videos, and large runtime libraries can live in Google Drive, but every such external asset must be listed in README/Wiki with exact filenames and fixed child paths.

## Sync Note

The `seeed` repository at:

```text
seeed:/home/seeed/sscma-example-sg200x
```

is the source of truth for all demo source edits, builds, and commits. Do not maintain a parallel local-PC copy.
