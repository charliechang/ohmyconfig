#!/usr/bin/env bash
# Open a new terminal split next to the current one, running tmux/remote.sh
# <host> (a remote tmux you can reach with C-h/j/k/l). Run it from the split
# you want to split, e.g. `split-remote.sh charlie.chang@10.0.0.4`.
#   macOS: Ghostty (AppleScript `split ... with configuration`)
#   WSL:   Windows Terminal (`wt.exe -w 0 split-pane`)
# Design + progress: docs/terminal-split-nav.md
#
# usage: split-remote.sh <ssh-host> [session] [right|down]
set -eu

here=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
host=${1:?usage: split-remote.sh <ssh-host> [session] [right|down]}
session=${2:-}
dir=${3:-right}
cmd="$here/remote.sh $(printf '%q' "$host")${session:+ $(printf '%q' "$session")}"

if [ "$(uname)" = Darwin ]; then
  osascript - "$cmd" "$dir" >/dev/null <<'EOF'
on run argv
  tell application "Ghostty"
    set cfg to new surface configuration
    set command of cfg to item 1 of argv
    set t to focused terminal of selected tab of front window
    if item 2 of argv is "down" then
      split t direction down with configuration cfg
    else
      split t direction right with configuration cfg
    end if
  end tell
end run
EOF
elif [ -d /mnt/c/Windows ]; then
  flag=-V
  [ "$dir" = down ] && flag=-H
  args=(-w 0 split-pane "$flag" wsl.exe -d "${WSL_DISTRO_NAME:-Ubuntu}" --cd "$HOME" -e bash -lc "$cmd")
  (cd /mnt/c && { wt.exe "${args[@]}" 2>/dev/null || cmd.exe /c wt.exe "${args[@]}"; })
else
  echo "split-remote.sh: only Ghostty (macOS) and Windows Terminal (WSL) are supported" >&2
  exit 1
fi
