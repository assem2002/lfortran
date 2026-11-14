#!/usr/bin/env bash
# Check a fix branch before it is pushed: fix-issue's "inspect all new commits"
# step plus this machine's test-name check.
# Usage: verify_branch.sh <issue-number>
# Shows the worktree state, the commits with author, the diff stat, the
# repository's AI-authorship check (must pass), each commit's "Fixes #N" line,
# test-name collisions, the push invariant, and whether the fork has the branch.

here=$(dirname "$(readlink -f "$0")")
. "$here/_lib.sh"
i=$1; b=$(branch_of "$i"); src=$(src_of "$i")
[ -n "$b" ] || { echo "no fix branch found for issue $i" >&2; exit 2; }
cd "$MAIN" || exit 2
[ -d "$src" ] && echo "source worktree: branch=[$(git -C "$src" branch --show-current)] dirty=$(git -C "$src" status --short | wc -l)"
base=$(git merge-base origin/main "$b")
echo "--- commits on $b (base $(git rev-parse --short "$base")):"
git log --format='%h %an <%ae> | %s' "$base..$b"
git diff --stat "$base" "$b" | tail -1
if [ -d "$src" ] && [ -f "$src/check_ai_commit_authorship.py" ]; then
    (cd "$src" && python check_ai_commit_authorship.py > /dev/null 2>&1) \
        && echo "authorship check: passed" || echo "authorship check: FAILED (run check_ai_commit_authorship.py in $src)"
fi
echo "attribution hits (want 0): $(git log --format=%B "$base..$b" | grep -ciE 'co-authored|co-author:|generated[- ]by|assisted[- ]by|generated with|claude code')"
git log --format='  %B' "$base..$b" | grep -E 'Fixes #|Fix #' | sort -u
echo "--- test names:"
"$here/check_test_names.sh" --branch "$b"
green=$(sed -n 's/^- suites_green_sha: *//p' "$src/.fix-issue/$i/state.md" 2>/dev/null | head -1)
if [ -z "$green" ]; then
    echo "--- push invariant: no suites_green_sha recorded in state.md"
elif git diff --quiet "$green" "$b" -- src grammar; then
    echo "--- push invariant: suites are current (green at ${green:0:10})"
else
    echo "--- push invariant: NOT current; src/ or grammar/ changed since ${green:0:10}, rerun the suites"
fi
fork=$(git ls-remote "$FORK" "refs/heads/$b" | cut -c1-10)
echo "--- fork: ${fork:-not pushed}  local: $(git rev-parse --short=10 "$b")"
