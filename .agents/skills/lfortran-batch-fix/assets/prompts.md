# Agent messages

One agent per issue, and its job ends when the draft PR is open. Start it once with prompt 1. Resume the SAME agent (SendMessage) with the later prompts only when there is something for it to do. Replace `<N>`, `<title>`, `<src>` and the bracketed parts. If the agent is gone or its context has grown too large, start a new `general-purpose` agent with the "Resume" prompt.

## 1. Start: from reproduction to the open draft PR (fix-issue Phases 2–4)

> You are the one agent for LFortran issue #<N> ("<title>"), from reproduction to an open draft PR.
>
> First read `<src>/.fix-issue/<N>/machine.md` completely with the Read tool. It gives your worktree, branch and the rules of this machine, and it overrides the repository's skills where they conflict. Then read `<src>/.agents/skills/fix-issue/SKILL.md` and `<src>/AGENTS.md`.
>
> Do `fix-issue` Phases 2 to 4 yourself, in one run:
> - Phase 2: reproduce with the `repro-issue` skill.
> - Phase 3: loop `create-mre` → `fix-mre` (targeted checks 5a) → the original-issue check (3c), one fix commit followed by one `test:` commit with its integration test per distinct bug (machine.md, "Tests go in their own commit"), until every program and scenario in the issue passes. Then run the suites once in the default mode (3d: unit, integration, reference) on the committed head and record `suites_green_sha` in `state.md`.
> - Review your whole branch once with the `pr-review` skill, as machine.md describes, and fix what it finds.
> - Phase 4: write `.fix-issue/<N>/pr_body.md` in the form machine.md gives under "The PR description" (the issue explained simply, then the fix; not `fix-issue`'s headings) and publish with `publish_pr.sh <N>`.
>
> Then stop. Do not watch CI and do not mark the PR ready.
>
> Authorized: commits on your branch with no co-author or AI-attribution lines, pushes to `myrepo`, and the draft PR against `lfortran/lfortran`. Not authorized: pushing to `origin`, filing issues, commenting anywhere, labels, marking ready.
> [Other issues being fixed now: #A, #B. If yours shares a root cause with one of them, or needs its fix, stop before publishing and say so.]
>
> Report as machine.md describes: the PR URL and head SHA (or why you stopped before publishing), the commit SHAs, the suite results against the baseline, what your review found and changed, anything it left open, and the Unrelated bugs list.

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

> You are taking over LFortran issue #<N> ("<title>") from an earlier agent. Read `<src>/.fix-issue/<N>/machine.md` completely, then `<src>/.agents/skills/fix-issue/SKILL.md`, then `state.md` and the other files in `<src>/.fix-issue/<N>/`, `git log` on the branch and, if a PR exists, `gh pr view`. Continue from the first step that is not finished. [Then the text of prompt 1 or 3 that applies.]
