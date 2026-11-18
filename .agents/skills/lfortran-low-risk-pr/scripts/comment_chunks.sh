#!/usr/bin/env bash
# Post one PR review with a comment on each low-risk chunk of the diff, after
# the model has judged the chunks (see ../SKILL.md). The script judges nothing.
#
# Usage:
#   comment_chunks.sh <PR> <comments.json>
# comments.json is a JSON array, one object per low-risk chunk:
#   {"path": "src/libasr/codegen/asr_to_llvm.cpp", "start_line": 29252,
#    "line": 29255, "side": "RIGHT", "kind": "unhandled_type_check",
#    "reason": "one line"}
# Lines are file line numbers on the PR head ("RIGHT") or, for a chunk that
# only deletes, on the base ("LEFT"). start_line may be left out for one line.
# A chunk that already has a current (not outdated) low-risk comment of the
# same kind on the same lines is skipped, so a rerun after a push adds only
# comments for new chunks.

set -u
repo=lfortran/lfortran
pr=${1:?usage: comment_chunks.sh <PR> <comments.json>}
input=${2:?usage: comment_chunks.sh <PR> <comments.json>}
me=$(gh api user --jq .login) || exit 2
head=$(gh pr view "$pr" --repo "$repo" --json headRefOid --jq .headRefOid) || exit 2

existing=$(gh api --paginate "repos/$repo/pulls/$pr/comments" \
    --jq "[.[] | select(.user.login == \"$me\" and .line != null
        and (.body | startswith(\"Low risk\")))
        | {path, line, start_line, body}]" | jq -s 'add // []') || exit 2

payload=$(jq --arg head "$head" --argjson existing "$existing" '
    def body: "Low risk (`\(.kind)`): \(.reason)";
    [ .[] | select(. as $c | ($existing | any(
            .path == $c.path and .line == $c.line
            and (.start_line // .line) == ($c.start_line // $c.line)
            and (.body | startswith("Low risk (`\($c.kind)`)")))) | not) ]
    | if length == 0 then empty else
      { commit_id: $head, event: "COMMENT", body: "",
        comments: [ .[] | {path, line, side: (.side // "RIGHT"), body: body}
            + (if (.start_line // .line) != .line
               then {start_line, start_side: (.side // "RIGHT")} else {} end) ] }
      end' < "$input") || exit 2

if [ -z "$payload" ]; then
    echo "PR #$pr: every low-risk chunk already has its comment; nothing posted."
    exit 0
fi
n=$(echo "$payload" | jq '.comments | length')
echo "$payload" | gh api --method POST "repos/$repo/pulls/$pr/reviews" --input - \
    --jq '"PR #'"$pr"': posted review \(.id) with '"$n"' low-risk comment(s): \(.html_url)"' || exit 2
