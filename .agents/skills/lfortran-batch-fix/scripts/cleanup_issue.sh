#!/usr/bin/env bash
# Remove an issue's source worktree once its PR is merged or closed, or when
# the disk is needed. fix-issue leaves worktrees in place; here each one is
# about 85 MB on a nearly full disk, so they are removed when no longer used.
# Usage: cleanup_issue.sh <issue-number>
# Refuses if the worktree has uncommitted changes or the fork lacks the branch
# tip. The branch itself and the fork are left alone; the state directory
# (.fix-issue/<N>/) is saved to $STATE/done/<N>/ first.

set -e
. "$(dirname "$(readlink -f "$0")")/_lib.sh"
i=$1; b=$(branch_of "$i"); src=$(src_of "$i")
[ -d "$src" ] || { echo "$src does not exist"; exit 0; }
[ -z "$(git -C "$src" status --short)" ] || { echo "$src is not clean; aborting" >&2; exit 1; }
if [ -n "$b" ]; then
    [ "$(git -C "$MAIN" ls-remote "$FORK" "refs/heads/$b" | cut -f1)" = "$(git -C "$MAIN" rev-parse "$b")" ] \
        || { echo "$FORK does not have the tip of $b; push it first" >&2; exit 1; }
fi
if [ -d "$src/.fix-issue/$i" ]; then
    mkdir -p "$STATE/done"
    rm -rf "$STATE/done/$i"
    cp -r "$src/.fix-issue/$i" "$STATE/done/$i"
fi
git -C "$MAIN" worktree remove --force "$src"
echo "removed $src (state kept in $STATE/done/$i)"
