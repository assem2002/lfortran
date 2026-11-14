#!/usr/bin/env bash
# Apply the low-risk handling to one LFortran PR, after the model has read the
# PR's diff and judged it (see ../SKILL.md). The script does not judge anything.
#
# Usage:
#   mark_low_risk.sh <PR> <kind> "<one-line reason>"
#       The PR is low risk: add the "low risk" label, write it to
#       ../low_risk_prs.txt, mark a draft ready and turn on auto-merge.
#   mark_low_risk.sh <PR> --unmark
#       The PR had the label but is no longer low risk: remove the label,
#       turn auto-merge off and remove it from the register.

set -u
repo=lfortran/lfortran
label="low risk"
pr=${1:?usage: mark_low_risk.sh <PR> <kind> \"<reason>\" | mark_low_risk.sh <PR> --unmark}
kind=${2:?usage: mark_low_risk.sh <PR> <kind> \"<reason>\" | mark_low_risk.sh <PR> --unmark}
here=$(dirname "$(readlink -f "$0")")
registry=$(dirname "$here")/low_risk_prs.txt
touch "$registry"

if [ "$kind" = --unmark ]; then
    gh pr edit "$pr" --repo "$repo" --remove-label "$label" > /dev/null
    gh pr merge "$pr" --repo "$repo" --disable-auto 2>/dev/null || true
    sed -i "/^$pr /d" "$registry"
    echo "PR #$pr: removed \"$label\", turned auto-merge off, removed it from $registry. Tell the user."
    exit 0
fi

reason=${3:?give a one-line reason for the verdict}

state=$(gh pr view "$pr" --repo "$repo" --json state,isDraft --jq '"\(.state) \(.isDraft)"') || exit 2
gh pr edit "$pr" --repo "$repo" --add-label "$label" > /dev/null || exit 2
if ! grep -q "^$pr " "$registry"; then
    title=$(gh pr view "$pr" --repo "$repo" --json title --jq .title)
    echo "$pr $(date +%F) $kind $title | $reason" >> "$registry"
fi
case $state in
    "OPEN true") gh pr ready "$pr" --repo "$repo" || exit 2 ;;
    "OPEN false") ;;
    *) echo "PR #$pr is ${state%% *}; only the label was added"; exit 0 ;;
esac
gh pr merge "$pr" --repo "$repo" --auto --merge || exit 2
gh pr view "$pr" --repo "$repo" --json isDraft,labels,autoMergeRequest \
    --jq '"PR draft=\(.isDraft), labels=\([.labels[].name] | join(",")), auto-merge=\(.autoMergeRequest.mergeMethod // "off")"'
