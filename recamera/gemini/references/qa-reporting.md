# Wiki QA Reporting

## Purpose

Every demo run should answer: "Can a developer reproduce this wiki on Steven's stable seeed + reCamera setup?"

The report must separate:

- What the wiki says.
- What happened when following it directly.
- What fixes were needed.
- Whether the demo ultimately ran.
- Evidence paths.
- A writing-quality score.

## Score Rubric

Use a 10-point score:

- 9-10: Runs as written. Minor wording or polish issues only.
- 7-8: Runs after small obvious fixes, such as adding environment variables or clarifying a port.
- 5-6: Runs only after nontrivial debugging, missing parameters, missing privileges, or undocumented asset handling.
- 3-4: Partially runs, but key output cannot be reproduced or evidence is weak.
- 1-2: Does not run after reasonable effort, or required assets/credentials/hardware are unavailable without being documented.

Do not call a wiki "good" just because Codex eventually fixed it. The score is for reproducibility from the wiki.

## Required Report Shape

```markdown
## Wiki QA Report: <title>

Source:
- Wiki file: `<path>`
- Public URL: <url>
- Tested on: <date>, seeed `<host/ip>`, reCamera `<ip/os>`

Result:
- Direct wiki run: pass/fail
- Final run after fixes: pass/fail
- Score: N/10

Evidence:
- Logs: <paths or summarized key lines>
- Screenshot/frame: <path>
- Device artifacts: <paths>

Direct-run findings:
- ...

Fixes applied:
- ...

What the wiki should change:
- ...

Notes:
- ...
```

## Status Language

- `pass-as-written`: direct wiki steps worked.
- `pass-with-fixes`: demo worked after undocumented but reasonable fixes.
- `partial`: program started but key expected output was missing.
- `blocked`: cannot continue because required asset, credential, account, or hardware is unavailable.
- `fail`: reasonable debugging exhausted and demo still does not work.
