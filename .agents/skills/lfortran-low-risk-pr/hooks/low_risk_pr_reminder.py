#!/usr/bin/env python3
"""PostToolUse hook for Bash: after a command that creates or pushes a PR,
remind Claude to apply the lfortran-low-risk-pr skill."""
import json
import re
import sys

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
cmd = (data.get("tool_input") or {}).get("command") or ""
if not re.search(r"\bgh\s+pr\s+create\b|publish_pr\.sh\s+\d+|\bgit\s+(-C\s+\S+\s+)?push\b", cmd):
    sys.exit(0)
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "PostToolUse",
        "additionalContext": (
            "A PR was just created or pushed. Load the `lfortran-low-risk-pr` skill "
            "(Skill tool), read that PR's diff (lfortran/lfortran) and judge yourself "
            "whether it fits a low-risk kind; if it does, run its `mark_low_risk.sh "
            "<PR> <kind> \"<reason>\"` before you report. If this push did not touch "
            "an lfortran/lfortran PR, ignore this."
        ),
    }
}))
