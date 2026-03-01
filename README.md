# tmux-frost

Minimal tmux session save/restore. Freeze your sessions, thaw them later.

## Why

I've been using tmux daily for over five years and was pretty happy with tmux-resurrect and tmux-continuum for most of that time. But a few things always bugged me:

1. **continuum hijacks `status-right`** — my theme would constantly overwrite it, breaking auto-save or vice versa.
2. **resurrect's stacked-pane bug** — restored layouts often leave panes with a height of 1, and the project has been effectively unmaintained for a while now.
3. **Two plugins for one job** — needing both resurrect *and* continuum just to save and restore sessions felt like unnecessary complexity.
4. **Too many features I don't use** — process restoration, strategy hooks, and other extras add weight I never needed. I just want my windows, panes, and layouts back.

tmux-frost is a single plugin that does save, restore, and auto-save/restore with none of the baggage.

## Features

- **Save & restore** all sessions, windows, panes, and layouts
- **Auto-restore** on server start — previous layout restored automatically
- **Auto-save** at a configurable interval (default: 15 min)
- **Stacked-pane fix** — detects broken layouts at save time and replaces them with `tiled`
- **Dedup** — identical saves don't create new files
- **Backup retention** — old saves cleaned up automatically (default: 30 days, keeps newest 5)
- **Locking** — `flock`-based mutual exclusion prevents concurrent freeze/thaw

## Requirements

- tmux 3.0+
- bash
- [TPM](https://github.com/tmux-plugins/tpm)

## Install

Add to `~/.tmux.conf`:

```tmux
set -g @plugin 'chris/tmux-frost'
```

Then reload tmux and press `prefix + I` to install.

## Keybindings

| Binding | Action |
|---|---|
| `prefix + C-s` | Save (freeze) all sessions |
| `prefix + C-r` | Restore (thaw) from last save |

## What gets saved

- All sessions, windows, and panes
- Window layouts and names
- Pane working directories and titles
- Active window/pane selections
- Client session state
- `automatic-rename` window option

## What doesn't get saved

- Running processes (panes restore to a fresh shell)
- Scroll history
- Environment variables
- Pane contents

## Options

Set these in `~/.tmux.conf` before loading the plugin:

```tmux
# Save/restore keybindings
set -g @frost-save-key 'C-s'        # default: C-s
set -g @frost-restore-key 'C-r'     # default: C-r

# Auto-restore on server start ('on' or 'off')
set -g @frost-auto-restore 'on'       # default: on

# Auto-save interval in minutes (0 to disable)
set -g @frost-auto-save-interval '15'  # default: 15

# Save directory
set -g @frost-dir '~/.local/share/tmux/frost'  # default

# Delete backups older than N days (keeps newest 5 regardless)
set -g @frost-delete-backup-after '30'  # default: 30
```

## Save file format

Saves are tab-separated text files with a version header:

```
frost_version	1
pane	session	window_idx	win_active	pane_idx	title	:path	pane_active
window	session	window_idx	:name	win_active	:flags	layout	auto_rename
state	client_session	client_last_session
```

Files are stored as `frost_YYYYMMDDTHHMMSS.txt` with a `last` symlink pointing to the most recent save.

## How auto-restore works

When the plugin loads, it registers a one-shot `session-created` hook. The first time a session is created (i.e. tmux just started), the hook checks if the server is fresh (only 1 pane exists) and a save file is available. If so, it runs thaw to restore the previous layout. The hook removes itself immediately so it never fires again during the server's lifetime.

## How auto-save works

Auto-save runs as a background loop that sleeps for the configured interval and then triggers a quiet freeze. The loop is started by `frost.tmux` when the plugin loads and is a child of the tmux server process, so it dies naturally when tmux exits. A PID file prevents duplicate loops on config reloads (`tmux source`).

## Running tests

```sh
./tests/run_tests.sh
```

Tests run against an isolated tmux server socket and don't affect your running sessions.

## License

MIT
