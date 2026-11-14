#!/usr/bin/env bash
# Show the build slot's queue: who is building or testing right now, who is
# waiting and in which order, and the most recent slot events.
#
# Usage: slot_status.sh [history-lines]      (default 12; 0 hides the history)
# Watch it live from another terminal with: watch -n 5 <this script>

STATE=${BATCH_FIX_STATE:-$HOME/lfortran_test/.batch-fix}
LOCK=$STATE/build.lock
QUEUE=$STATE/queue
CURRENT=$STATE/slot_current
HISTORY=$STATE/slot_history.log
lines=${1:-12}
now=$(date +%s)

age() { local s=$((now - $1)); printf '%dm%02ds' $((s / 60)) $((s % 60)); }

[ -f "$STATE/build_slot.open" ] && echo "slot: open" || echo "slot: CLOSED (calls wait up to 9 min, then exit 3)"

held=no
if [ -e "$LOCK" ] && ! flock -n "$LOCK" true; then held=yes; fi
holder=
if [ -f "$CURRENT" ]; then
    IFS=$'\t' read -r cname cpid cstart cphase cwhat < "$CURRENT"
    if kill -0 "$cpid" 2>/dev/null; then
        holder=$cpid
        echo "NOW:  $cname  $cphase for $(age "$cstart")  --  $cwhat"
    elif [ $held = yes ]; then
        echo "NOW:  $cname  its command is still running, but the calling script is gone  --  $cwhat"
    fi
elif [ $held = yes ]; then
    echo "NOW:  a job without a ticket holds the lock (baseline.sh or prepare_build_worktree.sh)"
fi
[ -z "$holder" ] && [ $held = no ] && echo "NOW:  idle"

n=0
for t in "$QUEUE"/*; do
    [ -e "$t" ] || continue
    IFS=$'\t' read -r tname tpid tqueued twhat < "$t"
    [ "$tpid" = "$holder" ] && continue
    kill -0 "$tpid" 2>/dev/null || continue
    [ $n -eq 0 ] && echo "WAITING, in order:"
    n=$((n + 1))
    echo "  $n. $tname  waiting $(age "$tqueued")  --  $twhat"
done
[ $n -eq 0 ] && echo "WAITING: nobody"

if [ "$lines" -gt 0 ] && [ -f "$HISTORY" ]; then
    echo "RECENT:"
    tail -n "$lines" "$HISTORY" | sed 's/^/  /' | cut -c1-200
fi
