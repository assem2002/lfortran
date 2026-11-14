---
name: lfortran-low-risk-pr
description: Judge whether an LFortran PR is low risk by reading its diff yourself, and if it is, mark it ready for review, label it "low risk" and turn on auto-merge. Use it EVERY time a PR to lfortran/lfortran is created or pushed - by you or by any agent, through `gh pr create`, `publish_pr.sh`, or `git push` to a PR branch - and whenever the user asks which PRs are low risk or suggests a new kind of low-risk PR. Low-risk kinds today: a PR that just adds a test and its registration line, a fix that only registers something the compiler already supports in an existing table (plus its test), and a tiny one-function fix that turns a compile-time crash into working code without changing any program that already compiled (plus its test), and a fix that only lower-cases a Fortran name the compiler stored as written, like a sibling construct already does (plus its test), and a small fix that wraps an existing step in an `if` check the code base already uses widely for the same decision, such as a common LLVM-codegen type check (plus its test), and a fix that adds one missing case to a switch whose default asserts, built like its neighbour cases (plus its test). The list of kinds is meant to grow with the user's suggestions.
---

# Low-risk LFortran PRs

The user set this up on 2026-10-20, after the test-only PR #15670 (a new integration test for #15654, which main already fixed): "a PR like the one that you just pushed, the one that just has the test, that's considered to be a low risk PR that should be marked as ready to review and put on auto merge", and "you should label such PRs as low risk PRs in GitHub".

A low-risk PR does not wait for the user: it is marked ready for review, gets the `low risk` label and is set to auto-merge, so it merges by itself once CI passes. Every other PR follows the normal rules (a draft that the user marks ready).

**You judge, not a script.** The user: "I want you 'the model' to judge the diff". An earlier version matched line patterns with a script; the user rejected it as too rigid. Read the diff, understand what it does, and decide whether it fits a kind below.

## When to run it

Every time a PR to `lfortran/lfortran` is created or gets a new push. A `PostToolUse` hook, `hooks/low_risk_pr_reminder.py` in this skill's folder, reminds you after `gh pr create`, `publish_pr.sh` and `git push`. It is turned on in `~/.claude/settings.json` under `hooks.PostToolUse`, with matcher `Bash` and command `/usr/bin/python3 <skill>/hooks/low_risk_pr_reminder.py 2>/dev/null || true`. Run it for PRs that agents open too; in the batch-fix workflow the coordinator does it when an agent reports its PR.

## How to judge a PR

1. Read the PR and its whole diff:
   ```bash
   gh pr view <PR> --repo lfortran/lfortran --json title,body,files,labels,isDraft,state
   gh pr diff <PR> --repo lfortran/lfortran
   ```
2. If it changes compiler code, read that code on upstream `main` around the change: what uses the changed table, and whether the new case really goes through code that already works for its neighbors.
3. Decide: do ALL the changes fit ONE kind below? When in doubt, it is not low risk.
4. Act:
   - **Low risk:** `<skill>/scripts/mark_low_risk.sh <PR> <kind> "<one-line reason>"` (`<skill>` is this skill's folder). It adds the label, writes the PR to the register, marks a draft ready and turns on auto-merge (merge commit). On a merged or closed PR it only adds the label.
   - **Has the label but no longer low risk** (a later push added other changes): `mark_low_risk.sh <PR> --unmark`, and tell the user.
   - **Not low risk:** do nothing. The PR stays a draft for the user.
5. In your report, say which PRs you found low risk, why in one line, and what was done.

## Low-risk kinds

| Kind | What fits | What does not fit | Added |
|---|---|---|---|
| `new_integration_test` | The PR only adds a new integration test (and any files it needs) and registers it with a `RUN(...)` line in `integration_tests/CMakeLists.txt`. Example: #15670. | Any change to compiler code, CI, build scripts, docs, existing tests or reference outputs. | 2026-10-20 |
| `register_entry` | The fix only registers something that was missed: a new entry in an existing table (a map, list or registry) that fits the table's current form, for something the compiler already supports in general; the code that reads the table needs no change. Plus a new integration test for it. Example: #15679 added `{ AST::boolopType::NEqv, "~neqv" }` to `boolop2str`, next to `.eqv.`, so a defined `operator(.neqv.)` is found like `.eqv.` already was. User: "registering a thing that completely fit the current register record/table and appears to have support generally but it just needed to be registered". | A new table; changed or removed entries; an entry that needs new handling code anywhere else to work; an entry whose support is missing or only partial; any other compiler change in the same PR. | 2026-10-20 |
| `small_ice_fix` | A tiny compiler fix that turns a compile-time crash (ICE, "not implemented", assertion) into working code, and leaves every program that already compiled unchanged. All the points in "Checks for `small_ice_fix`" below must hold. Example: #16941 (#16892): `SelectCaseVisitor::visit_Select` now calls the base walker on the case bodies before lowering the Select, so nested SELECT CASE of any depth is lowered in one walk; the second whole-unit walk, a workaround, is removed. +4 -3 lines in one function of one ASR pass. User: "fairly low-risk. Good to go PR without review". | Wrong-result fixes (old output changes); new or changed error messages; any reference-output update; changes in more than one function, or in more than one file of compiler code; a new helper, class, flag or table; backend code that works around a type or ASR problem (the bug is upstream); a crash fix that only skips or hides the case (early return, `if (!x) return`) instead of handling it. | 2026-11-09 |
| `name_case_fix` | A fix for a name that the source spells with upper-case letters but that the compiler stores or looks up as written, while every other lookup uses lower case. The fix only lower-cases that name with the existing `to_lower` (or the `s2c(al, to_lower(...))` form) where it enters the symbol table or ASR node, the same way a sibling construct already does, and uses the lowered name in place of the raw one. All the points in "Checks for `name_case_fix`" below must hold. Example: #17358 (#17227): `visit_SelectType` and `visit_SelectRank` lower-case the association name, as `visit_AssociateBlock` already did; +8 -5 lines in one file. User: "such PR ... is considered low risk". | Any other logic in the same PR (new branches, new lookups, changed scoping); lower-casing something that must keep its case (strings, `bind(c, name=...)`, file names, external link names); changes in more than one file of compiler code; a new helper; any reference-output update. | 2026-11-11 |
| `common_guard_fix` | A small fix that wraps an existing step in an `if` that the code base already uses for the same decision in many places, so the step runs only for the cases it was written for. In LLVM codegen this is usually a well-known type check before a load or a descriptor step (for example `LLVM::is_llvm_pointer`, `ASRUtils::is_array`, `is_a<Pointer_t>` / `is_a<Allocatable_t>`, `ASRUtils::is_character`). All the points in "Checks for `common_guard_fix`" below must hold. Example: #17349 (#14335): in `visit_PointerAssociated`, the descriptor load now runs only `if (LLVM::is_llvm_pointer(*tgt_type))` (a check used about 180 times in `asr_to_llvm.cpp`), so an assumed-shape target no longer asserts. User: "it uses a very traditional if check that's widely used in the fortran llvm-codegen phase, mark such usage ... as a low-risk PR". | A check that is new, rare, or written for this PR; a guard that skips or hides the case (early return, `if (!x) return`) instead of handling it; a new `else` with new logic; changes in more than one function; any reference-output update; any other compiler change in the same PR. | 2026-11-12 |
| `missing_switch_case` | A fix that adds one missing `case` to a `switch` whose `default` asserts or says "not implemented", so a kind that crashed now works, and the case is built like its neighbours in the same switch. All the points in "Checks for `missing_switch_case`" below must hold. Example: the `set_allocation_size` part of #17345 (#17270): a new `Unpack` case allocates the temporary with `size(mask, i)` per dimension, like the CSHIFT, EOSHIFT and TRANSPOSE cases next to it. The user agreed (2026-11-12) to count "add a missing case to a switch that asserts on unknown cases, built like its neighbours" as low risk. #17345 itself does not fit, because it also adds `Unpack` to `intrinsic_array_result_len`, which changes the length taken on the fixed-size path that already compiled. | Any other compiler change in the same PR, even a related table entry, if it can change programs that already compiled; a case with new logic that no sibling has; a case that only skips or hides the kind (empty case, `break`, early return); more than one new case or function; any reference-output update. | 2026-11-12 |

### Checks for `small_ice_fix`

Every point must hold. When one is unclear, it is not low risk.

1. **Tiny and local.** At most about 10 changed lines of compiler code, all in one function (or one function plus the line that calls it), in one file. Tests do not count.
2. **Reuses what exists.** The fix uses a pattern or helper the code base already has, used the same way elsewhere: for example calling the base visitor to walk children first, or an existing `ASRUtils` helper. No new logic of its own.
3. **Removing is fine.** Dropping a workaround that the fix makes useless (like a repeated walk) is allowed, and is a good sign, as long as the PR body says why it is now dead.
4. **Only adds support.** On main the case failed at compile time. Programs that compiled before take the same path and get the same ASR and IR. A fix that changes what an already-compiling program produces is not this kind.
5. **No reference change.** The reference suite passes with no updated outputs. Any `tests/reference/` file in the diff rules it out.
6. **Real test.** A new integration test, registered with at least `gfortran` and `llvm`, that crashes on main and passes on the branch. It covers more than the one reported shape (for `#16941`: deeper nesting, DO / IF / DO WHILE between levels, CASE DEFAULT, character selectors).
7. **Local suites pass.** Local unit, integration and reference suites pass. Do not wait for Quick checks to judge; auto-merge waits for them anyway. Judge again after each new push.

To check point 4, read the changed function on upstream `main` and ask: for input that already worked, does the new code do exactly what the old code did? For #16941, yes: a Select with no nested Select gains only a walk over bodies that contain nothing to lower.

### Checks for `name_case_fix`

Every point must hold. When one is unclear, it is not low risk.

1. **Only lower-casing.** Every compiler change is either a `to_lower` of the raw name or a swap of the raw name for the lowered one. Nothing else. It may touch a few functions in one file when each gets the same change (#17358: SELECT TYPE and SELECT RANK).
2. **A sibling already does it.** Some other construct already lower-cases the same kind of name (for #17358: `visit_AssociateBlock`). Name it in the PR body.
3. **Lower-case code is unchanged.** `to_lower` does nothing to a lower-case name, so a program that spells the name in lower case gets the same ASR and IR. Only programs that used upper-case letters change, and those failed (or were wrong) before.
4. **The name is a Fortran identifier.** Fortran names are case-insensitive, so lower-casing is always right. Not for anything whose case matters at run time or link time.
5. **No reference change.** Any `tests/reference/` file in the diff rules it out.
6. **Real test.** A new integration test, registered with at least `gfortran` and `llvm`, that fails on main and passes on the branch. It spells the name in mixed case at the definition and in several different spellings at the uses, for every construct the fix touches.
7. **Local suites pass.** Local unit, integration and reference suites pass. Judge again after each new push.

### Checks for `common_guard_fix`

Every point must hold. When one is unclear, it is not low risk.

1. **Only a guard.** The compiler change is an `if (<check>)` around code that is already there (plus a short comment). The guarded code itself is not changed.
2. **The check is common.** The same check is used for the same kind of decision in many other places in that phase (grep it). Name it in the PR body.
3. **Old cases keep their path.** Every case that compiled before still meets the guard and runs the same code. Only cases that crashed before skip the guarded step.
4. **Tiny and local.** One function in one file of compiler code, about 10 changed lines or fewer. Tests do not count.
5. **No reference change.** Any `tests/reference/` file in the diff rules it out.
6. **Real test.** A new integration test, registered with at least `gfortran` and `llvm`, that fails on main and passes on the branch, and covers several types or shapes that reach the guard.

### Checks for `missing_switch_case`

Every point must hold. When one is unclear, it is not low risk.

1. **Only a new case.** The compiler change is one new `case` in a `switch` (or one new branch in an if-chain over the same kinds) whose `default` asserts, throws "not implemented" or reports an internal error. Nothing outside the new case changes.
2. **Only the failing path changes.** On main the new kind reached that `default` and crashed. Every kind that worked before still takes its old case, so programs that compiled before get the same ASR and IR.
3. **Built like its neighbours.** The body follows a sibling case in the same switch, with the same helpers and the same shape of code (for #17345's `Unpack`: the CSHIFT, EOSHIFT and TRANSPOSE cases). Name that sibling in the PR body. Only the parts that differ for the new kind differ, and those follow the standard (for UNPACK: the result has the shape of MASK).
4. **Small and local.** One case in one function in one file, about 25 changed lines or fewer. No new helper, class or flag.
5. **No reference change.** Any `tests/reference/` file in the diff rules it out.
6. **Real test.** A new integration test, registered with at least `gfortran` and `llvm`, that crashes on main and passes on the branch, and covers several types, ranks and shapes that reach the new case (zero size, non-1 lower bounds where they matter).
7. **Local suites pass.** Local unit, integration and reference suites pass. Judge again after each new push.

Before a `new_integration_test` PR is pushed, the new test must already pass locally on upstream main in the default, `--fast` and `--std=f23` modes and with gfortran, and its name must be free (`check_test_names.sh` of the batch-fix skill). The PR description uses the user's usual form (Fixes #N, The issue, Why it happened, The fix, Tests), says that main already gives the right result and names the PR that fixed it.

Before a `register_entry` PR is pushed: the new test fails on main and passes on the branch, the fix-mre targeted checks pass, and the local unit, integration and reference suites pass.

## The low-risk register

`low_risk_prs.txt` in the batch-fix state directory (`~/lfortran_test/.batch-fix/`, or `$BATCH_FIX_STATE`) lists every PR that got the `low risk` label, one per line: `<PR> <date> <kind> <title> | <reason>`. `mark_low_risk.sh` adds the line when it adds the label, and removes it with `--unmark`. A PR already in the file can be marked again (new push) without being listed twice. There is no limit on how many PRs it holds (the user removed the limit of 10 on 2026-11-12).

## Adding a kind

The user wants this list open for new kinds. When the user says that some other kind of PR is low risk:
1. Add a row to the table above: what fits, what does not, an example PR, the date and the user's words in a short quote.
2. If the new kind needs extra local checks before pushing, write them under the table.

Do not widen a kind, or treat a PR as low risk because it "looks safe", without the user's say-so.

## Notes

- The `low risk` label was created in `lfortran/lfortran` on 2026-10-20 (green, "Low-risk change, such as a PR that only adds a test; ready for review with auto-merge"). Other labels follow their usual rules.
- Auto-merge needs the repository's "allow auto-merge" setting (on) and push access (the user has it). If `gh pr merge --auto` fails, say so; do not merge by hand.
- Only push to the fork remote `myrepo`, never to `origin`.
