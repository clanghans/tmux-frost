#!/usr/bin/env bash
#
# auto_save_loop.sh — daemonised auto-save loop for tmux-frost.
#
# Fully detaches from the calling process so tmux run-shell (and TPM)
# can return immediately.

pid_file="$1"
interval="$2"
freeze_script="$3"
tmux_socket="$4"

# Close every inherited fd beyond stderr so the tmux run-shell pipe
# reaches EOF and the caller is unblocked.
for fd in /proc/$$/fd/*; do
	n="$(basename "$fd")"
	(( n > 2 )) && eval "exec $n>&-" 2>/dev/null
done
exec </dev/null >/dev/null 2>&1

echo $$ > "$pid_file"

while true; do
	sleep "$interval"
	# Use explicit socket so we don't depend on TMUX env var
	tmux -S "$tmux_socket" run-shell "'$freeze_script' quiet"
done
