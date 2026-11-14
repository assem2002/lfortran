#!/usr/bin/env bash
# fix-issue's Phase 4 push and draft PR, with its preconditions enforced.
# Usage: publish_pr.sh <issue-number> [--title "<title>"] [--push-only]
#
# Refuses unless: the worktree is clean, the repository's AI-authorship check
# passes, the local suites are current for src/ and grammar/ (the push
# invariant: `- suites_green_sha: <sha>` in state.md), and the new test names
# are free. Then it pushes the branch to the fork (`myrepo`, never `origin`)
# and, unless the PR already exists or --push-only is given, opens a draft PR
# against lfortran/lfortran from .fix-issue/<N>/pr_body.md. The title defaults
# to the commit subject when the branch has one commit.

set -e
. "$(dirname "$(readlink -f "$0")")/_lib.sh"
here=$(dirname "$(readlink -f "$0")")
i=$1; shift
title=; push_only=no
while [ $# -gt 0 ]; do
    case "$1" in
        --title) title=$2; shift 2 ;;
        --push-only) push_only=yes; shift ;;
        *) echo "unknown argument $1" >&2; exit 2 ;;
    esac
done
b=$(branch_of "$i"); src=$(src_of "$i"); st=$src/.fix-issue/$i
[ -n "$b" ] && [ -d "$src" ] || { echo "no branch or worktree for issue $i" >&2; exit 2; }
[ "$(git -C "$src" rev-parse HEAD)" = "$(git -C "$MAIN" rev-parse "$b")" ] || { echo "$src is not at the tip of $b" >&2; exit 1; }
[ -z "$(git -C "$src" status --short)" ] || { echo "$src has uncommitted changes" >&2; exit 1; }
(cd "$src" && python check_ai_commit_authorship.py) || { echo "the AI-authorship check failed" >&2; exit 1; }
green=$(sed -n 's/^- suites_green_sha: *//p' "$st/state.md" 2>/dev/null | head -1)
[ -n "$green" ] || { echo "state.md has no suites_green_sha; run the suites first" >&2; exit 1; }
git -C "$src" diff --quiet "$green" HEAD -- src grammar \
    || { echo "src/ or grammar/ changed since the suites passed at ${green:0:10}; rerun them first" >&2; exit 1; }
"$here/check_test_names.sh" --branch "$b" || { echo "a test name is taken; rename the test and its modules" >&2; exit 1; }

# --force-with-lease: a rebased branch must replace the old one on the fork.
git -C "$src" push --force-with-lease -u "$FORK" "$b" 2>&1 | tail -1
[ "$(git -C "$src" rev-parse "$FORK/$b" 2>/dev/null)" = "$(git -C "$src" rev-parse HEAD)" ] \
    || { echo "the push to $FORK failed; the fork does not have HEAD" >&2; exit 1; }
head=$(git -C "$src" rev-parse HEAD)
login=$(gh api user --jq .login)
pr=$(gh pr list -R lfortran/lfortran --state open --head "$b" --json url,headRepositoryOwner \
     --jq ".[] | select(.headRepositoryOwner.login == \"$login\") | .url" | head -1)
if [ -z "$pr" ] && [ $push_only = no ]; then
    [ -s "$st/pr_body.md" ] || { echo "$st/pr_body.md is missing" >&2; exit 1; }
    if [ -z "$title" ]; then
        base=$(git -C "$src" merge-base origin/main HEAD)
        [ "$(git -C "$src" rev-list --count "$base..HEAD")" = 1 ] \
            || { echo "several commits: pass --title \"fix: ...\"" >&2; exit 1; }
        title=$(git -C "$src" log -1 --format=%s)
    fi
    pr=$(cd "$HOME" && gh pr create -R lfortran/lfortran --base main --head "$login:$b" --draft \
         --title "$title" --body-file - < "$st/pr_body.md")
fi
if [ -n "$pr" ]; then
    gh api -X PATCH "repos/lfortran/lfortran/pulls/${pr##*/}" -F maintainer_can_modify=true --silent \
        || echo "could not turn on maintainer edits for $pr" >&2
fi
sed -i "s|^- last_pushed_sha:.*|- last_pushed_sha: $head|; s|^- pr:.*|- pr: ${pr:-none yet}|" "$st/state.md"
echo "pushed $b at ${head:0:10}; PR: ${pr:-none yet}"
