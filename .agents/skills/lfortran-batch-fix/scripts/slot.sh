#!/usr/bin/env bash
# The stand-in for `pixi run -e llvm11 ...` on this machine, which has no Pixi
# and room for only one LFortran build. Wherever the repository's skills or
# AGENTS.md say
#     pixi run -e llvm11 <task or command> [args]
# run, from inside your source worktree,
#     slot.sh <task or command> [args]
#
# It queues for the shared build slot (see build_slot.sh), rebuilds the slot to
# the calling worktree's HEAD plus uncommitted changes, then runs:
#   build | rebuild      nothing more (the rebuild is the task)
#   start ARGS           the built lfortran with ARGS, in the current directory
#   tests ARGS           the reference suite, from the worktree, LLVM 11 required
#   integration_tests ARGS   the integration suite, from the worktree
#   ctest ARGS           the unit tests
#   gfortran | llvm-config   directly, without the queue (no LFortran build needed)
#   anything else        that command, in the current directory, with the built
#                        compiler first on PATH and LFORTRAN_BUILD_DIR set
# Test tasks are pinned to 8 cores and get -j8 unless a smaller -j is given.
# Called from inside a slot command, it runs at once without queueing again.
#
# Environment overrides: BATCH_FIX_STATE, BATCH_FIX_WORK, BATCH_FIX_BUILD, BATCH_FIX_MAIN, BATCH_FIX_JOBS.
# BATCH_FIX_DRY=1 prints the command that would run and exits.

WORK=${BATCH_FIX_WORK:-/media/assem/nvme-9gb}
BUILD=${BATCH_FIX_BUILD:-$WORK/lfortran-fixes}
MAIN=${BATCH_FIX_MAIN:-$HOME/lfortran_test/lfortran}
JOBS=${BATCH_FIX_JOBS:-8}
here=$(dirname "$(readlink -f "$0")")
# The slot was configured inside the conda env lf; its suites need that python, cmake and ctest.
LF_ENV=${BATCH_FIX_CONDA_ENV:-$HOME/conda_root/envs/lf}
case ":$PATH:" in *":$LF_ENV/bin:"*) ;; *) export PATH=$LF_ENV/bin:$PATH CONDA_PREFIX=$LF_ENV ;; esac

[ "${1:-}" = run ] && shift
if [ "${1:-}" = -e ]; then
    [ "${2:-}" = llvm11 ] || { echo "slot.sh: only the llvm11 configuration exists on this machine" >&2; exit 2; }
    shift 2
fi
[ $# -ge 1 ] || { echo "usage: slot.sh <task or command> [args]   (see the header of $0)" >&2; exit 2; }
task=$1; shift
args=("$@")

case "$task" in
    gfortran|llvm-config) exec "$task" "${args[@]}" ;;
esac

SRC=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "slot.sh: run it from inside your source worktree" >&2; exit 2; }
if [ "$SRC" = "$(readlink -f "$BUILD")" ] || [ "$SRC" = "$(readlink -f "$MAIN")" ]; then
    echo "slot.sh: $SRC is not a source worktree; run it from $WORK/lfortran-src-<N>" >&2
    exit 2
fi

cap_jobs() {
    local out=() seen=0 i a n
    for ((i = 0; i < ${#args[@]}; i++)); do
        a=${args[i]}
        if [[ $a =~ ^-j([0-9]+)$ ]]; then
            n=${BASH_REMATCH[1]}; ((n > JOBS)) && n=$JOBS
            out+=("-j$n"); seen=1
        elif [[ $a == -j && ${args[i+1]:-} =~ ^[0-9]+$ ]]; then
            n=${args[i+1]}; ((n > JOBS)) && n=$JOBS
            out+=(-j "$n"); seen=1; i=$((i + 1))
        else
            case "$a" in -s|--sequential|--jobs|--jobs=*|-n|--no_of_threads) seen=1 ;; esac
            out+=("$a")
        fi
    done
    ((seen)) || out+=("-j$JOBS")
    args=("${out[@]}")
}
pin=(taskset -c "0-$((JOBS - 1))")

cwd=$PWD
case "$task" in
    build|rebuild)
        cmd=() ;;
    clean)
        echo "slot.sh: the build slot is shared; it is never cleaned by a job" >&2; exit 2 ;;
    start)
        cmd=("$BUILD/src/bin/lfortran" "${args[@]}") ;;
    ctest)
        cap_jobs
        cmd=("${pin[@]}" ctest --test-dir "$BUILD" --output-on-failure "${args[@]}") ;;
    tests)
        cap_jobs; cwd=$SRC
        ref=$BUILD/build/slot/reference_tests
        # The runner reuses (and empties) a build directory only if its `tests`
        # link points at the calling tree, so hand the shared one over first.
        cmd=(bash -c '[ -L "$2/tests" ] && ln -sfn "$1/tests" "$2/tests"; shift 2; exec "$@"' _ "$SRC" "$ref"
             "${pin[@]}" python run_tests.py --require-llvm 11 --compiler-dir "$BUILD/src/bin"
             --build-dir "$ref" "${args[@]}") ;;
    integration_tests)
        cap_jobs; cwd=$SRC/integration_tests
        cmd=("${pin[@]}" python run_tests.py --build-dir "$BUILD/build/slot/integration_tests"
             --compiler-dir "$BUILD/src/bin" "${args[@]}") ;;
    *)
        cmd=("$task" "${args[@]}") ;;
esac

if [ -n "${BATCH_FIX_DRY:-}" ]; then
    printf 'cwd: %s\ncmd:' "$cwd"; printf ' %q' "${cmd[@]}"; echo
    exit 0
fi
if [ -n "${BATCH_FIX_IN_SLOT:-}" ]; then
    if [ "$BATCH_FIX_IN_SLOT" != "$SRC" ]; then
        echo "slot.sh: this slot call was built for $BATCH_FIX_IN_SLOT, not $SRC" >&2; exit 2
    fi
    [ ${#cmd[@]} -eq 0 ] && exit 0
    cd "$cwd" || exit 2
    exec "${cmd[@]}"
fi

label="$task ${args[*]}"
export BATCH_FIX_CWD=$cwd BATCH_FIX_LABEL=${label:0:160}
if [ ${#cmd[@]} -eq 0 ]; then
    exec "$here/build_slot.sh" "$SRC"
fi
exec "$here/build_slot.sh" "$SRC" -- "${cmd[@]}"
