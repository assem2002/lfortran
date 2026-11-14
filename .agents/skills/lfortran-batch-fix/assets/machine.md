# Machine rules for issue #__ISSUE__

Read this whole file before anything else. You are the ONE agent for LFortran issue #__ISSUE__ ("__TITLE__"), from reproduction to an open draft PR. The workflow is the repository's own: `.agents/skills/fix-issue/SKILL.md` in your worktree, with the `repro-issue`, `create-mre`, `fix-mre` and `pr-review` skills it names, and `AGENTS.md` for the project rules. Follow them as written up to and including Phase 4. This file changes what this machine's RAM (13 GB, no swap) and disk (a few GB free) force, plus two choices the user made; where it conflicts with those files, this file wins.

## Your job's facts
- Worktree: `__SRC__`. It holds sources only, no build. Do all reading, editing and committing there.
- Branch: `__BRANCH__`, created at upstream `main` `__BASE__`.
- State directory: `__SRC__/.fix-issue/__ISSUE__/` (gitignored). Keep `state.md` there current, and write the artifacts `fix-issue` lists (`repro.md`, `mre_<j>.md`, `fix_<j>.md`, `check_<j>.md`, `suites.md`, `pr_body.md`, `review_<k>.md`, `round_<k>.md`, `followups.md`) there too.
- Reproducers (`run_re.sh`, `re_*.f90`, `run.sh`, `mre_*.f90`) go in the worktree root, as the skills say. They are gitignored. __REPRO__
- Upstream remote: `origin` (lfortran/lfortran); never push to it. Fork remote: `myrepo` (assem2002/lfortran).
- Commit identity: `__IDENT__`. Use it as configured; never change git config.
- GitHub access: the `gh` CLI, already logged in.

## One agent, and the job ends at the draft PR (the user's choices)
`fix-issue` spawns a fresh subagent for every phase, then watches CI and reviews in a loop until the PR is ready. Here:
- You do every phase yourself, in one run, in order. Never spawn subagents.
- The job ends when the draft PR is open. Do not watch or wait for CI, do not run the Phase 5 loop, and do not mark the PR ready. The user does that.

Because nobody else checks your work before it is public, do these two checks as if you had not written the fix, BEFORE publishing:
- the original-issue check (Phase 3c): reread the issue text and comments, and test every program and scenario it mentions, not only your MRE;
- one review: load the `pr-review` skill and review your whole branch against it. Write real findings to `review_1.md`, classed blocker, rework or follow-up, and fix the blockers and rework items. The user wants minimal tests: one case per code path the fix changes. Rerun the suites once if the fixes touched `src/` or `grammar/`.

Stop and report WITHOUT publishing if:
- your fix shares a root cause with, or needs the fix of, another issue being fixed in this batch;
- a blocker survives your review, for example a case that your fix turns from a compile error into a silently wrong result;
- the bug does not reproduce on the base, or gfortran rejects the code.

If the issue already works on the base (every program and scenario in the issue and its comments gives what the issue asks for: gfortran's result for valid code, a proper error for invalid code), start your report with the line `WORKS IN MAIN`, then each program with its exact command (the main build or `slot.sh`), the LFortran output, the gfortran output and the base SHA. The coordinator then labels the issue `works in main`; do not label, comment on or close it yourself, and do not add a test, commit or open a PR for it.

## The build slot replaces Pixi
This machine has no Pixi and room for one LFortran build. That one build is the shared slot `__BUILD__` (Debug, LLVM 11.1.0), which every job on the machine takes in turn.

Wherever the skills or `AGENTS.md` say `pixi run -e llvm11 <something>`, run this from inside your worktree instead:

    __SCRIPTS__/slot.sh <something>

| The repository says | Here |
|---|---|
| `pixi run -e llvm11 build` (with any flags), `rebuild` | `slot.sh build` |
| `pixi run -e llvm11 start <args>` | `slot.sh start <args>` |
| `pixi run -e llvm11 bash run.sh` | `slot.sh bash run.sh` |
| `pixi run -e llvm11 tests <args>` | `slot.sh tests <args>` |
| `pixi run -e llvm11 integration_tests <args>` | `slot.sh integration_tests <args>` |
| `pixi run -e llvm11 ctest <args>` | `slot.sh ctest <args>` |
| `pixi run -e llvm11 gfortran ...` | plain `gfortran ...` (the system one; no slot needed) |
| `pixi run -e llvm11 clean` | never; the slot is shared |

What a `slot.sh` call does:
1. It waits in a first-come-first-served queue. `__SCRIPTS__/slot_status.sh` shows who is building or testing and your place in line.
2. It makes the slot match your worktree: your HEAD plus your uncommitted changes and new untracked files.
3. It rebuilds with `ninja -j8`. Exit code 4 means the build failed; the log is `__STATE__/slot_ninja_<your worktree's name>.log`.
4. It runs your command with the fresh compiler first on `PATH` and `LFORTRAN_BUILD_DIR` set, as Pixi activation would. Test tasks run from your worktree, so `tests -u` updates the reference files in your worktree.

Rules that follow from sharing one slot:
- The next caller replaces the build, so everything that needs YOUR compiler must happen inside a slot call. Outside one, a bare `lfortran` is the main build (below), not yours.
- A call can wait many minutes. Put related commands in one call (`slot.sh bash -c '...'` or a script); inside a slot call, further `slot.sh ...` commands run at once. Keep reading and editing while you wait. Do not cancel a waiting call and call again; that sends you to the back.
- For any call that may take more than about 9 minutes, including its wait, use `run_in_background: true` and wait for it to finish. Never call `slot.sh` in a tight loop.
- Never run `ninja`, `cmake`, `ctest` or a `run_tests.py` yourself, never build in your worktree, and never touch `__BUILD__` directly.
- Threads are capped at 8 for you; a larger `-j` is reduced.
- **The main build** `__MAIN__/src/bin/lfortran` is upstream `main` at your base `__BASE__`, built in the user's checkout. Use it by explicit path, with no wait, as the base to test against: reproducing the issue, fail-before evidence, "does this also fail on main?" and `WORKS IN MAIN` checks. First check that `git -C __MAIN__ rev-parse --short=10 HEAD` prints `__BASE__`; if it does not, say so in your report and use a slot call made before you write the fix instead. Never edit, build or run suites in `__MAIN__`. Generated headers such as `src/libasr/asr.h` and `src/lfortran/ast.h` are not in your worktree; read them from `__MAIN__/src/...`.
- To read the ASR, use the `lfortran-asr-query` skill's `asrq` (`/home/assem/.claude/skills/lfortran-asr-query/scripts/asrq`) instead of dumping whole `--show-asr` trees: `slot.sh <asrq> line 12 mre.f90` for your build, or `LFORTRAN=__MAIN__/src/bin/lfortran <asrq> ...` for the main build.
- Disk is limited. Your worktree and the slot are on the `nvme-9gb` partition (8.5 GB, shared by the whole batch). Create no large files, and delete binaries and `.mod` files your checks leave behind.
- `gh` is a snap and cannot open files under `/media`, where your worktree is. Pass a file to it on stdin: `--body-file - < file`.

## What else differs from `fix-issue`
- **Setup (Phase 1) is done.** The worktree, branch and slot exist; do not create a build.
- **Fail-before evidence** comes from the main build `__MAIN__/src/bin/lfortran` (your base), or from a slot call made before you write the fix, not from a separate build.
- **Baseline.** The suites were run on clean `__BASE__`: `__STATE__/baseline___BASE___{unit,integration,reference}.log` (an older batch may have `_{llvm,ref}.log` instead). A test that fails for you but passes there is your regression. To run a program on upstream `main`, use the main build. For anything else on `main` (suites, another commit), ask the coordinator in your report; do not build `main` yourself.
- **Test names.** Before choosing an integration test name, run `__SCRIPTS__/check_test_names.sh <name> ...`. A name is free only if it is unused on `main`, in other local `fix/*` branches and in other people's open PRs. Module and program names inside the test carry the same unique prefix.
- **Tests go in their own commit** (the user's rule, 2026-10-18). For each distinct bug, make two commits in this order: first the fix (source changes, plus any existing reference outputs the fix changes, so the fix commit passes the suites on its own), then a `test:` commit with the new tests only (the test file, its `RUN(...)` line in `integration_tests/CMakeLists.txt`, and any new `tests/tests.toml` entry with its new reference files). With several bugs in one PR: fix A, tests A, fix B, tests B. This replaces "the fix and its test in one commit" in `fix-mre`, `AGENTS.md` and the user's global instructions.
- **Publishing (Phase 4)** is one command, and your last step: `__SCRIPTS__/publish_pr.sh __ISSUE__ --title "fix: ..."` (the branch always has at least two commits, so the title is needed). It rechecks authorship, the push invariant and test names, pushes to `myrepo`, and opens the draft PR from `pr_body.md`; if it refuses, fix what it names. You are authorized to push to `myrepo` and open that draft PR; nothing else leaves the machine. If you are resumed later for more work on the PR: `__SCRIPTS__/publish_pr.sh __ISSUE__ --push-only`, or after a rebase `git push --force-with-lease myrepo __BRANCH__`.
- **Unrelated bugs** you meet are always reported upstream, so never drop one. Put each in `followups.md` and at the end of every report, with a standalone reproducer saved in the state directory, the exact command and output, and the gfortran result. The coordinator files them after removing duplicates across all jobs; do not file them yourself.
- **Comments in code:** the user keeps them to one line or none. Put the reasoning in the commit message.
- **Plain English in everything a person reads:** code comments, commit messages, `pr_body.md` and drafted replies. Use short, common words and short, direct sentences that say what happens and where. No fancy words, no figures of speech, no clever phrasing. If a simpler word says the same thing, use it. Read the PR body once more for this before publishing.

## The PR description (the user's form)
`fix-issue` Phase 4 asks for the headings Summary, Scope, Verification and Rationale. Do not use them. The user wants `pr_body.md` to explain the issue simply and then explain the fix simply, so that someone who has not read the issue follows it in about a minute. Just before you write it, read the example `/home/assem/.claude/skills/lfortran-batch-fix/assets/pr_body_example.md` and write yours the same way:

- `Fixes #<N>` on the first line, one line per issue the PR fixes.
- `## The issue`: the few lines of Fortran that show the bug (not the whole test), what LFortran did with them (the real error text or the wrong result, shortened), and what is right (what gfortran does).
- `## Why it happened`: two or three sentences that name the function and say what it did wrong.
- `## The fix`: what the code does now and in which file. Add a small before/after table only when the fix changes more than one case. If a related case stays broken, end with one line `Not covered: ...`.
- Pass fixes (the user's rule, 2026-11-10): if the fix changes an ASR pass (`src/libasr/pass/`), `## The fix` shows the Fortran that pass now gives for the MRE, before and after, as two short code blocks (`Before (main):` and `After:`) with only the lines that changed and a line or two around them. Get it with `--dump-all-passes-fortran`, which writes `pass_fortran_<NN>_<pass>.f90` per pass into the current directory. Run each compiler in its own empty directory: the main build in `__STATE__/pass_main/` (`cd` there, then `__MAIN__/src/bin/lfortran --dump-all-passes-fortran <mre>.f90`), and yours inside a slot call in `__STATE__/pass_fix/` (`slot.sh bash -c 'cd __STATE__/pass_fix && lfortran --dump-all-passes-fortran <mre>.f90'`). Then `diff` the two files of the pass you changed. If the dump hides the change (it is the same text), show the `--show-asr` lines of that pass instead (`asrq -p <pass> line N`). For a fix in semantics, do the same with `--show-fortran` when the generated code is the point of the fix.
- New functions (the user's rule, 2026-10-21): if your branch adds a function or method, end `## The fix` with `New functions:` and one line per function: its name and file, what it takes, what it returns (also when it finds nothing), what else it changes (symbols it adds, nodes it edits), and who calls it. Keep each line short. For example:
  - `resolve_and_copy_type_bound_proc(clss, name)` (`ast_symboltable_visitor.cpp`): returns the binding `name` of type `clss` or of a parent type, or null if there is none. An inherited binding is first copied into `clss`. Called by `add_generic_class_procedures` and `inherit_generic_class_procedures`.
- `## Tests`: one line per new or changed test, with its name and what it checks; say that it fails on `main` and passes here. Then one line with the local suite results.
- `## Other bugs found`: only when the coordinator has sent you issue numbers for unrelated bugs; one line per bug with its link.

Leave out commit SHAs, rebase and review history, lists of commands, the modes you ran, and ideas for later work (those go in your report). Aim for 150 to 300 words, not counting code.

Tell the story so a reader understands it in one pass, without asking questions:
- If the fix depends on a Fortran rule (for example, a sequential WRITE makes its record the last one), state the rule in one sentence in `## The issue`.
- No pointers like "see below" or "see the last row of the table". Say the thing where it is needed.

With several bugs in one PR:
- If they are independent bugs from the issue, write the first three sections once per bug, with the bug's short name in each heading (`## The issue: <name>`), and keep one Tests section.
- If one bug had to be fixed only so the main fix would not break something, start with the bug the issue reports, not with commit order. After its `## The fix`, add `## Why <other bug> is fixed here too`: show the few lines of code that would break with the main fix alone, say how the other bug was broken and how the old code hid it, then what its fix does.

## Reports
End every turn with a report of at most about 20 lines: what you did, the commit SHAs, each function you added with one line on how it works (as in the PR description), test results with log paths, what is outstanding, and an **Unrelated bugs** list (or `none`). Longer material goes in files under the state directory; give the path.
