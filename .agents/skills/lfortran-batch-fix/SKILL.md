---
name: lfortran-batch-fix
description: Run the LFortran repository's `fix-issue` workflow on this machine (assem's 13 GB RAM, nearly-full NVMe laptop), for one issue or several at once, without running out of RAM or disk. It follows `fix-issue` from reproduction to an open draft PR from the fork and stops there: no CI watching, no review-and-fix loop, no marking ready. It changes what the machine forces - one shared build slot with a first-come-first-served queue instead of a Pixi build per worktree, source-only worktrees, 8 build threads and 8 test threads - plus the user's choices of one agent per issue and of stopping at the draft PR. Use this whenever the user asks to fix LFortran issues, "go for the next N" or "another 4", run fixer agents in parallel or in worktrees, queue builds, see who is building, resume or finish a batch, or push fix branches and open their PRs. Use it instead of the repository's `fix-issue` skill on this machine, even if the user names that skill or doesn't mention worktrees or builds.
---

# LFortran issue fixing on this machine

The workflow of record is the repository's own: `.agents/skills/fix-issue/SKILL.md` and its `references/batch.md` (read them from `origin/main`, or from an issue's worktree, so they are current). **Follow them as written.** This skill is only the layer that makes them fit this machine. It lists every difference and the reason for it; anything not listed here is done the `fix-issue` way, including what a fixing request authorizes: commits, pushes to the fork, draft PRs against `lfortran/lfortran`, and filing new unrelated bugs.

The user set this up on 2026-10-12: "align everything in my skill but just respect my machine's capabilities (ram and storage)", then "I want single agent per issue", and on 2026-10-13: "just push the fix branch and create a PR, and then that's it don't watch it".

## What differs from `fix-issue`, and why

| `fix-issue` says | Here | Reason |
|---|---|---|
| A Pixi `llvm11` build in every issue's worktree | ONE built worktree, the build slot, shared by all jobs; each issue gets a source-only worktree (about 85 MB) | Disk: a build is about 4.7 GB, on an 8.5 GB partition |
| One build or test process per worktree, jobs in parallel | One build or test process on the whole machine, taken in turn through a queue | RAM: 13 GB, no swap; two builds at once ran out of memory |
| `pixi run -e llvm11 <x>` | `scripts/slot.sh <x>`, run from the issue's worktree | No Pixi here: it would add a second copy of a toolchain the conda env `lf` already has (LLVM 11.1.0, about 1.6 GB) |
| Build flags `-g -O2` | Plain Debug, in-tree, from `./build0.sh` and `./build1.sh` | `-O2` at 12 jobs is untested against the RAM limit. Try it between batches, not during one |
| Job budget chosen per worker | At most 8 threads for builds (`ninja -j8`) and 8 for test suites (pinned to 8 cores) | The user's limit for this laptop; builds were 12 from 2026-10-19 and back to 8 on 2026-10-21 |
| Each job builds `main` first and compares against it | One build of the pinned base in the user's checkout `~/lfortran_test/lfortran` (`build_main.sh`), which every job runs directly for single programs, plus one baseline run of the suites per batch in the slot | The user's choice (2026-10-25). The checkout already holds a build, so updating it costs little disk; a second full build does not fit |
| Building `main` in a separate worktree to confirm an unrelated bug | The main build `~/lfortran_test/lfortran/src/bin/lfortran`, by explicit path, no queue | Same |
| A fresh subagent per phase, and a worker that spawns them | One agent per issue does every phase, from reproduction to the open PR | The user's choice, to keep context. It is not a machine limit |
| Phase 5: watch Quick CI, review rounds with `pr-review`, fix loop. Phase 6: mark the PR ready | The job ends when the draft PR is open. Nobody watches CI, and the PR is left as a draft for the user | The user's choice |
| At most four of a batch's PRs in Quick checks at once; verified branches wait to publish | No limit: all agents start at once and publish when ready | The user's choice (2026-10-20) |
| Review by a fresh agent after publishing, while CI runs | One self-review with `pr-review` BEFORE publishing, by the issue's own agent, so the first push is the reviewed one | Follows from the two choices above |
| A PR body with the headings Summary, Scope, Verification, Rationale | The user's form: `Fixes #N`, then The issue, Why it happened, The fix, Tests (see User preferences) | The user's choice |
| Worktrees under `.fix-issue/<batch>/worktrees/` in the invoking checkout | `/media/assem/nvme-9gb/lfortran-src-<N>` | Keeps the user's checkout untouched, and `/` free |
| Worktrees kept after the PR is ready | Removed with `cleanup_issue.sh` at the end of the batch, once the PR is open; the branch, the fork and the saved state remain | Disk |

Two things this skill adds:
- **Test-name check.** Agents number new tests from `main`, so parallel branches and other people's PRs collide (`intrinsics_482` and `operator_overloading_41` did). `check_test_names.sh` checks `main`, other local `fix/*` branches and open upstream PRs; `publish_pr.sh` refuses a taken name.
- **Disk check.** Look at `df -h /media/assem/nvme-9gb /` before starting and when an agent reports odd I/O errors.

Never use the NTFS HDD at `/mnt/AEDE4577DE4538BB` for anything here: writes fell under 1 MB/s and stalled everything for half an hour.

**All builds and worktrees are on the `nvme-9gb` partition** (since 2026-10-20; the user asked for every build to go there from now on). It is `/dev/nvme0n1p6`, ext4, 8.5 GB, mounted at `/media/assem/nvme-9gb` by the desktop automounter (no `/etc/fstab` entry). The scripts stop if it is not mounted; never fall back to `/` or the HDD. The slot is about 4.7 GB, a libasr rebuild needs about 1.2 GB more while `ranlib` rewrites the archive, the suite build directories about 0.8 GB, and each source worktree about 90 MB, so keep at least 1.5 GB free there. gcc's temporary files go to its `tmp/` folder, not `/tmp`. `gh` is a snap without the `removable-media` interface, so it cannot open files there: pass files on stdin (`--body-file - < file`).

The one build on `/` is the main build in `~/lfortran_test/lfortran` (the user's choice, 2026-10-25). `/` is nearly full: relinking `libasr.a` (1.5 GB in October 2026) deletes it, writes it again and `ranlib` writes a full temporary copy, so a rebuild needs one archive size more. `build_main.sh` refuses when `/` has less than that plus 300 MB free; then tell the user. Its gcc temporaries go to the nvme `tmp/` folder. Never run suites or other builds in that checkout: their build directories would fill `/`.

## Layout

| Path | What |
|---|---|
| `~/lfortran_test/lfortran` | The main build: the user's checkout, kept detached at the pinned base and built in-tree by `build_main.sh` (the user's choice, 2026-10-25). Its `src/bin/lfortran` is the base compiler to test against: "does it fail on main?", fail-before evidence, `works in main` checks, side-bug confirmation. Run it by explicit path; it needs no queue. It is also the bare `lfortran` on `PATH`, which is why jobs must go through the slot for their own build. Never edit its sources; only `build_main.sh` moves or builds it, and it refuses while tracked files have uncommitted changes. Git metadata (branches, worktrees) is shared as before. |
| `/media/assem/nvme-9gb/lfortran-fixes` | The build slot: the ONE built worktree, detached. Only `build_slot.sh` and `prepare_build_worktree.sh` touch it. Suite build directories live in its `build/slot/`. |
| `/media/assem/nvme-9gb/lfortran-src-base` | Source-only worktree at the pinned base, for the baseline and "does it fail on main?" checks. |
| `/media/assem/nvme-9gb/lfortran-src-<N>` | Source-only worktree of issue N, on branch `fix/<N>-<slug>`. Its `.fix-issue/<N>/` holds `machine.md`, `state.md` and the artifacts `fix-issue` names. |
| `~/lfortran_test/.batch-fix/` | Batch state: `base_sha`, `build.lock`, the `build_slot.open` marker, the queue (`queue/`, `slot_current`, `slot_history.log`), baseline logs, `registry.md`, `followups.md`, `done/<N>/`. |
| `~/lfortran_test/Claude_creates_lists_for_me/lfortran-fixable-issues.md` | Candidate list. Reproducers from scouting are in `~/lfortran_test/lfortran-fixable-issues/<N>/`. |

Scripts are in this skill's `scripts/` folder (`<skill>/scripts/...` below). The machine's paths (state directory, nvme partition, main checkout, fork remote, conda env, job counts) are set in one place, `scripts/_lib.sh`; each can be changed with the `BATCH_FIX_*` variable named there.

## The build slot and its queue

`slot.sh` is the stand-in for `pixi run -e llvm11`: `slot.sh build`, `slot.sh start <args>`, `slot.sh bash run.sh`, `slot.sh tests <args>`, `slot.sh integration_tests <args>`, `slot.sh ctest <args>`. Each call:
1. takes a ticket and waits its turn, first come, first served;
2. makes the slot match the calling worktree (HEAD, uncommitted changes, new untracked files) and runs `ninja -j8`;
3. runs the command with that compiler first on `PATH` and `LFORTRAN_BUILD_DIR` set, as Pixi activation does. Suites run from the calling worktree, so `tests -u` updates references there.

`slot_status.sh` prints who is building or testing now, who waits and in which order, and recent events. Run it whenever the user asks who is building, and tell them they can watch it with `watch -n 5 <skill>/scripts/slot_status.sh`. When jobs wait a long time, say so and say why; the usual cause is one job's full suites, which hold the slot for about 6 minutes.

The slot serves calls only while `~/lfortran_test/.batch-fix/build_slot.open` exists. Remove that file when a batch is over.

## Workflow

You are the batch coordinator of `references/batch.md`. Keep your own context small: agents read code, diffs and logs; you read their short reports.

### 0. Preflight and selection
- Do `fix-issue` Phase 0 and the selection steps of `batch.md`: `gh auth status`, remotes (`origin` is upstream and is never pushed to; `myrepo` is the fork, assem2002/lfortran), `git var GIT_AUTHOR_IDENT`, the complete frozen selection, and each issue's state and existing PRs.
- When the user asks for picks rather than naming issues, take them from the candidate list and skip `lfortran-human-steered-issues.md`.
- `df -h /media/assem/nvme-9gb`: about 1.5 GB free is enough when the slot exists; creating it needs about 5 GB. If there is not enough, or the partition is not mounted, tell the user; do not fall back to `/` or the HDD.

### 1. Setup (replaces Phase 1's per-job build)
```bash
<skill>/scripts/prepare_build_worktree.sh        # slot to latest upstream main, pins base_sha
<skill>/scripts/build_main.sh $(cat ~/lfortran_test/.batch-fix/base_sha)   # main build at the same base; queues
touch ~/lfortran_test/.batch-fix/build_slot.open
<skill>/scripts/baseline.sh                      # background; queues like any job, ~6 min in the slot
<skill>/scripts/setup_issue.py <N> --slug <two-to-four-words>     # once per issue
```
If the slot worktree was deleted by hand, run `git -C ~/lfortran_test/lfortran worktree prune` first. If `build_main.sh` stops because the checkout has uncommitted changes, ask the user what to do with them; never stash, reset or commit them yourself. If it stops for disk, tell the user; the agents then use a slot call from `lfortran-src-base` for base checks, as before. Start `registry.md` with one row per selected issue, as `batch.md` describes.

### 2. One agent per issue (Phases 2–4)
Launch one background `general-purpose` agent per issue, all in one message, with prompt 1 of `assets/prompts.md`. Agents start at once; they diagnose with the main build while the baseline holds the slot. Tell the user which agent has which issue. Do not poll agents; "stopped with background work still running" notices are interim.

Each agent reads its `machine.md`, then does everything for its issue in one run: reproduce, reduce, fix, check the original issue, run the suites once, commit, review its own branch once with `pr-review` and fix what that finds, write `pr_body.md`, and publish with `publish_pr.sh`, which pushes the branch to the fork and opens the draft PR. Then it reports and stops. It does not watch CI.

An agent stops BEFORE publishing and reports instead when its fix shares a root cause with, or depends on, another issue of the batch, or when its own review leaves a blocker it cannot resolve, such as a case the fix turns from a compile error into a silently wrong result.

Start every selected issue's agent at once. Do not hold issues back in waves for CI capacity: the user asked on 2026-10-20 that the number of agents not be limited by the repository's rule of at most four of a batch's PRs in Quick checks at once ("I don't care about the CI"). The only limits are this machine's: agents queue for the one slot, so tell the user how long waits may get, and check `df -h /media/assem/nvme-9gb` before adding worktrees.

### 3. Grouping (coordinator, only when an agent stopped for it)
- Compare the reports as `batch.md` says: independent fixes get separate PRs; shared or dependent fixes become one PR with ordered, focused commits. Similar errors or edits to the same file are not a dependency.
- Resume the owning agent with the decision; it integrates the commits, reruns the checks and publishes.
- `<skill>/scripts/verify_branch.sh <N>` prints a branch's author, authorship check, `Fixes #N`, test names and push invariant in a few lines, when you want to check one yourself. `publish_pr.sh` enforces the same things.

### Issues that already work on `main`: label them "works in main"
The user asked on 2026-10-21: "any issue that actually works in main should be labeled 'works in main'". The label exists in `lfortran/lfortran` ("This issue describes a code that actually works in main now. Add a test and close it.").
- **When:** an agent stops because its issue does not reproduce on the pinned base, or you see it yourself, for example while picking issues. "Works" means `main` now does what the issue asks for: valid code compiles and gives the same result as gfortran; for invalid code, LFortran gives a proper error, not the crash or silent acceptance the issue reports. Every program and scenario in the issue and its comments must work, not only the first one.
- **Check it on the pinned base**, which is the latest upstream `main`: with the main build, `~/lfortran_test/lfortran/src/bin/lfortran`, after checking that `git -C ~/lfortran_test/lfortran rev-parse HEAD` is the `base_sha`. If it is not, rerun `build_main.sh <base_sha>`, or use `slot.sh` from `lfortran-src-base`. If gfortran rejects code that the issue calls valid, or it is unclear what the issue expects, do not label; tell the user.
- **Label:** `gh issue edit <N> --repo lfortran/lfortran --add-label "works in main"`. Keep the issue's other labels; do not comment on it or close it.
- **Nothing more:** no test, no branch, no PR for such an issue (the user, 2026-10-21: "just add the label and don't add the test or open a PR for such issue"), even though the label's description says "Add a test and close it". Remove its worktree with `cleanup_issue.sh` if one was made.
- In the final table, the issue's row says `works in main (labeled)` and the base SHA it was checked on.

### Side bugs: always filed upstream
Every LFortran bug an agent meets that its own issue does not need ends up as an upstream issue: a failure that also happens on `main`, something seen while reducing, reviewing or reading CI logs. This is `fix-issue`'s follow-up procedure, and the user asked on 2026-10-12 that it never be skipped. Start on it as soon as an agent's report arrives; do not leave it for the end of the batch.

1. Agents list such bugs at the end of every report and in their `followups.md`, each with a standalone reproducer saved in their state directory.
2. Copy each into the batch ledger `~/lfortran_test/.batch-fix/followups.md` as `unfiled`, merging a bug that two jobs reported.
3. Take the `unfiled` entries one at a time:
   - Confirm it on the pinned base, with the gfortran result alongside: run `~/lfortran_test/lfortran/src/bin/lfortran` directly (its HEAD is the `base_sha`; if not, `cd /media/assem/nvme-9gb/lfortran-src-base && <skill>/scripts/slot.sh bash -c '...'`). If it passes on the base, the branch caused it: mark it `regression` and send it back to that issue's agent.
   - Search open and closed issues (`gh issue list --repo lfortran/lfortran --state all --search "<keywords>"`), read the likely matches, and recheck just before filing. An existing report becomes `duplicate of #M`; do not comment on it.
   - Otherwise file it: `gh issue create --repo lfortran/lfortran --title "<bug>" --body-file <file>`. The body has a minimal self-contained reproducer, the exact LFortran command and output, the gfortran result, the base SHA it fails on, and links to the originating issue and PR. Mark it `filed #M`.
4. Tell the originating agent to add every filed or duplicate issue under `## Other bugs found` at the end of its PR body.

File even when the job that found the bug is blocked or produced no PR. Only bugs are filed: ideas, refactorings and performance notes go in the final report, not in the PR body. If a search or filing call fails, mark the entry `blocked: <error>`, keep the ready-to-file title and body, and tell the user at once. A batch is not finished while any entry is still `unfiled`.

### 4. After the PRs are open
- Low-risk check: for every PR that is opened or pushed (an agent's, or one you make yourself), load the `lfortran-low-risk-pr` skill, read the PR's diff and judge it yourself; if it fits a low-risk kind, run its `mark_low_risk.sh <PR> <kind> "<reason>"`. A low-risk PR is marked ready, labelled `low risk` and set to auto-merge; that is the one exception to leaving PRs as drafts (asked by the user on 2026-10-20). A hook reminds you after `gh pr create`, `publish_pr.sh` and `git push`.
- Link side bugs: once the entries a job reported are filed or matched to existing issues, resume that agent with prompt 2 so the PR description lists them. That is a description edit only.
- Do NOT watch Quick checks, run review rounds, push follow-up fixes or mark the PR ready (low-risk PRs aside, see above). The user looks at CI and marks PRs ready. If the user later asks for changes on a PR (a CI failure, a review comment, a rebase), resume the issue's agent with prompt 3; branches are updated by rebasing onto upstream `main` and `git push --force-with-lease`, never by merging `main`.

### 5. Finish
- Check the ledger: no side bug may still be `unfiled`.
- Remove the issues from the candidate list.
- Report one table covering every selected issue exactly once: issue, PR (draft), branch, what the fix was, and anything the agent's review left open. Add the issues filed and the duplicates linked.
- Close the slot: `rm ~/lfortran_test/.batch-fix/build_slot.open`.
- Free the disk: `<skill>/scripts/cleanup_issue.sh <N>` for each issue whose PR is open. It keeps the branch and the fork and saves the state directory to `.batch-fix/done/<N>/`. To work on a PR again later, add a worktree for its branch (`git -C ~/lfortran_test/lfortran worktree add /media/assem/nvme-9gb/lfortran-src-<N> <branch>`) and copy the saved state back.

## User preferences

- **No `Co-Authored-By` or AI attribution** in commits or PR bodies. Tell every agent.
- **"My repo"** = the remote `myrepo`. Never push to `origin`.
- **Tests should be minimal:** one case per changed code path. The user had a 110-line test cut down to 29 lines.
- **Tests in their own commit** (asked on 2026-10-18: "add the tests in any PR that we're going to create in the future in a separate commit"): per bug, the fix commit first (with any existing reference outputs it changes), then a `test:` commit with the new tests and their registration. So every PR has at least two commits and `publish_pr.sh` needs `--title`. `assets/machine.md` tells every agent; check it with `verify_branch.sh` before an agent publishes.
- **Terse code comments:** one line or none; the reasoning goes in the commit message.
- **Plain English in everything people read** (asked on 2026-10-13: "simple english -- no fancy words or cool expression forming"): code comments, commit messages, PR descriptions, drafted replies and issue bodies you file. Short, common words and short, direct sentences; no figures of speech or clever phrasing. `assets/machine.md` tells every agent; hold your own side-bug reports to the same rule, and send back a `pr_body.md` that does not follow it.
- **The PR description explains the issue, then the fix** (asked on 2026-10-13: "simple explanation of the issue, and simple explanation of the fix"). It does not use `fix-issue`'s Summary, Scope, Verification, Rationale headings. The form is `Fixes #N`, then `## The issue` (a few lines of code, what LFortran did, what is right), `## Why it happened` (the function and what it did wrong), `## The fix` (what the code does now and where) and `## Tests` (each test and what it checks, fails on `main` and passes here, one line of suite results). `## Other bugs found` is added only when side bugs are linked. When the branch adds a function or method, `## The fix` ends with `New functions:`, one short line each: name and file, what it takes and returns (also when it finds nothing), what else it changes, and who calls it (asked on 2026-10-21: "mention the working characteristics of any function the agent has added, and mention that in the PR comment in a brief way"); agents also list them in their reports. When the fix changes an ASR pass, `## The fix` shows the Fortran that pass gives for the MRE before (main) and after, from `--dump-all-passes-fortran`, only the changed lines (asked on 2026-11-10 about #15716: "it's fixing a pass, I'd like to see the change of the ASR output (preferably the fortran output after the pass) in the `THE FIX` section"). About 150 to 300 words without the code; no SHAs, rebase or review history, or command lists. The rules are in `assets/machine.md` and a full example is `assets/pr_body_example.md`; use the same form for any PR body you write or edit yourself.
- **Keep the user informed:** say what is running and why something waits. The user asked "why are they stalling?" once.
- **Stop helper loops when asked.** Stop every monitor and watcher you started.
- **Labels and CI cancelling only on request.** `fix-issue` forbids labelling PRs on its own; when the user asks, add `bug` plus area labels by the `classify-issue` rules, never priority labels. `cancel_pr_runs.sh <PR>...` cancels a PR's runs when the user asks. One standing exception: an issue that already works on `main` always gets the `works in main` label (see "Issues that already work on `main`").

## Gotchas

- **The main build's `--version`** can name an older commit when `build_main.sh` did not need to rerun `build0.sh`. Trust `git -C ~/lfortran_test/lfortran rev-parse HEAD`.
- **Old batches:** branches named `fix/issue-<N>` and scratch under `.batch-fix/r/<N>/` come from before the alignment. The scripts accept both branch forms.
- **clangd noise:** clangd errors that appear in the session for source-only worktrees (headers not found) are noise; ignore them.
- **Never edit a script in place while agents run.** A waiting `build_slot.sh` is still being read by bash. Write the new version beside it and `mv` it over.
- **`integration_tests -t`** doesn't shell-quote its pattern, so don't pass `|` in it; each call also reconfigures the whole CMake suite.
- **`gh` is a snap and cannot read `/tmp` or `/media`.** Give it a body file on stdin (`--body-file - < file`); a path under `/tmp` gives "no such file or directory", and one under `/media` (the worktrees) "permission denied".
- **An agent may finish but leave a suite wait running.** Its report is still valid if its worktree is clean.
- **Keeping the mapping current:** `slot.sh` mirrors the tasks in the repository's `pixi.toml` (`build`, `rebuild`, `start`, `tests`, `integration_tests`, `ctest`). If upstream changes a task, update `slot.sh` to match.
- **If Pixi is installed one day:** the slot can become a real `pixi run -e llvm11 build` in `lfortran-fixes`; only `build_slot.sh` and `slot.sh` would change.
