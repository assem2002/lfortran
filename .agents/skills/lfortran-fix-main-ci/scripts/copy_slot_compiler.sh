#!/usr/bin/env bash
# Copy the build slot's compiler to <dest>, so an MRE can be reduced with it
# without holding the slot. Run it through slot.sh from the source worktree at
# the commit you want:
#     cd /media/assem/nvme-9gb/lfortran-src-<name>
#     ~/.claude/skills/lfortran-batch-fix/scripts/slot.sh bash \
#         ~/.claude/skills/lfortran-fix-main-ci/scripts/copy_slot_compiler.sh \
#         /media/assem/nvme-9gb/tmp/<name>/lf
# Then use <dest>/src/bin/lfortran. It finds its runtime library and intrinsic
# .mod files in <dest>/src/runtime. About 470 MB: delete <dest> when done.
set -euo pipefail
dst=${1:?usage: copy_slot_compiler.sh <dest under /media/assem/nvme-9gb>}
: "${LFORTRAN_BUILD_DIR:?run this through slot.sh}"
case $dst in
    /media/assem/nvme-9gb/*) ;;
    *) echo "copy_slot_compiler.sh: put <dest> on /media/assem/nvme-9gb" >&2; exit 2 ;;
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
df -h /media/assem/nvme-9gb | tail -1
