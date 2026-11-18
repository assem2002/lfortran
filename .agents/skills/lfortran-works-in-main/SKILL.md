---
name: lfortran-works-in-main
description: Label an LFortran GitHub issue "works in main" when current upstream main already does what the issue asks for, whether or not the repository already has a test for it. Use it whenever an issue does not reproduce on main - an agent reports `WORKS IN MAIN`, you see it while reproducing, picking, triaging or reviewing issues, or the user asks whether some issues still fail on main. The label is the only action - no comment, no close, no test, no PR.
---

# Issues that already work on main

The user, 2026-10-21: "any issue that actually works in main should be labeled 'works in main'", and "just add the label and don't add the test or open a PR for such issue". On 2026-11-17 they made it a skill of its own: label such an issue "has a test or not".

The label is `works in main` (with spaces) in `lfortran/lfortran`, green, "This issue describes a code that actually works in main now. Add a test and close it." Someone else adds the test and closes the issue; you only label.

## When

Any time you meet an issue that does not reproduce on main:
- a fixer agent reports `WORKS IN MAIN` (the batch-fix workflow; the coordinator labels, not the agent);
- you reproduce an issue yourself and it already works;
- you pick, triage or classify issues and check them on main;
- the user asks which of some issues still fail.

Skip an issue that already has the label, or that is closed.

## 1. Check it on current main

1. Read the whole issue and its comments: `gh issue view <N> --repo lfortran/lfortran --comments`. List every program and every scenario (flags, backends, follow-up programs in comments).
2. Use the main build `~/lfortran_test/lfortran/src/bin/lfortran`, by explicit path. Note its commit: `git -C ~/lfortran_test/lfortran rev-parse --short=10 HEAD`. If it is older than `origin/main` by more than a few days, or the issue was touched by a recent commit, rebuild it first with `<skills>/lfortran-batch-fix/scripts/build_main.sh` (`<skills>` is the folder that holds this skill) (it queues behind the build slot; never build it any other way). In a batch, use the batch's `base_sha` instead.
3. Run each program in a scratch directory with the same flags the issue uses, and with `gfortran` (`/usr/bin/gfortran`) for comparison. Do not run anything inside `~/lfortran_test/lfortran`.

## 2. Decide

It works in main only if EVERY program and scenario of the issue and its comments now does what the issue asks for:
- **Valid code:** compiles and runs, and the output matches gfortran (same values; formatting differences that the standard allows are fine).
- **Invalid code** (the issue asks for an error): LFortran gives a proper error at the right place, not a crash, an internal error or silent acceptance.
- **A crash or ICE report:** no crash, and the result is right, not just "no longer crashes".

Do not label, and tell the user instead, when:
- only some programs or scenarios work;
- gfortran rejects code that the issue calls valid, or it is unclear what the issue expects;
- the issue needs something you cannot run here (another OS, a GPU, a backend or option not in the main build): say what you could check;
- it works only with different flags than the issue uses.

Whether the repository already has a test for it does not matter. Do not search for one, and do not add one.

## 3. Label

```bash
gh issue edit <N> --repo lfortran/lfortran --add-label "works in main"
```

Keep its other labels. Do not comment on the issue, close it, add a test, make a branch or open a PR. If a worktree was made for it in the batch-fix workflow, remove it with `<skills>/lfortran-batch-fix/scripts/cleanup_issue.sh <N>`.

## 4. Report

One line per issue: `#<N> works in main (labeled), checked on <sha>`, plus what was run (each program, LFortran vs gfortran in a few words). For an issue you did not label, say why in one line.
