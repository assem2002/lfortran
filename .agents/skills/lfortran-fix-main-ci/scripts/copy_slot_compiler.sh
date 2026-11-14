#!/usr/bin/env bash
# Copy the build slot's compiler to <dest>, so an MRE can be reduced with it
# without holding the slot. Run it through slot.sh from the source worktree at
# the commit you want:
#     cd $WORK/lfortran-src-<name>
#     <skills>/lfortran-batch-fix/scripts/slot.sh bash \
#         <skills>/lfortran-fix-main-ci/scripts/copy_slot_compiler.sh \
#         $WORK/tmp/<name>/lf
# ($WORK is the nvme partition set in lfortran-batch-fix/scripts/_lib.sh.)
# Then use <dest>/src/bin/lfortran. It finds its runtime library and intrinsic
# .mod files in <dest>/src/runtime. About 470 MB: delete <dest> when done.
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../lfortran-batch-fix/scripts/_lib.sh"
dst=${1:?usage: copy_slot_compiler.sh <dest under $WORK>}
: "${LFORTRAN_BUILD_DIR:?run this through slot.sh}"
case $dst in
    "$WORK"/*) ;;
    *) echo "copy_slot_compiler.sh: put <dest> on $WORK" >&2; exit 2 ;;
esac
if [ -e "$dst" ]; then
    echo "copy_slot_compiler.sh: $dst exists; remove it first or pick another" >&2
    exit 2
fi
mkdir -p "$dst/src/bin" "$dst/src/runtime"
cp "$LFORTRAN_BUILD_DIR/src/bin/lfortran" "$dst/src/bin/"
cp -a "$LFORTRAN_BUILD_DIR"/src/runtime/*.mod \
    "$LFORTRAN_BUILD_DIR"/src/runtime/liblfortran_runtime.so* "$dst/src/runtime/"
# --version may name an old commit (the slot never reruns build0.sh).
echo "built from: $(git log --oneline -1)$(git diff --quiet HEAD || echo ' + uncommitted changes')"
echo "compiler:   $dst/src/bin/lfortran"
df -h "$WORK" | tail -1
