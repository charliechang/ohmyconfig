#!/usr/bin/env bash
# Remote end of tmux/remote.sh (runs on the remote machine, over ssh -t).
#   1. make sure the tmux server runs *outside* this ssh login, so a dropped
#      connection can't take it down (systemd-logind KillUserProcesses):
#      tmux.service if installed (tmux/install-resurrect.sh), else
#      systemd-run --scope; on macOS a plain start is enough
#   2. pick the session: [session], else the most recently attached one
#   3. mark this client's tty as behind nav-proxy.py (tmux/nav.sh then signals
#      edge moves through the title, and leaves entry to the proxy)
#   4. attach as a grouped session that disappears when this client leaves
#
# usage: remote-attach.sh <proxy|''> [session]
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
mode=${1:-}
target=${2:-}

if ! tmux list-sessions >/dev/null 2>&1; then
  if [ "$(uname)" = Linux ] && systemctl --user cat tmux.service >/dev/null 2>&1; then
    systemctl --user start tmux.service
    for _ in 1 2 3 4 5 6 7 8 9 10; do tmux list-sessions >/dev/null 2>&1 && break; sleep 0.3; done
  elif [ "$(uname)" = Linux ] && command -v systemd-run >/dev/null 2>&1; then
    systemd-run --user --scope --quiet tmux new-session -d -s main 2>/dev/null
  fi
  tmux list-sessions >/dev/null 2>&1 || tmux new-session -d -s main
fi

if [ -z "$target" ]; then
  # Most recently attached session that isn't itself a grouped copy.
  target=$(tmux list-sessions -F '#{session_last_attached}	#{session_name}	#{session_grouped}	#{session_group}' |
    awk -F'\t' '$3 == 0 || $2 == $4' | sort -rn | head -1 | cut -f2)
fi
[ -n "$target" ] || target=main
tmux has-session -t "=$target" 2>/dev/null || tmux new-session -d -s "$target"

key=$(tty | sed 's/[^A-Za-z0-9]/_/g')
if [ "$mode" = proxy ]; then
  tmux set -g "@navproxy$key" 1
  # The grouped session sends titles so nav.sh can put its edge marker in
  # them (nav-proxy.py strips it before the terminal sees it).
  exec tmux new-session -t "=$target" \; set-option destroy-unattached on \; \
    set-option set-titles on \; set-option set-titles-string '#{@navmsg}#h: #S:#W'
fi
tmux set -gu "@navproxy$key"
exec tmux new-session -t "=$target" \; set-option destroy-unattached on
