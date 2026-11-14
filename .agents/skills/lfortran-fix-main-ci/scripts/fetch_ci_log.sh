#!/usr/bin/env bash
# Save the log of a failed CI job of lfortran/lfortran and print what matters:
# the run, the failed step, the recent results of the same job on main, and
# the error lines.
# Usage: fetch_ci_log.sh <job URL>
#        fetch_ci_log.sh <run-id> <job-id>
# The log goes to ~/lfortran_test/ci_<run-id>/job_<job-id>.log.
# `gh run view --log` prints nothing on this machine, so this uses gh api.
set -euo pipefail
repo=lfortran/lfortran
if [[ $# -eq 1 && $1 =~ /runs/([0-9]+)/job/([0-9]+) ]]; then
    run=${BASH_REMATCH[1]}; job=${BASH_REMATCH[2]}
elif [[ $# -eq 2 ]]; then
    run=$1; job=$2
else
    echo "usage: fetch_ci_log.sh <job URL> | <run-id> <job-id>" >&2
    exit 2
fi
dir=$HOME/lfortran_test/ci_$run
mkdir -p "$dir"
log=$dir/job_$job.log

gh run view "$run" --repo $repo --json workflowName,headBranch,headSha,event,conclusion \
    --jq '"run: \(.workflowName) on \(.headBranch) \(.headSha[0:10]) (\(.event)): \(.conclusion)"'
jobname=$(gh api "repos/$repo/actions/jobs/$job" --jq .name)
echo "job: $jobname"
gh api "repos/$repo/actions/jobs/$job" \
    --jq '.steps[] | select(.conclusion=="failure") | "failed step: \(.name)"'

gh api "repos/$repo/actions/jobs/$job/logs" > "$log"
echo "log: $log ($(wc -l < "$log") lines)"

echo "--- this job on main, newest first (run, commit, result):"
wf=$(gh run view "$run" --repo $repo --json workflowName --jq .workflowName)
gh run list --repo $repo --workflow "$wf" --branch main --limit 8 \
    --json databaseId,headSha --jq '.[] | "\(.databaseId) \(.headSha)"' |
while read -r rid sha; do
    c=$(gh api "repos/$repo/actions/runs/$rid/jobs" --paginate \
        --jq ".jobs[] | select(.name==\"$jobname\") | .conclusion // \"running\"" 2>/dev/null | head -1)
    echo "  $rid ${sha:0:10} ${c:-not run}"
done

echo "--- error lines (timestamps cut):"
grep -n -E "Internal Compiler Error|Exception|AssertFailed|<ERROR>|##\[error\]|error stop|Error:" "$log" |
    sed -E 's/^([0-9]+:)[0-9T:.-]+Z /\1/' | cut -c1-240 | head -40
