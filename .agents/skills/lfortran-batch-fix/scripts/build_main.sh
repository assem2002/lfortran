#!/usr/bin/env bash
# Build upstream main in the user's checkout ~/lfortran_test/lfortran (in-tree
# Debug build, LLVM 11 from the conda env lf), so that its src/bin/lfortran is
# the base compiler every check is compared against. The user chose this
# directory for it on 2026-10-25; it is the one LFortran build allowed on /.
#
# Usage: build_main.sh [<commit>]       (default: the latest origin/main)
#   In a batch, build the pinned base:
#       build_main.sh $(cat ~/lfortran_test/.batch-fix/base_sha)
#
# It changes nothing and exits 2 when the checkout has uncommitted changes to
# tracked files (ask the user what to do with them), or when / has less than
# MIN_FREE_MB free. Untracked files are left alone. The checkout is left
# detached at <commit>; the branch it was on is printed and kept.
# It waits in the build slot's queue, so it never builds at the same time as a
# slot call (RAM), and slot_status.sh shows it as "main-checkout".
# Exit 4 means the build failed; the log is $STATE/main_build.log.

set -u
. "$(dirname "$(readlink -f "$0")")/_lib.sh"
need_work
# Relinking libasr.a deletes it, writes it again and ranlib writes a full
# temporary copy, so it needs one archive size more, plus a margin.
archive_mb=$(( $(stat -c %s "$MAIN/src/libasr/libasr.a" 2>/dev/null || echo 3000000000) / 1048576 ))
MIN_FREE_MB=$((archive_mb + 300))
# Outputs of build0.sh are gitignored, so a checkout leaves them stale.
GEN_INPUTS=(build0.sh grammar/AST.asdl src/libasr/ASR.asdl src/libasr/asdl_cpp.py
    src/libasr/wasm_instructions.txt src/libasr/wasm_instructions_visitor.py
    src/libasr/intrinsic_func_registry_util_gen.py src/lfortran/parser/tokenizer.re
    src/lfortran/parser/preprocessor.re src/lfortran/parser/parser.yy src/server/generator)

cd "$MAIN" || exit 2
if ! git diff --quiet HEAD; then
    echo "build_main.sh: $MAIN has uncommitted changes to tracked files; nothing done. Ask the user:" >&2
    git status --short --untracked-files=no >&2
    exit 2
fi
free=$(df --output=avail -m / | tail -1)
if [ "$free" -lt $MIN_FREE_MB ]; then
    echo "build_main.sh: / has ${free} MB free, less than $MIN_FREE_MB MB; nothing done. Tell the user." >&2
    exit 2
fi
git fetch -q origin main || exit 2
target=$(git rev-parse --verify "${1:-origin/main}^{commit}") || exit 2

QUEUE=$STATE/queue CURRENT=$STATE/slot_current HISTORY=$STATE/slot_history.log
mkdir -p "$QUEUE" "$WORK/tmp"
name=main-checkout what="build main at ${target:0:10}" log=$STATE/main_build.log
log_event() { printf '%s\t%s\t%s\n' "$(date '+%F %T')" "$name" "$1" >> "$HISTORY"; }
ticket=$QUEUE/$(date +%s%N)_$$
leave() {
    rm -f "$ticket" "$CURRENT.$$"
    [ "$(cut -f2 "$CURRENT" 2>/dev/null)" = "$$" ] && rm -f "$CURRENT"
}
trap leave EXIT
trap 'exit 130' INT TERM
printf '%s\t%s\t%s\t%s\n' "$name" "$$" "$(date +%s)" "$what" > "$QUEUE/.tmp.$$" && mv "$QUEUE/.tmp.$$" "$ticket"
# The same first-come-first-served wait as build_slot.sh.
while :; do
    first=
    for t in "$QUEUE"/*; do
        [ -e "$t" ] || continue
        pid=$(cut -f2 "$t" 2>/dev/null)
        if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then rm -f "$t"; continue; fi
        first=$t; break
    done
    [ "$first" = "$ticket" ] && break
    sleep 3
done
exec 9> "$STATE/build.lock"
flock 9
printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$$" "$(date +%s)" building "$what" > "$CURRENT.$$" && mv "$CURRENT.$$" "$CURRENT"
started=$(date +%s)
log_event "building: $what"

old=$(git rev-parse HEAD)
was=$(git symbolic-ref -q --short HEAD || echo "detached at ${old:0:10}")
git checkout -q --detach "$target" || exit 2
# gcc writes its temporary files to TMPDIR; keep them off /.
export TMPDIR=$WORK/tmp
: > "$log"
# The lf env's old `shell` breaks configure since upstream bd263f9eba.
if ! grep -q '^LFORTRAN_SHELL:' CMakeCache.txt; then
    cmake -DLFORTRAN_SHELL=/usr/bin/bash . >> "$log" 2>&1 || { echo "build_main.sh: cmake failed, see $log" >&2; exit 4; }
elif ! git diff --quiet "$old" "$target" -- "${GEN_INPUTS[@]}"; then
    bash ./build0.sh >> "$log" 2>&1 || { echo "build_main.sh: build0.sh failed, see $log" >&2; exit 4; }
fi
if ! ninja -j"$BUILD_JOBS" >> "$log" 2>&1; then
    echo "build_main.sh: BUILD FAILED at ${target:0:10}, see $log; last lines:" >&2
    grep -E "error|FAILED" "$log" | head -20 >&2
    log_event "build FAILED after $(($(date +%s) - started))s"
    exit 4
fi
log_event "done rc=0 (build $(($(date +%s) - started))s)"
echo "main build OK: $MAIN at ${target:0:10} (was $was); compiler $MAIN/src/bin/lfortran"
df -h / | tail -1
