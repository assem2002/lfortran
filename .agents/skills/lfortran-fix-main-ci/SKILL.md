---
name: lfortran-fix-main-ci
description: Find, reduce and fix a failure in LFortran's CI on `main`, most often a third-party application in the Exhaustive checks (FIATS, fpm, neural-fortran, ...). Use it when the user pastes a GitHub Actions run or job URL, or says CI, Exhaustive or Quick on main is red, or that a third-party code broke. It goes from the failing job to a reproducer on this machine, an MRE, the commit that caused it, a revert-or-fix decision, and a PR that links the run (ready for review with auto-merge when it changes at most 20 lines, a draft otherwise).
---

# Fixing a red CI job on main

The repository's rule (AGENTS.md, CI policy): a failure found by an application
must become a reduced integration test, and it is fixed promptly or the change
that caused it is reverted. This skill is that loop on this machine.

Builds go through the build slot of the `lfortran-batch-fix` skill (`slot.sh`).
Never build LFortran any other way here; the user's words: "Use the build slot
if you're building lfortran". The rules of the `building-lfortran` skill hold:
everything on `/media/assem/nvme-9gb`, 8 threads.

Scripts are in this skill's `scripts/` folder (`<skill>/scripts/...` below).
`<skills>` is the folder that holds this skill and `lfortran-batch-fix`.

## 1. Read the failing job

```bash
<skill>/scripts/fetch_ci_log.sh <job URL>      # or: fetch_ci_log.sh <run-id> <job-id>
```

It prints the run, the failed step, the last results of the same job on `main`,
and the error lines, and saves the whole log to `~/lfortran_test/ci_<run>/`.
(`gh run view --log` prints nothing on this machine; the script uses
`gh api .../jobs/<id>/logs`.) Write down the exact message, the failing source
file and the compiler flags.

## 2. Find the commit that caused it

- The suspects are the commits between the last green run of the job and the
  red one: `git log --oneline <green-sha>..<red-sha>`. A merged PR that touches
  the failing feature is the first suspect.
- Tell the user early which PR it looks like. It may be their own.

## 3. Reproduce on this machine

- The recipe is in `ci/test_third_party_codes.sh`: the repository, the pinned
  commit and the exact `fpm` or `cmake` command with its flags. Use it as
  written. Clone into `/media/assem/nvme-9gb/tmp/<name>/`. `fpm` is in the conda
  env `lf` (`conda run -n lf fpm ...`).
- **The main build** `~/lfortran_test/lfortran/src/bin/lfortran` is upstream
  `main`, built by the batch-fix skill's `build_main.sh` (its commit is
  `git -C ~/lfortran_test/lfortran rev-parse HEAD`; `--version` can be stale).
  During a batch it is the batch's base; do not move it then.
- **Old compiler:** use the slot from a source worktree at the last green commit.
- **Red compiler:** the main build when it is at the red SHA. Otherwise add a source worktree at the red SHA
  (`git -C ~/lfortran_test/lfortran worktree add --detach /media/assem/nvme-9gb/lfortran-src-<name> <sha>`)
  and, from it, copy the slot's compiler out:
  `slot.sh bash <skill>/scripts/copy_slot_compiler.sh /media/assem/nvme-9gb/tmp/<name>/lf`.
  Then reduce with `/media/assem/nvme-9gb/tmp/<name>/lf/src/bin/lfortran` without
  holding the slot. The copy is about 470 MB; delete it when done.
- It is a regression when the red compiler fails with the same message and the
  old one passes.
- The `--version` text of a slot build can name an old commit, because the slot
  never reruns `build0.sh`. That is harmless; trust the worktree's HEAD.

## 4. Reduce to an MRE

- Follow the repository's `create-mre` skill. Check each step with gfortran, the
  red compiler and the old one.
- A failure while loading a `.mod` file needs two files compiled one by one with
  `-c`, so the second file loads the first file's `.mod`.
- Add the CI flags (`--separate-compilation`, `--realloc-lhs-arrays`, ...) only
  if the plain form does not fail.

## 5. Find the root cause, and whether it is older

- Read the suspect commit's diff for the code that makes the broken thing.
- Look for a variant of the MRE that does not use what the commit added. If it
  fails on the old compiler too, the commit only made an older bug common.
- Search issues for the error text and the construct:
  `gh issue list --repo lfortran/lfortran --state all --search "<words>"`.
  An open issue with the same cause is fixed by the same PR (`Fixes #N`).

## 6. Revert or fix: ask the user

Say in a few lines: the cause, how big a real fix is, and the option of
reverting the merge now so `main` is green again. The user decides.

## 7. The fix

Use the `lfortran-batch-fix` machinery for one job, done by you (no subagent):

```bash
<skills>/lfortran-batch-fix/scripts/prepare_build_worktree.sh     # slot and base to the latest main
<skills>/lfortran-batch-fix/scripts/baseline.sh                   # background, about 10 min
<skills>/lfortran-batch-fix/scripts/setup_issue.py <N> --slug <words>
```

Use the number of the issue it fixes; with none, ask the user what to use.
Then follow `machine.md` in the new state directory, with these points:

- A narrow fix often only moves the crash to the next place. After every
  attempt, build the **whole application** again with the fixed compiler, not
  only the MRE.
- When the fix lets an ASR field hold a new form (for example an
  `ExternalSymbol` where a `Function` was expected), list every reader of that
  field (`grep -rn -- "m_<field>\b" src`) and fix them all in a first commit
  that changes no behavior. `grep` here is `ugrep`, and `--include` does not
  filter: filter the output instead.
- Prefer existing helpers (`ASRUtils::import_symbol`,
  `symbol_get_past_external`, `insert_module_dependency`) to new ones.
- Commits: the refactor, then per bug the fix and a `test:` commit.
- Multi-file tests are integration tests:
  `RUN(NAME x LABELS gfortran llvm EXTRAFILES xa.f90)`. CMake compiles each file
  on its own, so `.mod` loading is tested. Check names with `check_test_names.sh`.
- Checks: the new tests in default, `-f`, `--std=f23`, `-sc` and `-b gfortran`
  modes; the application's own command (for FIATS `fpm test` with the CI
  flags); then the unit, integration and reference suites once. Put them all in
  one script and one `slot.sh` call, in the background.
- Review the branch with `pr-review` before publishing. Bugs found on the way
  that the fix does not need are filed upstream (the batch-fix side-bug rules)
  and listed in the PR under `## Other bugs found`.

## 8. Publish

- `publish_pr.sh <N> --title "fix: ..."`. If it pushes but `gh pr create` fails
  with "error opening '/media/.../.git': Permission denied" (`gh` is a snap),
  open the PR from the home checkout:
  `cd ~/lfortran_test/lfortran && gh pr create --repo lfortran/lfortran --draft --base main --head <your GitHub login>:<branch> --title "..." --body-file - < <body copied to ~/lfortran_test/...>`.
- The PR body uses the user's form (`Fixes #N`, The issue, Why it happened,
  The fix, Tests). Right after `Fixes`, one line links the CI run and names the
  PR that caused it. A fix to an ASR pass shows, in The fix, that pass's
  Fortran for the MRE before and after (the batch-fix `machine.md` rule
  "Pass fixes").
- Size rule (the user, 2026-10-25): a PR that fixes CI is marked ready for
  review and put on auto-merge if and only if it changes at most 20 lines
  (additions + deletions over all files, as GitHub counts them). Otherwise it
  stays a draft for the user. Run
  `<skill>/scripts/ready_if_small.sh <PR>` right after the PR is created and
  again after every later push to it. It marks a small draft ready and turns on
  auto-merge (merge commit). If a later push makes the PR bigger than 20 lines,
  it turns auto-merge off and makes the PR a draft again; tell the user. Only
  push after the checks of step 7 pass, since a small PR can merge by itself.
- This is separate from the `low risk` label: no label, no line in
  `low_risk_prs.txt`. Still run the `lfortran-low-risk-pr` check (the hook asks
  for it); a CI fix usually fits none of its kinds, which changes nothing here.
- Do not watch CI.
- Clean up: `cleanup_issue.sh <N>` (copy the MRE files into the state directory
  first), the compiler copy, the scratch worktree of the red commit, and the
  build directory of the application clone. Add a line to
  `~/lfortran_test/.batch-fix/registry.md`.

## Pitfalls seen

- `rm -rf` after `cd` with a glob is blocked. Remove explicit paths.
- `gh` is a snap: it cannot read files under `/tmp`, `/media` or hidden folders
  in home. Pass files on stdin, or copy them to `~/lfortran_test/...`.
- `integration_tests -t` does not take `|`; run one pattern per call.
- Keep the slot free for others: put related commands in one `slot.sh` call.
