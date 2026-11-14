#!/usr/bin/env python3
"""Create the source-only worktree, branch, state directory and machine rules for one issue.

Usage:
  setup_issue.py ISSUE --slug short-words [--repro PATH]

This is fix-issue's Phase 1 without the per-job build, which this machine has
no room for:
- branch fix/ISSUE-SLUG at the batch's pinned base ($STATE/base_sha, written by
  prepare_build_worktree.sh) in the worktree /media/assem/nvme-9gb/lfortran-src-ISSUE;
- <worktree>/.fix-issue/ISSUE/machine.md, from assets/machine.md, which the
  issue's agent reads first, and a starting state.md.
Prints the paths.
"""
import argparse
import os
import re
import subprocess
import sys

home = os.path.expanduser("~")
STATE = os.environ.get("BATCH_FIX_STATE", f"{home}/lfortran_test/.batch-fix")
# The build slot and the source worktrees live on the nvme-9gb partition (the user's choice, 2026-10-20).
WORK = os.environ.get("BATCH_FIX_WORK", "/media/assem/nvme-9gb")
BUILD = os.environ.get("BATCH_FIX_BUILD", f"{WORK}/lfortran-fixes")
MAIN = os.environ.get("BATCH_FIX_MAIN", f"{home}/lfortran_test/lfortran")
ISSUES_DIR = f"{home}/lfortran_test/lfortran-fixable-issues"
SKILL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def run(*cmd):
    return subprocess.run(cmd, check=True, capture_output=True, text=True).stdout.strip()


ap = argparse.ArgumentParser()
ap.add_argument("issue")
ap.add_argument("--slug", required=True, help="two to four words for the branch name, e.g. entry-result")
ap.add_argument("--repro", help="an existing reproducer (default: the issue list's <issue>/re0.f90, if any)")
a = ap.parse_args()

if not re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", a.slug):
    sys.exit("--slug must be lowercase words joined by hyphens")
if not (os.path.isdir(WORK) and os.access(WORK, os.W_OK)):
    sys.exit(f"{WORK} is not mounted; mount the nvme-9gb partition first")
base = open(f"{STATE}/base_sha").read().strip()
src = f"{WORK}/lfortran-src-{a.issue}"
branch = f"fix/{a.issue}-{a.slug}"
taken = run("git", "-C", MAIN, "for-each-ref", "--format=%(refname:short)",
            f"refs/heads/fix/{a.issue}-*", f"refs/heads/fix/issue-{a.issue}")
if taken:
    sys.exit(f"branch {taken} already exists for this issue; resume it instead of starting over")
run("git", "-C", MAIN, "worktree", "add", "-q", "-b", branch, src, base)
state = f"{src}/.fix-issue/{a.issue}"
os.makedirs(state)

title = run("gh", "issue", "view", a.issue, "-R", "lfortran/lfortran", "--json", "title", "--jq", ".title")
ident = run("git", "-C", src, "var", "GIT_AUTHOR_IDENT").rsplit(" ", 2)[0]
repro = a.repro
if repro is None and os.path.isdir(f"{ISSUES_DIR}/{a.issue}"):
    repro = f"{ISSUES_DIR}/{a.issue}/re0.f90"
repro = (f"A copy of the issue's code from earlier scouting is at `{repro}`; `repro-issue` still decides the RE."
         if repro else "")

subst = {
    "__ISSUE__": a.issue, "__TITLE__": title, "__BASE__": base[:10], "__SRC__": src,
    "__BRANCH__": branch, "__BUILD__": BUILD, "__MAIN__": MAIN, "__STATE__": STATE,
    "__SCRIPTS__": f"{SKILL}/scripts", "__IDENT__": ident, "__REPRO__": repro,
}
t = open(f"{SKILL}/assets/machine.md").read()
for k, v in subst.items():
    t = t.replace(k, v)
open(f"{state}/machine.md", "w").write(t)
open(f"{state}/state.md", "w").write(
    f"# Issue #{a.issue}: {title}\n\n"
    f"- worktree: {src}\n- branch: {branch}\n- base: {base}\n- fork remote: myrepo\n"
    f"- compiler: the shared build slot, through {SKILL}/scripts/slot.sh\n"
    f"- pr:\n- round: 0\n- last_pushed_sha:\n- suites_green_sha:\n- status: set up, nothing started\n")
print(f"worktree {src} on {branch} at {base[:10]}")
print(f"machine rules {state}/machine.md")
