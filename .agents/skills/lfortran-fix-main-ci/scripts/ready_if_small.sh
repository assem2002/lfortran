#!/usr/bin/env bash
# Apply the size rule to a PR made by this skill (see ../SKILL.md, step 8).
# Run it after the PR is created and after every later push to it.
#
# Usage: ready_if_small.sh <PR>
#   At most MAX_LINES changed lines (additions + deletions, all files):
#       mark a draft ready for review and turn on auto-merge (merge commit).
#   More: leave it a draft. If auto-merge is on (an earlier run set it when
#       the PR was small), turn it off and make the PR a draft again. A PR
#       the user marked ready by hand, without auto-merge, is left alone.

set -u
repo=lfortran/lfortran
MAX_LINES=20
pr=${1:?usage: ready_if_small.sh <PR>}

read -r state draft added removed auto < <(gh pr view "$pr" --repo "$repo" \
    --json state,isDraft,additions,deletions,autoMergeRequest \
    --jq '"\(.state) \(.isDraft) \(.additions) \(.deletions) \(.autoMergeRequest != null)"') || exit 2
lines=$((added + removed))

if [ "$state" != OPEN ]; then
    echo "PR #$pr is $state; nothing done"
    exit 0
fi

if [ "$lines" -le $MAX_LINES ]; then
    echo "PR #$pr: $lines changed lines (+$added -$removed), limit $MAX_LINES: ready + auto-merge"
    if [ "$draft" = true ]; then
        gh pr ready "$pr" --repo "$repo" || exit 2
    fi
    gh pr merge "$pr" --repo "$repo" --auto --merge || exit 2
else
    echo "PR #$pr: $lines changed lines (+$added -$removed), over the limit $MAX_LINES: stays a draft"
    if [ "$auto" = true ]; then
        gh pr merge "$pr" --repo "$repo" --disable-auto || exit 2
        if [ "$draft" = false ]; then
            gh pr ready "$pr" --repo "$repo" --undo || exit 2
        fi
        echo "PR #$pr grew past the limit: auto-merge turned off, back to draft. Tell the user."
    fi
fi
gh pr view "$pr" --repo "$repo" --json isDraft,autoMergeRequest \
    --jq '"PR draft=\(.isDraft), auto-merge=\(.autoMergeRequest.mergeMethod // "off")"'
