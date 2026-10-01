# CI label-noise test

Scratch file for a throwaway pull request on the fork. It exists only to give
the PR a diff so label events can be exercised against
`.github/workflows/Exhaustive-Checks-Trigger.yml` and
`.github/workflows/Exhaustive-Checks-Cleanup.yml`.

Expected behaviour when labels are changed on the PR:

1. Add `Tests::Run-Exhaustive` — the suite starts.
2. Add any other label while it runs — the suite is **not** cancelled and not
   re-run, and the no-op run that GitHub dispatches is deleted by the cleanup
   workflow, so only one "Exhaustive checks" entry remains.

Delete this file and the branch once the behaviour is confirmed.
