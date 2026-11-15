# Agent messages

One fixer agent per issue, and its job ends when the draft PR is open. Start it once with prompt 1. Before it publishes, each review round is done by a NEW reviewer agent started with prompt 1R; its findings go back to the fixer with prompt 1F, and when a round is clean the fixer publishes on prompt 1P. Resume the SAME fixer (SendMessage) with the later prompts only when there is something for it to do; never resume a reviewer for a later round. Replace `<N>`, `<title>`, `<src>`, `<branch>`, `<base>`, `<k>` (the review round, from 1), `<skill>` (this skill's folder) and the bracketed parts. If the agent is gone or its context has grown too large, start a new `general-purpose` agent with the "Resume" prompt.

## 1. Start the fixer: from reproduction to a branch ready for review (fix-issue Phases 2–3)

> You are the fixer agent for LFortran issue #<N> ("<title>"), from reproduction to an open draft PR. Fresh reviewer agents check your branch before it is published.
>
> First read `<src>/.fix-issue/<N>/machine.md` completely with the Read tool. It gives your worktree, branch and the rules of this machine, and it overrides the repository's skills where they conflict. Then read `<src>/.agents/skills/fix-issue/SKILL.md` and `<src>/AGENTS.md`.
>
> Do `fix-issue` Phases 2 and 3 yourself, in one run:
> - Phase 2: reproduce with the `repro-issue` skill.
> - Phase 3: loop `create-mre` → `fix-mre` (targeted checks 5a) → the original-issue check (3c), one fix commit followed by one `test:` commit with its integration test per distinct bug (machine.md, "Tests go in their own commit"), until every program and scenario in the issue passes. Then run the suites once in the default mode (3d: unit, integration, reference) on the committed head and record `suites_green_sha` in `state.md`.
> - Write `.fix-issue/<N>/pr_body.md` in the form machine.md gives under "The PR description" (the issue explained simply, then the fix; not `fix-issue`'s headings).
>
> Then stop and report `READY FOR REVIEW <sha>`. Do not publish yet: machine.md, "One fixer agent, a fresh reviewer before publishing", says what happens next.
>
> Authorized: commits on your branch with no co-author or AI-attribution lines, pushes to `myrepo`, and the draft PR against `lfortran/lfortran`. Not authorized: pushing to `origin`, filing issues, commenting anywhere, labels, marking ready.
> [Other issues being fixed now: #A, #B. If yours shares a root cause with one of them, or needs its fix, stop before publishing and say so.]
>
> Report as machine.md describes: `READY FOR REVIEW <sha>` (or why you stopped), the commit SHAs, the suite results against the baseline, anything left open, and the other bugs in two lists, "Fix in this PR" and "Report separately", each with its reason.

## 1R. Start a fresh reviewer for round k (a NEW agent every round)

Send when the fixer reports `READY FOR REVIEW`. Start a new background `general-purpose` agent; do not reuse a reviewer from an earlier round, and do not tell it what the fixer or you think of the fix: give it the code, not conclusions. While it runs, the fixer stays idle, so only one agent writes in the worktree.

> You are a fresh reviewer for the fix of LFortran issue #<N> ("<title>"). Another agent wrote it; you did not. This is review round <k>. Nothing is published yet.
>
> Worktree: `<src>`, branch `<branch>`, based on upstream `main` `<base>`. State directory: `<src>/.fix-issue/<N>/`.
>
> Read `<skill>/assets/review.md` completely with the Read tool and follow it, with `<src>`, `<N>` and `<k>` as above. It says what to read and what not to read first, how to build and run (the shared build slot), which paths to test, what you must not change, and how to report. You change no tracked file and make no commit; the fixer makes every change. You are not authorized to push or to write anything to GitHub.

## 1F. Send the findings of round k to the fixer

Send to the SAME fixer agent when a reviewer reports `NEEDS WORK`. Pass the file, not your summary of it.

> Review round <k> of your branch found work to do: `.fix-issue/<N>/review_<k>.md`. Read it in full. Fix every `blocker` and `rework` item, including each bug the reviewer put under "Fix in this PR", as machine.md says (step 4 of "One fixer agent, a fresh reviewer before publishing"): new commits only, a fix commit then a `test:` commit, never amend or rebase what the reviewer saw; for a finding you disagree with, write why in `round_<k>.md` with a program that shows it. Rerun the targeted checks, rerun the suites if `src/` or `grammar/` changed, and update `pr_body.md` if it is no longer true. Do not publish. Then report `READY FOR REVIEW <sha>` with, for each finding, what you changed or why not.

## 1P. Publish after a clean round

Send to the SAME fixer agent when a reviewer reports `CLEAN` and `state.md` has `review_clean_sha` equal to the branch head.

> Review round <k> of your branch was clean at <sha>. Publish now with `publish_pr.sh <N> --title "<title>"` (machine.md, "Publishing"), then stop. Do not watch CI and do not mark the PR ready. Report `PUBLISHED <PR url> <sha>`.

## 2. Link side bugs in the PR description

Send when the coordinator has filed or matched the bugs the agent reported.

> Side bugs from your #<N> report are resolved upstream. Add them under `## Other bugs found` at the end of `.fix-issue/<N>/pr_body.md`, one line per bug, update the PR with `gh pr edit <P> --repo lfortran/lfortran --body-file - < .fix-issue/<N>/pr_body.md` (`gh` is a snap and cannot open files under `/media`, so the body goes on stdin), and mark them in your `followups.md`. Change nothing else: no commits, no pushes, no comments on those issues.
> - [bug]: filed as lfortran/lfortran#M (confirmed on base <sha>).
> - [bug]: already reported as #M.
>
> Reply with one line when done.

## 3. More work on a PR, only when the user asks

> The user asks for this on PR #<P> for issue #<N>: [a failing check: ... / a review comment: ... / a base conflict / a grouping decision: ...]. Handle it as `fix-issue` Phase 5d describes: reproduce, fix, rerun the suites once through the slot before pushing any change under `src/` or `grammar/`, then push with `publish_pr.sh <N> --push-only`. If the change adds a function or method, add it to the `New functions:` list of the PR description (machine.md, "The PR description") and update the PR body with `gh pr edit <P> --repo lfortran/lfortran --body-file - < .fix-issue/<N>/pr_body.md`. Draft replies to human comments in `round_<k>.md`; do not post them. Then stop; do not watch CI.

## Resume (replacement agent)

> You are taking over LFortran issue #<N> ("<title>") from an earlier agent. Read `<src>/.fix-issue/<N>/machine.md` completely, then `<src>/.agents/skills/fix-issue/SKILL.md`, then `state.md` and the other files in `<src>/.fix-issue/<N>/`, `git log` on the branch and, if a PR exists, `gh pr view`. Continue from the first step that is not finished. [Then the text of prompt 1, 1F, 1P or 3 that applies.]
