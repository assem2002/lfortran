#!/usr/bin/env bash
# Build and run a source-only worktree's current state in the ONE shared,
# fully built LFortran worktree. Only one build or test run happens at a time,
# so RAM stays within budget on this machine.
#
# Usage: build_slot.sh <source-worktree> [-- command ...]
# Agents normally call it through slot.sh, the stand-in for `pixi run -e llvm11`.
#
# Callers are served first come, first served: each call takes a ticket in
# $STATE/queue and waits until it is the oldest one. `slot_status.sh` shows who
# holds the slot (building or testing), who waits and in which order.
#
# Holding the shared build lock for the whole call, it:
#   1. resets the build worktree to <source-worktree>'s HEAD commit,
#   2. applies that worktree's uncommitted changes, including untracked
#      non-ignored files such as a new integration test,
#   3. rebuilds incrementally with `ninja -j8`,
#   4. runs the optional command with this build's compiler first on PATH and
#      LFORTRAN_BUILD_DIR and LFORTRAN pointing at it, as Pixi activation does.
# Anything that needs this compiler (running lfortran on a reproducer, test
# suites) must be that command, because the next caller replaces the build.
#
# Exit codes: 3 if the slot is not open yet, 4 if the build failed,
# otherwise the command's exit code.
#
# Paths and job counts come from _lib.sh. Also read from the environment:
#   BATCH_FIX_CWD    directory to run the command in (default: the build worktree)
#   BATCH_FIX_LABEL  short text shown by slot_status.sh instead of the command

. "$(dirname "$(readlink -f "$0")")/_lib.sh"
LOCK=$STATE/build.lock
OPEN=$STATE/build_slot.open
QUEUE=$STATE/queue
CURRENT=$STATE/slot_current
HISTORY=$STATE/slot_history.log

[ $# -ge 1 ] || { echo "usage: $0 <source-worktree> [-- command ...]" >&2; exit 2; }
SRC=$(cd "$1" && pwd) || exit 2
shift
[ "${1:-}" = "--" ] && shift
mkdir -p "$STATE" "$QUEUE"
name=$(basename "$SRC")
what=${BATCH_FIX_LABEL:-${*:-build only}}
what=${what//[$'\t\n']/ }
case "$* $what" in
    *run_tests.py*|*ctest*|*" tests "*|*integration_tests*) work=testing ;;
    *) work=running ;;
esac

waited=0
until [ -f "$OPEN" ]; do
    if [ $waited -ge 540 ]; then
        echo "build slot not open yet (the build worktree is owned by someone else); call again later" >&2
        exit 3
    fi
    sleep 15; waited=$((waited + 15))
done

# Ticket names sort by arrival time, so the oldest live ticket is served next.
queued=$(date +%s)
ticket=$QUEUE/$(date +%s%N)_$$
log_event() { printf '%s\t%s\t%s\n' "$(date '+%F %T')" "$name" "$1" >> "$HISTORY"; }
set_phase() {
    printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$$" "$(date +%s)" "$1" "$what" > "$CURRENT.$$" \
        && mv "$CURRENT.$$" "$CURRENT"
}
leave() {
    rm -f "$ticket" "$CURRENT.$$"
    [ "$(cut -f2 "$CURRENT" 2>/dev/null)" = "$$" ] && rm -f "$CURRENT"
}
trap leave EXIT
trap 'exit 130' INT TERM
printf '%s\t%s\t%s\t%s\n' "$name" "$$" "$queued" "$what" > "$QUEUE/.tmp.$$" && mv "$QUEUE/.tmp.$$" "$ticket"

while :; do
    first=
    for t in "$QUEUE"/*; do
        [ -e "$t" ] || continue
        pid=$(cut -f2 "$t" 2>/dev/null)
        # A caller that was killed leaves its ticket behind.
        if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then rm -f "$t"; continue; fi
        first=$t; break
    done
    [ "$first" = "$ticket" ] && break
    sleep 3
done

# prepare_build_worktree.sh takes this lock without a ticket.
exec 9> "$LOCK"
flock 9
started=$(date +%s)
set_phase building
log_event "building after waiting $((started - queued))s: $what"

log=$STATE/slot_ninja_$name.log
cd "$BUILD" || exit 2
git checkout -q -f --detach "$(git -C "$SRC" rev-parse HEAD)" || exit 2
# CMake writes this header into the source tree only when it configures.
git clean -fdq -e src/lfortran/tests/Debug/ || exit 2
if ! git -C "$SRC" diff --quiet HEAD; then
    git -C "$SRC" diff --binary HEAD | git apply || { echo "applying the uncommitted changes failed" >&2; exit 2; }
fi
(cd "$SRC" && git ls-files -o --exclude-standard -z | xargs -0 -r cp --parents -t "$BUILD") || exit 2

echo "[build_slot] building $name at $(git rev-parse --short HEAD) + uncommitted changes" >&2
# gcc writes its temporary files to TMPDIR; keep them off /.
mkdir -p "$WORK/tmp"
if ! TMPDIR=$WORK/tmp ninja -j"$BUILD_JOBS" > "$log" 2>&1; then
    echo "[build_slot] BUILD FAILED, see $log; last lines:" >&2
    grep -E "error|FAILED" "$log" | head -20 >&2
    log_event "build FAILED after $(($(date +%s) - started))s"
    exit 4
fi
built=$(date +%s)
echo "[build_slot] build OK" >&2

rc=0
if [ $# -gt 0 ]; then
    set_phase "$work"
    if [ -n "${BATCH_FIX_CWD:-}" ]; then cd "$BATCH_FIX_CWD" || exit 2; fi
    BATCH_FIX_IN_SLOT=$SRC LFORTRAN_BUILD_DIR=$BUILD LFORTRAN=$BUILD/src/bin/lfortran \
        PATH="$BUILD/src/bin:$PATH" "$@"
    rc=$?
fi
log_event "done rc=$rc (build $((built - started))s, $work $(($(date +%s) - built))s)"
exit $rc
