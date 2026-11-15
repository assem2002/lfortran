# Rules for a fresh reviewer (review round k of issue N)

You review ONE fix branch that another agent, the fixer, wrote. You did not write it. Nothing is public yet: the branch is published only after a review round finds no blocker and no rework item. You find problems and report them; the fixer fixes them. The coordinator gives you `<src>` (the issue's worktree), `<N>` (the issue) and `<k>` (the round).

The user asked for this on 2026-11-15, after a batch where every fix had passed its author's own review and the three suites, and fresh reviewers still found a regression, a new silently wrong result and two missed code paths in four PRs. All of them were found by running new programs, none by the suites. So run programs; do not only read the diff.

## Read first
- `<src>/.agents/skills/pr-review/SKILL.md` (load it; it is the review standard) and `<src>/AGENTS.md`.
- In `<src>/.fix-issue/<N>/machine.md`, only these sections apply to you: "Your job's facts" (worktree, branch, remotes), "The build slot replaces Pixi" (`slot.sh` builds and runs the branch, the main build is upstream `main`) and "What else differs from `fix-issue`" (minimal tests, tests in their own commit, plain English). Ignore the rest; this file replaces it.
- Do NOT read the fixer's notes in `<src>/.fix-issue/<N>/` (`state.md` notes, `fix_*.md`, `repro.md`, `review_*.md`, `round_*.md`, `followups.md`, `pr_body.md`) until you have written down your own findings. Form your view from the issue, the diff and your own programs. Afterwards, read `pr_body.md` (check that it is true), and in round 2 or later read the earlier `review_<j>.md` and `round_<j>.md` and check that each earlier finding is really fixed, or that the fixer's reason for not fixing it holds.

## Review
1. Read the issue and its comments (`gh issue view <N> --repo lfortran/lfortran --comments`), then the whole diff (`git -C <src> diff origin/main...HEAD`) and the code around it on `main`.
2. Judge, as `pr-review` says: is the root cause right; is the fix in the right layer; does it change what already-compiling programs do; does it reuse existing helpers; are the tests minimal and do they fail on `main` and pass on the branch; is the PR text true.
3. Run programs. Write your own small programs in `<src>/.fix-issue/<N>/review_<k>/` (only there: files there are gitignored and never reach the build slot). Run each with the branch (`slot.sh`), with `main` (the main build) and with gfortran, in normal, `--fast` and `--std=f23` mode, and compare. Aim at the paths next to the one the fix was made for. The places that hid bugs before:
   - the same call as a function reference and as a subroutine call; with OPTIONAL dummies, both present and absent;
   - generic, type-bound, generic type-bound and procedure-pointer calls; implicit interfaces; elemental procedures;
   - a call inside an IF, DO WHILE, SELECT CASE or DO head, and inside WHERE;
   - other types, kinds, ranks (0, 1, 2, assumed rank), character lengths, CLASS vs TYPE, POINTER/ALLOCATABLE/TARGET actuals and dummies, sections with strides;
   - each other place in the compiler that has a copy of the changed code (grep for it).
   A program that compiled on `main` and now fails or prints something else is a regression. A program that was a compile error on `main` and now runs with a wrong result is a blocker.
4. Write `<src>/.fix-issue/<N>/review_<k>.md`: one entry per finding, classed `blocker`, `rework`, `follow-up` or `nit`, each with the program path, the exact commands and the three outputs (branch, main, gfortran). Say what you checked that was fine, in one short list.

## What you must not do
- Do not edit, add or commit tracked files, and do not run `git` commands that change the branch. Leave `git -C <src> status --short` empty. The fixer makes every change.
- Do not push, open PRs, comment, label or file issues.
- Never run the suites (the fixer does after each change); single programs only. Batch your slot calls into one `slot.sh bash -c '...'` or script, run long ones in the background, and keep reading while you wait: the slot is shared.

## The verdict
- If the round has no blocker and no rework item, add the line `- review_clean_sha: <the branch's HEAD sha>` to `<src>/.fix-issue/<N>/state.md`. `publish_pr.sh` needs it, and refuses if the branch changes after it.
- Otherwise do not write that line.

## Report (at most about 25 lines)
- Verdict: `CLEAN` or `NEEDS WORK`, and the HEAD sha you reviewed.
- Findings, one line each with its class and the program path.
- In round 2 or later: each earlier finding, fixed or not.
- Unrelated bugs: LFortran bugs that the branch does not cause and does not need (they fail on `main` too), each with a standalone reproducer in `review_<k>/`, the command, the `main` output and the gfortran output. The coordinator files them. A bug that passes on `main` and fails on the branch is not unrelated: it is a finding.
