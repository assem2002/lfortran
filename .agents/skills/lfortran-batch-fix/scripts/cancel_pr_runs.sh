#!/usr/bin/env bash
# Cancel queued or running GitHub Actions runs of the given upstream PRs.
# Usage: cancel_pr_runs.sh <PR> [<PR> ...]
# It matches runs by each PR's exact head commit, so other people's runs on
# same-named branches are never touched.
# Note: a PR whose base merge conflicts gets no pull_request runs at all; if one
# shows none, check `gh pr view N --json mergeable`.

R=lfortran/lfortran
for pr in "$@"; do
    read -r sha branch < <(gh pr view "$pr" -R $R --json headRefOid,headRefName --jq '"\(.headRefOid) \(.headRefName)"')
    ids=$(gh run list -R $R --commit "$sha" --limit 50 --json databaseId,status,name \
          --jq '.[] | select(.status != "completed") | "\(.databaseId)\t\(.name)"')
    if [ -z "$ids" ]; then
        echo "#$pr ($branch): no queued or running runs ($(gh pr view "$pr" -R $R --json mergeable --jq .mergeable))"
        continue
    fi
    while IFS=$'\t' read -r id name; do
        if gh run cancel "$id" -R $R > /dev/null 2>&1; then echo "#$pr: cancelled $id ($name)"; else echo "#$pr: FAILED to cancel $id ($name)"; fi
    done <<< "$ids"
done
