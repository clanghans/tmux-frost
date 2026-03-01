#!/usr/bin/env bash

# tmux-frost helpers — shared utilities for freeze and thaw

d=$'\t'

default_frost_dir="${XDG_DATA_HOME:-$HOME/.local/share}/tmux/frost"

# Read a tmux user option with a default fallback.
get_tmux_option() {
  local option="$1"
  local default_value="$2"
  local option_value
  option_value="$(tmux show-option -gqv "$option")"
  if [ -z "$option_value" ]; then
    echo "$default_value"
  else
    echo "$option_value"
  fi
}

# Resolved frost save directory.
frost_dir() {
  local path
  path="$(get_tmux_option "@frost-dir" "$default_frost_dir")"
  # expand ~ and $HOME
  echo "$path" | sed "s,\$HOME,$HOME,g; s,\~,$HOME,g"
}

# Path for a new save file (timestamped).
frost_file_path() {
  local timestamp
  timestamp="$(date +"%Y%m%dT%H%M%S")"
  echo "$(frost_dir)/frost_${timestamp}.txt"
}

# Path to the "last" symlink.
last_frost_file() {
  echo "$(frost_dir)/last"
}

# Display a message in the tmux status line for ~5 seconds.
display_message() {
  local message="$1"
  local display_duration="${2:-5000}"
  local saved_display_time
  saved_display_time="$(get_tmux_option "display-time" "750")"
  tmux set-option -gq display-time "$display_duration"
  tmux display-message "$message"
  tmux set-option -gq display-time "$saved_display_time"
}

# ── Logging ────────────────────────────────────────────────────────

# Daily log file: frost_YYYY-MM-DD.log in the frost directory.
# Keeps only the last 10 days of logs.

frost_log() {
  local level="$1"
  shift
  local dir
  dir="$(frost_dir)"
  mkdir -p "$dir"
  local log_file
  log_file="$dir/frost_$(date +%Y-%m-%d).log"
  echo "$(date +%H:%M:%S) [$level] $*" >>"$log_file"
}

rotate_logs() {
  local dir
  dir="$(frost_dir)"
  find "$dir" -name "frost_*.log" -type f -mtime +10 -delete 2>/dev/null
}

# Acquire an exclusive lock (non-blocking). Returns 1 if lock held by another.
# Uses flock on fd 9 — released automatically when the process exits.
acquire_lock() {
  local lock_file
  lock_file="$(frost_dir)/.frost.lock"
  mkdir -p "$(frost_dir)"
  exec 9>"$lock_file"
  flock -n 9 || return 1
}
