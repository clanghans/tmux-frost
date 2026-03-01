#!/usr/bin/env bash
#
# frost.tmux — TPM entry point for tmux-frost.
#
# Minimal session save/restore with built-in auto-save.
# Fixes the stacked-pane bug by validating layouts at save time.
#

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/scripts/helpers.sh"

# ── Keybindings ─────────────────────────────────────────────────────

set_freeze_binding() {
	local key
	key="$(get_tmux_option "@frost-save-key" "C-s")"
	tmux bind-key "$key" run-shell "$CURRENT_DIR/scripts/freeze.sh"
}

set_thaw_binding() {
	local key
	key="$(get_tmux_option "@frost-restore-key" "C-r")"
	# run-shell -b launches thaw in background, wait-for blocks the client
	# until thaw signals completion — making tmux "busy" during restore.
	tmux bind-key "$key" \
		run-shell -b "'$CURRENT_DIR/scripts/thaw.sh' ; tmux wait-for -S frost-thaw" \; \
		wait-for frost-thaw
}

# ── Auto-save ───────────────────────────────────────────────────────

# Background loop that saves at a fixed interval.
# The loop is a child of the tmux server, so it dies on normal exit.
# A PID file prevents duplicates on config reloads.

stop_auto_save() {
	local dir
	dir="$(frost_dir)"
	local pid_file="$dir/.auto_save.pid"

	if [ -f "$pid_file" ]; then
		local old_pid
		old_pid="$(cat "$pid_file")"
		if kill -0 "$old_pid" 2>/dev/null; then
			kill "$old_pid" 2>/dev/null
		fi
		rm -f "$pid_file"
	fi
}

setup_auto_save() {
	local interval
	interval="$(get_tmux_option "@frost-auto-save-interval" "15")"

	# 0 means disabled
	if [ "$interval" = "0" ]; then
		stop_auto_save
		return
	fi

	local dir
	dir="$(frost_dir)"
	local pid_file="$dir/.auto_save.pid"
	local freeze_script="$CURRENT_DIR/scripts/freeze.sh"

	mkdir -p "$dir"

	# If a loop is already running, leave it alone
	if [ -f "$pid_file" ]; then
		local old_pid
		old_pid="$(cat "$pid_file")"
		if kill -0 "$old_pid" 2>/dev/null; then
			frost_log INFO "auto-save loop already running (pid $old_pid)"
			return
		fi
	fi

	# Launch via setsid into a dedicated script that closes all inherited
	# fds — this prevents tmux's run-shell pipe from staying open, which
	# would block TPM installs and config reloads.
	setsid "$CURRENT_DIR/scripts/auto_save_loop.sh" \
		"$pid_file" "$((interval * 60))" "$freeze_script" &
	frost_log INFO "auto-save loop started (interval ${interval}m)"
}

# ── Auto-restore ───────────────────────────────────────────────────

# Register a one-shot session-created hook that restores on first
# session, then removes itself.  This defers thaw until tmux is
# fully initialised and ready to create sessions/windows/panes.

setup_auto_restore() {
	local enabled
	enabled="$(get_tmux_option "@frost-auto-restore" "on")"
	[ "$enabled" = "on" ] || return

	tmux set-hook -g session-created \
		"run-shell '\"$CURRENT_DIR/scripts/auto-restore.sh\" \"$CURRENT_DIR\"'"
}

# ── Main ───────────────────────────────────────────────────────────

main() {
	frost_log INFO "plugin loaded"
	set_freeze_binding
	set_thaw_binding
	setup_auto_restore
	setup_auto_save
}
main
