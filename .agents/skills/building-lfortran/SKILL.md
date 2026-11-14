---
name: building_lfortran
description: Where and how to build LFortran (or anything large compiled from Fortran) on this machine - always on the nvme-9gb partition at /media/assem/nvme-9gb, never on / or the NTFS HDD (one exception: the latest-main build in ~/lfortran_test/lfortran, made only by the batch-fix skill's build_main.sh), with at most 8 build threads and 8 test threads. Use it whenever you build LFortran, make a worktree that will be built, or run a test suite, also outside the batch-fix workflow.
---

Build with at most 8 threads (`-j8`, since 2026-10-21; it was 12); test suites also at 8 (`-j8`). Using more could stall my machine.
Use lowest model to do this skill to save on credits.

## Where to build: the nvme-9gb partition

Since 2026-10-20 every build goes on the `nvme-9gb` partition, `/media/assem/nvme-9gb` (the user's words: "building any Fortran from now on in the new NVMe partition"). Never build on `/`, which is nearly full, or on the NTFS HDD `/mnt/AEDE4577DE4538BB`, which is too slow.

One exception (the user's choice, 2026-10-25): the user's checkout `~/lfortran_test/lfortran` on `/` holds the build of the latest upstream `main`, the base version every check is compared against. Build it only with `~/.claude/skills/lfortran-batch-fix/scripts/build_main.sh [<commit>]`: it waits in the build slot's queue (so two builds never run at once), refuses while the checkout has uncommitted changes to tracked files or `/` has less free space than `src/libasr/libasr.a` takes plus 300 MB (about 1.7 GB in October 2026), and keeps gcc's temporaries on the nvme. Use its compiler by explicit path, `~/lfortran_test/lfortran/src/bin/lfortran`. Never run test suites or other builds in that checkout.

- **Mounted?** `findmnt /media/assem/nvme-9gb`. The desktop automounter mounts it; there is no `/etc/fstab` entry. If it is not mounted, stop and tell the user.
- **Room?** `df -h /media/assem/nvme-9gb`. The partition is 8.5 GB, and an in-tree Debug build is about 4.7 GB. A libasr rebuild needs about 1.2 GB more while `ranlib` rewrites the archive.
- **What is there:** `lfortran-fixes` (the batch-fix build slot), `lfortran-src-base` and `lfortran-src-<N>` (source-only worktrees) and `tmp/`. Two full builds do not fit. To build some branch, prefer the slot through the `lfortran-batch-fix` skill's `slot.sh` from a source worktree there, over making a second build.
- **gcc temporaries:** run builds with `TMPDIR=/media/assem/nvme-9gb/tmp`, so gcc's files stay off `/`.
- **New worktrees** go there too: `git -C ~/lfortran_test/lfortran worktree add /media/assem/nvme-9gb/<name> <branch>`. Moving one from `/` across filesystems: `mv` it, then `git -C ~/lfortran_test/lfortran worktree repair <new path>`. A built worktree cannot be moved this way, because CMake keeps absolute paths, so build it again in its new place.
- **`gh` is a snap** and cannot open files under `/media` ("permission denied"). Give it files on stdin: `--body-file - < file`.
- The user's own checkout `~/lfortran_test/lfortran` stays where it is. Do not move it. It holds the main build (see above).
