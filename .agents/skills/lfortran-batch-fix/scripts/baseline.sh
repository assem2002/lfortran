#!/usr/bin/env bash
# Run the suites once, in the default mode, on the pinned upstream main, so
# every job can tell a failure that is already on main from its own regression.
# fix-issue gets this from each job's own build of main; with one shared build
# a single baseline per batch is the cheap equivalent.
#
# Usage: baseline.sh      (after prepare_build_worktree.sh, with the slot open)
# It queues for the slot like any job and takes about 6 minutes there.
# Writes $STATE/baseline_<sha>_{unit,integration,reference}.log.

. "$(dirname "$(readlink -f "$0")")/_lib.sh"
slot=$(dirname "$(readlink -f "$0")")/slot.sh
sha=$(git -C "$BASE_WT" rev-parse --short=10 HEAD) || exit 2
p=$STATE/baseline_$sha

cd "$BASE_WT" || exit 2
"$slot" bash -c "
  '$slot' ctest > '${p}_unit.log' 2>&1; echo unit_exit=\$?
  '$slot' integration_tests > '${p}_integration.log' 2>&1; echo integration_exit=\$?
  '$slot' tests > '${p}_reference.log' 2>&1; echo reference_exit=\$?"
grep -h "tests passed" "${p}_unit.log" "${p}_integration.log"
grep -hE "TESTS PASSED|TESTS FAILED" "${p}_reference.log" | tail -1
echo "baseline logs: ${p}_{unit,integration,reference}.log"
