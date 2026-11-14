#!/usr/bin/env bash
# Check that integration test names are free: not on origin/main, not added by
# another local fix/* branch, and not in another open upstream PR.
#
# Usage:
#   check_test_names.sh <name> [<name> ...]     e.g. intrinsics_483 array_op_14
#   check_test_names.sh --branch fix/N-slug    checks the tests that branch adds,
#                                               plus the module names inside them
#
# Why: agents number tests from origin/main, so two in-flight branches (or other
# people's PRs) can pick the same intrinsics_NNN. Same-named modules inside two
# tests (e.g. operator_overloading_41_mod) can also clash once both are merged.

. "$(dirname "$(readlink -f "$0")")/_lib.sh"
cd "$MAIN" || exit 2
names=(); self=""
if [ "${1:-}" = "--branch" ]; then
    self=$2
    base=$(git merge-base origin/main "$self")
    for f in $(git diff --name-only --diff-filter=AR "$base" "$self" -- 'integration_tests/*.f90'); do
        names+=("$(basename "$f" .f90)")
        mods=$(git show "$self:$f" | grep -ioE '^\s*module\s+[a-z0-9_]+' | awk '{print $2}' | grep -iv '^procedure$')
        for m in $mods; do
            hits=$(git grep -il "^\s*module\s\+$m\b" origin/main -- integration_tests 2>/dev/null | head -3 | tr '\n' ' ')
            [ -n "$hits" ] && echo "MODULE CLASH: $m (in $f) also defined on main: $hits"
        done
    done
else
    names=("$@")
fi
[ ${#names[@]} -gt 0 ] || { echo "no test names to check"; exit 0; }

prs=$(gh pr list -R lfortran/lfortran --state open --limit 200 --json number,headRefName,files \
      --jq '.[] | "\(.number)\t\(.headRefName)\t\([.files[].path]|join(" "))"' 2>/dev/null)
[ -n "$prs" ] || echo "WARNING: could not list open PRs (GitHub API error?); retry"

status=0
for n in "${names[@]}"; do
    f=integration_tests/$n.f90
    out=""
    git cat-file -e "origin/main:$f" 2>/dev/null && out+="main "
    for b in $(git for-each-ref --format='%(refname:short)' 'refs/heads/fix/*'); do
        [ "$b" = "$self" ] && continue
        git diff --name-only --diff-filter=AR "$(git merge-base origin/main "$b")" "$b" | grep -qx "$f" && out+="$b "
    done
    out+=$(awk -F'\t' -v f="$f" -v self="$self" '$2 != self { n=split($3,a," "); for(i=1;i<=n;i++) if(a[i]==f) printf "PR#%s ", $1 }' <<< "$prs")
    if [ -n "$out" ]; then echo "TAKEN: $n -> $out"; status=1; else echo "free:  $n"; fi
done
exit $status
