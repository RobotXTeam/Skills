---
name: ibus
description: Diagnose, repair, deploy, and maintain Steven's Ubuntu 22.04 GNOME IBus/libpinyin Chinese display setup without logging out. Use when pinyin candidates, system Chinese text, or notifications are blank/garbled; when candidate-window fonts need repair while preserving the current horizontal/vertical layout and page size; or when installing/updating the local “输入法拼音显示修复” desktop application.
---

# IBus 中文显示修复

Repair Chinese font fallback and the IBus/libpinyin candidate window while keeping the active GNOME session and application windows alive. Preserve candidate layout, candidate count, display scaling, input sources, and unrelated desktop preferences unless the user explicitly requests a change.

## Workflow

1. Run the read-only diagnosis:

   ```bash
   bash scripts/diagnose.sh
   ```

2. Read [references/diagnosis.md](references/diagnosis.md) when interpreting font, Locale, IBus, D-Bus, or candidate-layout results.
3. If `fonts-noto-cjk`, `fontconfig`, `ibus`, or `ibus-libpinyin` is absent or fails `dpkg -V`, repair only the affected package. Do not reinstall healthy packages by default.
4. Apply the user-level repair:

   ```bash
   bash scripts/apply-fix.sh --notify
   ```

   This backs up settings, installs the known-good fontconfig rule, selects Noto CJK for GNOME and IBus, rebuilds the user font cache, and hot-restarts IBus. It does not log out or restart GNOME Shell.

5. Install or update the desktop repair application when requested:

   ```bash
   bash scripts/install-app.sh
   ```

6. Run `bash scripts/diagnose.sh` again and verify:

   - GNOME UI font is `Noto Sans CJK SC 11`.
   - IBus custom font is enabled as `Noto Sans CJK SC 12`.
   - `use-glyph-from-engine-lang` is `true`.
   - The active engine is still the intended engine, normally `libpinyin`.
   - Candidate orientation and page size exactly match the pre-repair values.
   - Recent user journal entries contain no new IBus/font/Pango errors.

## Safety Rules

- Never log out, reboot, restart GDM, or run `gnome-shell --replace` for this repair unless the user explicitly authorizes it.
- Never reset `/desktop/ibus/panel/` wholesale.
- Never change `display-style`, `lookup-table-orientation`, `lookup-table-page-size`, display scaling, fractional scaling, or monitor orientation unless explicitly requested.
- Back up Dconf and replaced files before mutation. Store backups under `~/.local/state/ibus-skill/`.
- Prefer the user-level fix first. Escalate to package repair only when files are absent or package verification fails.
- Reopen only an affected application if it retains an old font cache; do not log out.

## Resources

- `scripts/diagnose.sh`: read-only system, font, Locale, GNOME, and IBus inspection.
- `scripts/apply-fix.sh`: backed-up, layout-preserving, no-logout live repair.
- `scripts/install-app.sh`: install/update the desktop application and startup font guard.
- `assets/runtime/`: exact runtime project files and configuration templates.
- [references/project-files.md](references/project-files.md): live paths, deployment mapping, backups, and validation commands.
