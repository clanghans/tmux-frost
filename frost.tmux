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
	tmux bind-key "$key" run-shell "$CURRENT_DIR/scripts/thaw.sh"
}

# ── Auto-save ───────────────────────────────────────────────────────

# Uses the tmux status-right #() trick (same pattern as tmux-continuum):
# A shell command is embedded in status-right that checks elapsed time
# and triggers a save when the interval has passed.

auto_save_script() {
	cat <<'AUTOSAVE'
frost_dir="FROST_DIR_PLACEHOLDER"
interval="INTERVAL_PLACEHOLDER"
freeze_script="FREEZE_SCRIPT_PLACEHOLDER"

# 0 means disabled
[ "$interval" -eq 0 ] 2>/dev/null && exit 0

stamp_file="$frost_dir/.last_auto_save"
mkdir -p "$frost_dir"

now="$(date +%s)"
if [ -f "$stamp_file" ]; then
    last="$(cat "$stamp_file")"
else
    last=0
fi

elapsed=$(( now - last ))
threshold=$(( interval * 60 ))

if [ "$elapsed" -ge "$threshold" ]; then
    echo "$now" > "$stamp_file"
    "$freeze_script" quiet &
fi
AUTOSAVE
}

setup_auto_save() {
	local interval
	interval="$(get_tmux_option "@frost-auto-save-interval" "15")"

	# 0 means disabled
	if [ "$interval" = "0" ]; then
		return
	fi

	local dir
	dir="$(frost_dir)"
	local freeze_script="$CURRENT_DIR/scripts/freeze.sh"

	# Write the auto-save helper script
	mkdir -p "$dir"
	local auto_save_file="$dir/.auto_save.sh"

	auto_save_script | \
		sed "s|FROST_DIR_PLACEHOLDER|${dir}|g; s|INTERVAL_PLACEHOLDER|${interval}|g; s|FREEZE_SCRIPT_PLACEHOLDER|${freeze_script}|g" \
		> "$auto_save_file"
	chmod +x "$auto_save_file"

	# Append to status-right (hidden — produces no visible output)
	local current_status_right
	current_status_right="$(tmux show-option -gqv status-right)"

	# Don't add twice
	if [[ "$current_status_right" != *"frost"* ]]; then
		tmux set-option -gq status-right "${current_status_right}#(${auto_save_file})"
	fi
}

# ── Main ───────────────────────────────────────────────────────────

main() {
	set_freeze_binding
	set_thaw_binding
	setup_auto_save
}
main
