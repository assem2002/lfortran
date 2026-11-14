# Shared settings and helpers; source it, don't run it.
# This is the one place for this machine's paths. Every value can be changed
# with the BATCH_FIX_* variable named next to it.
STATE=${BATCH_FIX_STATE:-$HOME/lfortran_test/.batch-fix}
# The build slot and the source worktrees live on the nvme-9gb partition (the user's choice, 2026-10-20).
WORK=${BATCH_FIX_WORK:-/media/assem/nvme-9gb}
BUILD=${BATCH_FIX_BUILD:-$WORK/lfortran-fixes}
MAIN=${BATCH_FIX_MAIN:-$HOME/lfortran_test/lfortran}
BASE_WT=${BATCH_FIX_BASE_WT:-$WORK/lfortran-src-base}
JOBS=${BATCH_FIX_JOBS:-8}
BUILD_JOBS=${BATCH_FIX_BUILD_JOBS:-8}
FORK=${BATCH_FIX_FORK:-myrepo}
# Reproducers saved while picking issues: <dir>/<N>/re0.f90.
ISSUES_DIR=${BATCH_FIX_ISSUES_DIR:-$HOME/lfortran_test/lfortran-fixable-issues}
# The folder that holds this skill and its sibling skills.
SKILLS=$(dirname "$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")")
# The scripts need python from the conda env lf.
LF_ENV=${BATCH_FIX_CONDA_ENV:-$HOME/conda_root/envs/lf}
case ":$PATH:" in *":$LF_ENV/bin:"*) ;; *) export PATH=$LF_ENV/bin:$PATH CONDA_PREFIX=$LF_ENV ;; esac

# The fix branch of an issue: fix/<N>-<slug>, or fix/issue-<N> from older batches.
branch_of() {
    git -C "$MAIN" for-each-ref --format='%(refname:short)' \
        "refs/heads/fix/$1-*" "refs/heads/fix/issue-$1" | head -1
}
src_of() { echo "$WORK/lfortran-src-$1"; }
# The desktop automounter mounts the partition (there is no /etc/fstab entry); never fall back to / or the HDD.
need_work() {
    [ -d "$WORK" ] && [ -w "$WORK" ] \
        || { echo "$WORK is not mounted; mount the nvme-9gb partition first" >&2; exit 2; }
}
