#!/usr/bin/env bash
#
# auto_save_loop.sh — daemonised auto-save loop for tmux-frost.
#
# Fully detaches from the calling process so tmux run-shell (and TPM)
# can return immediately.

pid_file="$1"
interval="$2"
freeze_script="$3"

# Redirect stdio and close every inherited fd beyond stderr so the
# tmux run-shell pipe reaches EOF and the caller is unblocked.
exec </dev/null >/dev/null 2>&1
for fd in /proc/$$/fd/*; do
	n="$(basename "$fd")"
	(( n > 2 )) && eval "exec $n>&-" 2>/dev/null
done

echo $$ > "$pid_file"

while true; do
	sleep "$interval"
	"$freeze_script" quiet
done
