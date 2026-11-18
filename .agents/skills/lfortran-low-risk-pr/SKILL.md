---
name: lfortran-low-risk-pr
description: Judge whether an LFortran PR is low risk by reading its diff yourself, and if it is, mark it ready for review, label it "low risk" and turn on auto-merge. Use it EVERY time a PR to lfortran/lfortran is created or pushed - by you or by any agent, through `gh pr create`, `publish_pr.sh`, or `git push` to a PR branch - and whenever the user asks which PRs are low risk or suggests a new kind of low-risk PR. Low-risk kinds today: a PR that just adds a test and its registration line, a fix that only registers something the compiler already supports in an existing table (plus its test), and a fix that turns a compile-time crash into working code without changing any program that already compiled (plus its test), and a fix that only lower-cases a Fortran name the compiler stored as written, like a sibling construct already does (plus its test), and a fix that wraps an existing step in an `if` check the code base already uses widely for the same decision, such as a common LLVM-codegen type check (plus its test), and a fix that makes the generated code check a value (null pointer, present, allocated) before using it, with a check the code base already makes for the same kind of value (plus its test), and a fix that adds missing cases to a switch whose default asserts, built like its neighbour cases (plus its test), and a docs-only fix about existing behavior, and a repair of a bug in a test's own code that keeps what it checks, and a missing standard `#include` in C/C++ files, and a fix to only the text or location of an existing error message, and a fix that adds a compile-time error (semantic or syntax) LFortran did not report, for code that really breaks a rule of the Fortran standard (plus its reference test), and a fix that adds or fixes visit or replace methods in an existing ASR visitor or replacer with simple logic like its siblings, without visiting any subnode more often than needed (plus its test), and a change to how existing tests are registered or named that keeps every backend, mode and setting they were tested with, and a codegen fix that loads a value at run time (rank, size, length) where the code assumed a compile-time value, only for a case where the language makes that value a real runtime value (plus its test), and a fix that only adds a type check to an existing if/else condition so an unhandled type takes a body that already works for it (plus its test), and a bump of a pinned dependency, tool or action version that Quick checks use (not only Exhaustive), and a fix to code that builds an ASR type from another type so it picks how to build it by the source type, keeping old source types the same (plus its test). The list of kinds is meant to grow with the user's suggestions.
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
3. Decide: does EVERY change fit one of the kinds below? The changes may fit different kinds: a mix of low-risk kinds is a low-risk PR (the user, 2026-11-16: "a mix of low-risks is totally a low-risk PR"). Each change must pass all the checks of its own kind. When in doubt, it is not low risk.
4. Act:
   - **Low risk:** `<skill>/scripts/mark_low_risk.sh <PR> <kind> "<one-line reason>"` (`<skill>` is this skill's folder). For a mix, join the kinds with `+` (for example `missing_switch_case+visitor_logic_fix`). It adds the label, writes the PR to the register, marks a draft ready and turns on auto-merge (merge commit). On a merged or closed PR it only adds the label.
   - **Has the label but no longer low risk** (a later push added other changes): `mark_low_risk.sh <PR> --unmark`, and tell the user.
   - **Not low risk:** do nothing. The PR stays a draft for the user.
5. In your report, say which PRs you found low risk, why in one line, and what was done.

## Low-risk kinds

| Kind | What fits | What does not fit | Added |
|---|---|---|---|
| `new_integration_test` | The PR only adds a new integration test (and any files it needs) and registers it with a `RUN(...)` line in `integration_tests/CMakeLists.txt`. Example: #15670. | Any change to compiler code, CI, build scripts, docs, existing tests or reference outputs. | 2026-10-20 |
| `register_entry` | The fix only registers something that was missed: a new entry in an existing table (a map, list or registry) that fits the table's current form, for something the compiler already supports in general; the code that reads the table needs no change. Plus a new integration test for it. Example: #15679 added `{ AST::boolopType::NEqv, "~neqv" }` to `boolop2str`, next to `.eqv.`, so a defined `operator(.neqv.)` is found like `.eqv.` already was. User: "registering a thing that completely fit the current register record/table and appears to have support generally but it just needed to be registered". | A new table; changed or removed entries; an entry that needs new handling code anywhere else to work; an entry whose support is missing or only partial; any other compiler change in the same PR. | 2026-10-20 |
| `small_ice_fix` | A compiler fix that turns a compile-time crash (ICE, "not implemented", assertion) into working code, and leaves every program that already compiled unchanged. All the points in "Checks for `small_ice_fix`" below must hold. Example: #16941 (#16892): `SelectCaseVisitor::visit_Select` now calls the base walker on the case bodies before lowering the Select, so nested SELECT CASE of any depth is lowered in one walk; the second whole-unit walk, a workaround, is removed. +4 -3 lines in one function of one ASR pass. User: "fairly low-risk. Good to go PR without review". | Wrong-result fixes (old output changes); new or changed error messages; any reference-output update; a new helper, class, flag or table; backend code that works around a type or ASR problem (the bug is upstream); a crash fix that only skips or hides the case (early return, `if (!x) return`) instead of handling it. | 2026-11-09 |
| `name_case_fix` | A fix for a name that the source spells with upper-case letters but that the compiler stores or looks up as written, while every other lookup uses lower case. The fix only lower-cases that name with the existing `to_lower` (or the `s2c(al, to_lower(...))` form) where it enters the symbol table or ASR node, the same way a sibling construct already does, and uses the lowered name in place of the raw one. All the points in "Checks for `name_case_fix`" below must hold. Example: #17358 (#17227): `visit_SelectType` and `visit_SelectRank` lower-case the association name, as `visit_AssociateBlock` already did; +8 -5 lines in one file. User: "such PR ... is considered low risk". | Any other logic in the same PR (new branches, new lookups, changed scoping); lower-casing something that must keep its case (strings, `bind(c, name=...)`, file names, external link names); a new helper; any reference-output update. | 2026-11-11 |
| `common_guard_fix` | A fix that wraps an existing step in an `if` that the code base already uses for the same decision in many places, so the step runs only for the cases it was written for. In LLVM codegen this is usually a well-known type check before a load or a descriptor step (for example `LLVM::is_llvm_pointer`, `ASRUtils::is_array`, `is_a<Pointer_t>` / `is_a<Allocatable_t>`, `ASRUtils::is_character`). All the points in "Checks for `common_guard_fix`" below must hold. Example: #17349 (#14335): in `visit_PointerAssociated`, the descriptor load now runs only `if (LLVM::is_llvm_pointer(*tgt_type))` (a check used about 180 times in `asr_to_llvm.cpp`), so an assumed-shape target no longer asserts. User: "it uses a very traditional if check that's widely used in the fortran llvm-codegen phase, mark such usage ... as a low-risk PR". | A check that is new, rare, or written for this PR; a guard that skips or hides the case (early return, `if (!x) return`) instead of handling it; a new `else` with new logic; any reference-output update; any other compiler change in the same PR. | 2026-11-12 |
| `common_runtime_check` | A fix that makes the generated code check a value before it uses it, with a check that the code base already emits for the same kind of value in the same situation: a null check on a descriptor or data pointer before a load, a `present` check, an "is allocated" check, a zero-size check. The check gives the right Fortran answer for the checked case (null data means "not allocated" or "disassociated"), it does not just hide a crash. All the points in "Checks for `common_runtime_check`" below must hold. Example: #15967 (#13623): in `SimpleCMODescriptor::get_is_allocated_flag`, the string descriptor is now checked for null before its data is read, the same way the same function already checks the array descriptor and the polymorphic wrapper, so `allocate` of a nullified `character(len=k), pointer :: p(:)` no longer segfaults. User: "null checks basically a low-risk thing to do ... we want to tolerate checks that we usually check". | A check that the code base does not already make for that kind of value; a check on a value that should never be null or empty, where the real bug is the code that made it so (a workaround: fix the producer instead); a checked case that returns a made-up result instead of the right one; a new runtime error or message; any reference-output update; any other compiler change in the same PR. | 2026-11-14 |
| `missing_switch_case` | A fix that adds missing `case`s to a `switch` whose `default` asserts or says "not implemented", so a kind that crashed now works, and each case is built like its neighbours in the same switch. All the points in "Checks for `missing_switch_case`" below must hold. Example: the `set_allocation_size` part of #17345 (#17270): a new `Unpack` case allocates the temporary with `size(mask, i)` per dimension, like the CSHIFT, EOSHIFT and TRANSPOSE cases next to it. The user agreed (2026-11-12) to count "add a missing case to a switch that asserts on unknown cases, built like its neighbours" as low risk. #17345 itself does not fit, because it also adds `Unpack` to `intrinsic_array_result_len`, which changes the length taken on the fixed-size path that already compiled. | Any other compiler change in the same PR, even a related table entry, if it can change programs that already compiled; a case with new logic that no sibling has; a case that only skips or hides the kind (empty case, `break`, early return); any reference-output update. | 2026-11-12 |
| `doc_fix` | The PR only fixes or adds prose in documentation (`doc/`, a README) about behavior LFortran already has: a typo, a clearer explanation, a short troubleshooting note. Any command or example in it is checked to be right. All the points in "Checks for `doc_fix`" below must hold. Example: #16202 (a troubleshooting note). Ported from D1 of certik's `classify-pr-risk` skill (#17660). | Any non-doc file in the same PR; a new promise about what LFortran supports or how it behaves; agent skills, `AGENTS.md`/`CLAUDE.md`, CI, build or packaging files (these are policy or config, not passive docs, even as `.md`); doc files that the build or site generator runs; deleting files or tooling (#16823 is not this kind). | 2026-11-14 |
| `test_fixture_fix` | The PR only repairs a real bug in an existing test's own code, and the test still checks exactly what it checked before. Typical repairs: setting an uninitialized variable that the test reads; giving a test a unique file name so parallel runs do not clash; removing an invalid statement after an expected failure (every check of the failure stays); matching a test variable to a function's existing interface. All the points in "Checks for `test_fixture_fix`" below must hold. Examples: #16384, #16399, #16548, #16605, #16856. Ported from T2 of `classify-pr-risk` (#17660). | Any change to expected values, tolerances, input precision, platform guards, labels or modes; setting a variable to the expected answer or skipping the step that failed; removing or weakening a check; any compiler, runtime or test-runner change. Counterexamples: #17068, #17521, #17532, #17546, #17649. | 2026-11-14 |
| `missing_include` | The PR only adds a missing standard header `#include` (or an equally local declaration) to C/C++ files that fail to build without it on some configuration. All the points in "Checks for `missing_include`" below must hold. Ported from C1 of `classify-pr-risk` (#17660). | A changed or shared project header; a header that picks a different overload or implementation; new build flags, link libraries or dependencies; any other code change. | 2026-11-14 |
| `missing_error` | A fix that adds a compile-time error (semantic or syntax) that LFortran did not report, for code that really is invalid Fortran: it breaks a rule of the standard, so every program it rejects was wrong. Before the fix LFortran accepted the code silently, crashed, or gave garbage. All the points in "Checks for `missing_error`" below must hold. Example: item 3 of #17346 (#16223): a constant DIM of LBOUND/UBOUND of an assumed-rank array outside 1..15 is now rejected with `` `dim` argument of `ubound` must be between 1 and 15 for an assumed-rank array ``, because DIM must be between 1 and the rank, and a rank is at most 15. #17346 itself does not fit, because it also changes how valid LBOUND/UBOUND calls compile. User (2026-11-15): "adding a not reported error (language error -- semantic or syntactic) if the error is proper legit fortran error". | Rejecting code the standard allows, even if gfortran rejects it; rejecting a legacy extension LFortran accepts on purpose; a "not supported yet" error (an LFortran limit, not a language error); a warning turned into an error; a runtime check; a changed grammar rule in `parser.yy`; a new ASR walk, pass, helper or class to find the case; any change to how valid code compiles, or to another message; reference diffs beyond the new message. | 2026-11-15 |
| `visitor_logic_fix` | A fix in an existing ASR visitor, walker or replacer (a class built on `BaseWalkVisitor`, `ASRPassBaseWalkVisitor`, `BaseExprReplacer`, `CallReplacerOnExpressionsVisitor` and the like) that adds or fixes `visit_X` or `replace_X` methods with simple logic: it replaces one node with one built by existing helpers, or visits the node and records or forwards something, like the sibling methods in the same class. It must not visit any subnode more often than needed. All the points in "Checks for `visitor_logic_fix`" below must hold. No example PR yet. User (2026-11-15): "if the fix is about a visitor/replacer and it introduces simple replacement or visit logic, it's considered as low-risk. We just need to make sure the visitor/replacer doesn't introduce additional visits to subnodes unneccessarly". | A new visitor, replacer, pass or extra walk over the unit; a method that visits a child twice (calls the base method and also visits the same child by hand, or walks a subtree again inside a loop); a method that skips children the base method visits; new logic no sibling method has; any reference-output update; any other compiler change in the same PR. | 2026-11-15 |
| `diagnostic_text_fix` | The PR only fixes the wording, spelling, formatting or source location of an existing error or debug message. When and whether the message fires stays the same. All the points in "Checks for `diagnostic_text_fix`" below must hold. Ported from C2 of `classify-pr-risk` (#17660). | A new check or error; a changed severity (warning vs error); a change to what is accepted or to error recovery; a new ASR walk to find a location; a location API that keeps state across statements or scopes; reference updates beyond the changed message. | 2026-11-14 |
| `runtime_value_codegen` | A codegen fix (usually LLVM) in a function that emits IR from a value it assumed is always known at compile time (a rank, a size, an extent, a bound, a string length, a byte count), for a case where the value is only known at run time. The fix still handles the compile-time cases and, for the new case, fetches the value at run time, then lets the new case use the code that already handles the compile-time cases. All the points in "Checks for `runtime_value_codegen`" below must hold. Example for context (the kind is not limited to it): #17902 (#17258): `convert_to_polymorphic_arg` copied `dim_des_size * n_dims_copy` bytes of dimension descriptors, with `n_dims_copy` taken at compile time; an assumed-rank actual now takes the rank from its descriptor at run time (`arr_descr->get_rank`), and other arrays keep the constant. User (2026-11-18): "a codegen function emitting llvm IR that assumed always that it will consume compile-time value, finds out that we have runtime-value cases and tries to fetch the runtime-value along with the compile-time cases ... is considered low-risk as long as the new case is legitimately (logically, language wise) a real runtime value ... if that case could be handled using a compile-time value -- that rule fails". | A case whose value can be known at compile time (the language fixes it, or the ASR has or should have it as a constant): then the real bug is that the value was not taken from ASR or not folded, and a runtime load hides it; new logic beyond fetching the value and letting the new case in; any reference-output update; any other compiler change in the same PR. | 2026-11-18 |
| `unhandled_type_check` | A fix that adds a type check to an existing `if` / `else if` condition (for example an extra `ASRUtils::is_assumed_rank_array(t)` or `ASRUtils::is_character(*t)` joined with "or"), so a type that the chain did not handle now takes a body that already exists and is right for it. All the points in "Checks for `unhandled_type_check`" below must hold. User (2026-11-18): "any check that just makes the if/else body work for an unhandled type". | A change to the body itself; a type the body does not handle correctly as it is; a check that also moves types that already worked to another branch; any reference-output update; any other compiler change in the same PR. | 2026-11-18 |
| `version_bump` | The PR only bumps the pinned version of a dependency, tool or GitHub action (in `pixi.toml` and `pixi.lock`, a workflow under `.github/`, or a `ci/` script), and the bumped thing is used by a Quick job, so the PR's own Quick run tests the new version. All the points in "Checks for `version_bump`" below must hold. User (2026-11-18): "version bumping is fine, as long as it touching areas that are tested on quick tests and not only on the exhaustive ones". | A bump of something only Exhaustive uses (a third-party application, an Exhaustive-only configuration or platform), since PRs never run Exhaustive; any other change in the same PR (new jobs, changed steps or flags, code changes); a bump that needs a reference-output update (for example the LLVM 11 used for references). | 2026-11-18 |
| `mirrored_type_creation` | A fix to code that builds a new ASR type from another type, mirroring it or deriving from it (for example the type of a pointer, allocatable or temporary made from a variable's or expression's type). The same type is still built, but the code now picks how to build it by the source type, adding or dropping details (rank, dimensions, length, pointer or allocatable wrapper, physical type) so the new type fits the source. All the points in "Checks for `mirrored_type_creation`" below must hold. Example: #17729 (#17257): the pointer temporary for a TARGET actual was built with `create_array_type_with_empty_dims` and the actual's rank, which made a scalar for an assumed-rank actual; `get_pointer_type_for_target` now duplicates the assumed-rank type and keeps the old way for every other array, and the three places that built this type call it. User (2026-11-18): "the same creation of type happens but now we're creating it more robustly and design fitting because we add/remove details based on the type we're mirroring". | A change to what the type is used for (new statements, symbols, casts or calls around it); a new type that does not match the source type by the language; a changed type for source types that were built right before; any reference-output update; any other compiler change in the same PR. | 2026-11-18 |
| `test_registration_change` | A change to how existing tests are registered or named: renaming a test (its file, its `program` name and its `RUN` or `tests.toml` entry), moving its line, or changing its labels, `EXTRA_ARGS`, `GFORTRAN_ARGS` or other settings, as long as every test keeps every backend, mode and setting it was tested with before. Enabling more is fine. All the points in "Checks for `test_registration_change`" below must hold. Example: commit `65a8580d66` of #17995 renamed `coarray_01`/`coarray_02`/`coarray_03` to `coarrays_01`/`coarrays_02`/`coarrays_08` after a review comment. User (2026-11-18): "any change to the test registeration should be fine, as long as the testing setting don't regress ... if test_1 used to be tested with llvm, gfortran, wasm, the change should keep those tests and don't disable any, if we enable more that's fine". | Removing a test, a label, a backend or a mode it ran in; adding a flag that skips or weakens it (`FAIL`, a `NO...` or skip option, a smaller `NUM_IMAGES`); changing what a test checks (its body beyond the renamed `program` name, its expected output, its reference content); any compiler, runtime or CI change in the same change. | 2026-11-18 |

In the "What does not fit" column, "any other compiler change in the same PR" means a change that fits no low-risk kind. A change that fits another kind is allowed (see step 3).

### Checks for `small_ice_fix`

Every point must hold. When one is unclear, it is not low risk.

1. **Reuses what exists.** The fix uses a pattern or helper the code base already has, used the same way elsewhere: for example calling the base visitor to walk children first, or an existing `ASRUtils` helper. No new logic of its own.
2. **Removing is fine.** Dropping a workaround that the fix makes useless (like a repeated walk) is allowed, and is a good sign, as long as the PR body says why it is now dead.
3. **Only adds support.** On main the case failed at compile time. Programs that compiled before take the same path and get the same ASR and IR. A fix that changes what an already-compiling program produces is not this kind.
4. **No reference change.** Any `tests/reference/` file in the diff rules it out.
5. **Real test.** A new integration test, registered with at least `gfortran` and `llvm`, that crashes on main and passes on the branch. One case that reaches the changed code is enough (the user, 2026-11-16: no need to cover several types, ranks, shapes or ways in).

To check point 4, read the changed function on upstream `main` and ask: for input that already worked, does the new code do exactly what the old code did? For #16941, yes: a Select with no nested Select gains only a walk over bodies that contain nothing to lower.

### Checks for `name_case_fix`

Every point must hold. When one is unclear, it is not low risk.

1. **Only lower-casing.** Every compiler change is either a `to_lower` of the raw name or a swap of the raw name for the lowered one. Nothing else. It may touch several functions or files when each gets the same change (#17358: SELECT TYPE and SELECT RANK).
2. **A sibling already does it.** Some other construct already lower-cases the same kind of name (for #17358: `visit_AssociateBlock`). Name it in the PR body.
3. **Lower-case code is unchanged.** `to_lower` does nothing to a lower-case name, so a program that spells the name in lower case gets the same ASR and IR. Only programs that used upper-case letters change, and those failed (or were wrong) before.
4. **The name is a Fortran identifier.** Fortran names are case-insensitive, so lower-casing is always right. Not for anything whose case matters at run time or link time.
5. **No reference change.** Any `tests/reference/` file in the diff rules it out.
6. **Real test.** A new integration test, registered with at least `gfortran` and `llvm`, that fails on main and passes on the branch. It spells the name with upper-case letters, one case per construct the fix touches; no need for several spellings (the user, 2026-11-16).

### Checks for `common_guard_fix`

Every point must hold. When one is unclear, it is not low risk.

1. **Only a guard.** The compiler change is an `if (<check>)` around code that is already there (plus a short comment). The guarded code itself is not changed.
2. **The check is common.** The same check is used for the same kind of decision in many other places in that phase (grep it). Name it in the PR body.
3. **Old cases keep their path.** Every case that compiled before still meets the guard and runs the same code. Only cases that crashed before skip the guarded step.
4. **No reference change.** Any `tests/reference/` file in the diff rules it out.
5. **Real test.** A new integration test, registered with at least `gfortran` and `llvm`, that fails on main and passes on the branch. One case that reaches the changed code is enough (the user, 2026-11-16: no need to cover several types, ranks, shapes or ways in).

### Checks for `common_runtime_check`

Every point must hold. When one is unclear, it is not low risk.

1. **Only a check.** The compiler change emits a test on a value and a branch around code that is already there (plus a short comment). The guarded code itself is not changed, except to use the value the check already loaded.
2. **The check is common for that value.** Grep the phase for the same check on the same kind of value (descriptor pointer, data pointer, wrapper, optional argument). It must already be made in several places, ideally in the same function or its siblings (#15967: the two null checks above it in `get_is_allocated_flag`). Name them in the PR body. A check that is common in general but new for this kind of value does not count.
3. **The checked case is a legal state.** The value can rightly be null, absent or empty in valid Fortran (a nullified pointer, an unallocated component, an absent optional), and the check gives the answer the standard asks for in that state. If the value should never be null there, the check is a workaround and the PR is not low risk.
4. **Old cases keep their result.** When the check passes, the same code runs as before, so programs that worked before give the same results.
5. **No new pieces.** No new helper, class or flag.
6. **No reference change.** Any `tests/reference/` file in the diff rules it out.
7. **Real test.** A new integration test, registered with at least `gfortran` and `llvm`, that fails on main and passes on the branch. One case that reaches the changed code is enough (the user, 2026-11-16: no need to cover several types, ranks, shapes or ways in).

### Checks for `missing_switch_case`

Every point must hold. When one is unclear, it is not low risk.

1. **Only new cases.** The compiler change is new `case`s in a `switch` (or new branches in an if-chain over the same kinds) whose `default` asserts, throws "not implemented" or reports an internal error. Nothing outside the new case changes.
2. **Only the failing path changes.** On main the new kind reached that `default` and crashed. Every kind that worked before still takes its old case, so programs that compiled before get the same ASR and IR.
3. **Built like its neighbours.** The body follows a sibling case in the same switch, with the same helpers and the same shape of code (for #17345's `Unpack`: the CSHIFT, EOSHIFT and TRANSPOSE cases). Name that sibling in the PR body. Only the parts that differ for the new kind differ, and those follow the standard (for UNPACK: the result has the shape of MASK).
4. **No new pieces.** No new helper, class or flag.
5. **No reference change.** Any `tests/reference/` file in the diff rules it out.
6. **Real test.** A new integration test, registered with at least `gfortran` and `llvm`, that crashes on main and passes on the branch. One case that reaches the new `case` is enough (the user, 2026-11-16: no need to cover several types, ranks, shapes or ways in).

### Checks for `doc_fix`

Every point must hold. When one is unclear, it is not low risk.

1. **Only docs.** Every changed file is prose documentation. No code, test, CI, build, skill or agent-instruction file.
2. **Describes what exists.** Each statement matches LFortran's current behavior on main. Nothing claims new support or a new policy.
3. **Commands are right.** Any command or example in the change is checked against main (run it when it is cheap).
4. **Nothing runs it.** The changed file is not an input that the build or the doc-site generator executes (templates, embedded scripts).

### Checks for `test_fixture_fix`

Every point must hold. When one is unclear, it is not low risk.

1. **A real test bug.** You can state the defect in the test on its own (for example "reads `x` before setting it"), apart from any compiler bug.
2. **Same oracle.** Every check, expected value, kind and code path the test exercised before is still there and unchanged.
3. **Not a bypass.** The repair does not set a result to the expected answer or skip the operation that was failing. Read the code around the change.
4. **Still catches the bug.** When it is not obvious, show that a wrong result still makes the test fail.
5. **Test passes.** The fixed test passes on main in the default, `--fast` and `--std=f23` modes and with gfortran, when it has a gfortran label.

### Checks for `missing_include`

Every point must hold. When one is unclear, it is not low risk.

1. **Only includes.** The only changes are `#include` lines (or local declarations) in `.cpp`/`.c` files.
2. **Real build failure.** Name the configuration that fails to build without it (compiler, LLVM version or platform), and show that it builds with it.
3. **No behavior change.** The header is a standard one and does not pull in a different overload, conditional code or API for code that already built.
4. **Builds.** The default local build passes.

### Checks for `missing_error`

Every point must hold. When one is unclear, it is not low risk.

1. **A real Fortran error.** Name the rule the code breaks: a constraint or section of the standard (for #17346: DIM must be between 1 and the rank, and a rank is at most 15). gfortran rejecting it is supporting evidence, not proof. Put the rule in the PR body.
2. **Only invalid code is rejected.** The condition is exact: no valid program meets it. Check the edges by hand (for #17346: DIM 1 and 15 still compile, DIM not a constant is not checked). If the rule depends on something known only at run time, a compile-time error is wrong.
3. **Only adds an error.** Valid programs take the same path and get the same ASR and IR. No other message, severity or recovery changes.
4. **Built like its neighbours.** Each new check sits next to the code that already handles that construct, built like the neighbouring errors in that function (same `diag.add(Diagnostic(...))` form, same `SemanticAbort` or continue-compilation recovery). A syntax error goes in a parser action or the semantic phase, not in a grammar rule change.
5. **Good message.** Explicit kinds, no ASR node names, says what is wrong and what is allowed. The label points at the bad part of the source. Upper or lower case at the start does not matter (the user, 2026-11-17).
6. **Tested.** New cases are appended at the end of `tests/errors/continue_compilation_1.f90`, one per form the check catches. The reference update only adds the new messages (plus the `.json` hash). Errors after the new ones in that file still appear unchanged. `! {Error}` comments on the cases are fine (the user, 2026-11-17). A case that needs flags `continue_compilation_1.f90` does not run with (for example `--implicit-interface`) may go in its own small file under `tests/errors/`, registered in `tests/tests.toml` with those flags and its new references; say in the PR body why it needs its own file (#15609; the user, 2026-11-17). A separate file for a case that would work in `continue_compilation_1.f90` still does not fit.

### Checks for `visitor_logic_fix`

Every point must hold. When one is unclear, it is not low risk.

1. **Only visitor code.** The compiler change is new or changed `visit_X` / `replace_X` methods in existing visitor or replacer classes. No new class, pass, flag or helper.
2. **Simple logic.** The method builds its replacement with existing `ASRUtils` / `make_*_t` helpers, or only records or forwards what it visits, the same way sibling methods in that class do. Name the sibling in the PR body.
3. **No extra visits.** Compare the method with the base method it overrides (generated in `src/libasr/asr.h`). Each child the base visits is visited exactly once: not twice (base call plus a hand-written visit of the same child), not again inside a loop, and not skipped. A replacer saves and restores `current_expr` and writes the new node back through it, like its siblings.
4. **Old cases keep their path.** Only the node kind or case that was wrong takes new code. Every other node gets the same ASR and IR as before.
5. **No reference change.** Any `tests/reference/` file in the diff rules it out.
6. **Real test.** A new integration test, registered with at least `gfortran` and `llvm`, that fails on main and passes on the branch. One case that reaches the changed code is enough (the user, 2026-11-16: no need to cover several types, ranks, shapes or ways in).

### Checks for `runtime_value_codegen`

Every point must hold. When one is unclear, it is not low risk.

1. **Really a runtime value.** By the language, the value cannot be known at compile time in the new case. Examples: the rank of an assumed-rank object; the extents and bounds of an assumed-shape, allocatable or pointer array, or of an array whose bounds are not constant; the length of an assumed-length or deferred-length character; anything that depends on the dynamic type of a polymorphic object. If the value is fixed for that case (explicit-shape array with constant bounds, a `parameter`, a constant length or kind), or the ASR type already holds it, the rule fails, even if the runtime load would give the right answer.
2. **Only the value source changes.** The compiler change fetches the value at run time for the new case and keeps the compile-time value for the old cases. The code that uses the value stays as it is, apart from taking the runtime value. Widening a condition so the new case reaches that existing code is allowed when the code is correct for it once it has the runtime value.
3. **No reference change.** Any `tests/reference/` file in the diff rules it out.
4. **Real test.** A new integration test, registered with at least `gfortran` and `llvm`, that fails on main and passes on the branch. One case that reaches the changed code is enough (the user, 2026-11-16).

### Checks for `unhandled_type_check`

Every point must hold. When one is unclear, it is not low risk.

1. **Only the check.** The compiler change adds a type check to the condition of an existing branch. The branch body is not changed.
2. **The body fits the new type.** Read the body: it does the right thing for the new type as it is.
3. **Other types stay put.** Types that worked before take the same branch as before. Only the unhandled type moves.
4. **No reference change.** Any `tests/reference/` file in the diff rules it out.
5. **Real test.** A new integration test, registered with at least `gfortran` and `llvm`, that fails on main and passes on the branch. One case that reaches the changed code is enough (the user, 2026-11-16).

### Checks for `version_bump`

Every point must hold. When one is unclear, it is not low risk.

1. **Only versions.** Every change is a version, tag, commit SHA or hash of a pinned dependency, tool or action, plus the lockfile entries the bump brings with it.
2. **Quick tests it.** Find where the bumped thing is used. A job in `.github/workflows/Quick-Checks-CI.yml` must use it, directly or through what Quick calls (`.github/actions/*`, `Compiler-Compatibility-CI.yml`, `ci/` scripts, Pixi tasks). If only `Exhaustive-Checks-CI.yml` or other non-PR workflows use it, the rule fails.
3. **No reference change.** Any `tests/reference/` file in the diff rules it out.

### Checks for `mirrored_type_creation`

Every point must hold. When one is unclear, it is not low risk.

1. **Only type creation.** The compiler change is in the code that builds the new type from the source type. It chooses between ways of building it by the source type. The code that uses the new type is unchanged.
2. **Fits the source.** For the new case, the built type is what the language gives (for #17729: a pointer to an assumed-rank target is assumed-rank).
3. **Old source types unchanged.** Source types that were built right before are still built the same way.
4. **One place is fine.** Moving that type creation into one function that every place building the same type calls is allowed (#17729: three places).
5. **No reference change.** Any `tests/reference/` file in the diff rules it out.
6. **Real test.** A new integration test, registered with at least `gfortran` and `llvm`, that fails on main and passes on the branch. One case that reaches the changed code is enough (the user, 2026-11-16).

### Checks for `test_registration_change`

Every point must hold. When one is unclear, it is not low risk.

1. **Only registration and names.** The changes are `RUN(...)` lines in `integration_tests/CMakeLists.txt`, entries in `tests/tests.toml`, and test file renames. A renamed file changes only its `program`/`end program` name (`git show -M` shows a rename with just those lines).
2. **No lost coverage.** For each test, compare its old and new registration: every label (backend), mode and setting it had is still there, and nothing new skips or weakens it. New labels or modes are fine.
3. **References move unchanged.** A renamed `tests.toml` test may get new reference file names; their content is the same apart from the name and hash fields that the rename changes.
4. **Names are free.** New names do not clash (`check_test_names.sh` of the batch-fix skill).
5. **Tests pass.** Every renamed or re-registered test passes with its new registration.

### Checks for `diagnostic_text_fix`

Every point must hold. When one is unclear, it is not low risk.

1. **Only the message.** The compiler change edits the text, format or location passed to an existing diagnostic or debug call. The condition that triggers it is unchanged.
2. **Same flow.** After the message, the same thing happens as before (same severity, same recovery, same return).
3. **Location is safe.** If the fix uses a different location, the API it calls does not keep or change state that later statements see.
4. **Only matching references change.** Updated `tests/reference/` files differ only in that message's text or location.
5. **Tested.** The message is covered by a reference test (for example `tests/errors/continue_compilation_1.f90`) that shows the corrected text.

Before a `new_integration_test` PR is pushed, the new test must already pass locally on upstream main in the default, `--fast` and `--std=f23` modes and with gfortran, and its name must be free (`check_test_names.sh` of the batch-fix skill). The PR description uses the user's usual form (Fixes #N, The issue, Why it happened, The fix, Tests), says that main already gives the right result and names the PR that fixed it.

Before a `register_entry` PR is pushed: the new test fails on main and passes on the branch and the fix-mre targeted checks pass.

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
