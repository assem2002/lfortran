#!/usr/bin/env bash
# Put the shared build worktree at the latest upstream main, rebuilt, ready to
# serve as the build slot, and pin that commit as the batch's base. Creates and
# configures the worktree on first use.
#
# Usage: prepare_build_worktree.sh
#
# It also keeps a source-only worktree of the base (lfortran-src-base), which
# baseline.sh uses through the slot. Single-program checks on the base use the
# main build instead (build_main.sh, in ~/lfortran_test/lfortran).
# On first use it runs build0.sh plus build1.sh (with 12 jobs) and needs about
# 5 GB free on the nvme-9gb partition (check `df -h $WORK` first; NEVER put it
# on / or the NTFS HDD).
# If the worktree was deleted by hand, run `git worktree prune` first.

set -e
. "$(dirname "$(readlink -f "$0")")/_lib.sh"
need_work
mkdir -p "$STATE" "$WORK/tmp"
# gcc writes its temporary files to TMPDIR; keep them off /.
export TMPDIR=$WORK/tmp

git -C "$MAIN" fetch -q origin main
base=$(git -C "$MAIN" rev-parse origin/main)

if [ ! -d "$BUILD" ]; then
    git -C "$MAIN" worktree add --detach "$BUILD" "$base"
    cd "$BUILD"
    flock "$STATE/build.lock" bash -c "./build0.sh && CMAKE_BUILD_PARALLEL_LEVEL=$BUILD_JOBS ./build1.sh" \
        > "$STATE/initial_build.log" 2>&1
else
    cd "$BUILD"
    # Leftovers from the last slot user are fine to discard: every slot call
    # resets the worktree anyway. CMake writes the header in
    # src/lfortran/tests/Debug/ only when it configures, so keep it.
    flock "$STATE/build.lock" bash -c "git checkout -q -f --detach $base && git clean -fdq -e src/lfortran/tests/Debug/ && ninja -j$BUILD_JOBS" \
        > "$STATE/prepare_build.log" 2>&1
fi

if [ -d "$BASE_WT" ]; then
    git -C "$BASE_WT" checkout -q --detach "$base"
else
    git -C "$MAIN" worktree add -q --detach "$BASE_WT" "$base"
fi
echo "$base" > "$STATE/base_sha"
echo "build worktree $BUILD and $BASE_WT at ${base:0:10}, built (log in $STATE)"
df -h "$WORK" / | tail -2
