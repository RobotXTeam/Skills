# seeed Host Development Policy

## Canonical Edit Location

For reCamera C++ demos, the canonical working repository is:

```text
seeed:/home/steven/sscma-example-sg200x
```

Default behavior for future AE demo work:

- SSH into `seeed`.
- Create, edit, move, delete, build, and package demo code on `seeed`.
- Do not modify the local PC copy of `/home/steven/sscma-example-sg200x` unless Steven explicitly asks for local-only work.

## New Demo Placement

Create all new reCamera demos under:

```text
/home/steven/sscma-example-sg200x/solutions/sesg-project/<demo_name>
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

## Sync Note

The initial migration copies the local `/home/steven/sscma-example-sg200x` repository to:

```text
seeed:/home/steven/sscma-example-sg200x
```

After that migration, treat the `seeed` copy as the source of truth for future demo source edits.
