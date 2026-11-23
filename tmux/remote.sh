#!/usr/bin/env bash
# Show a remote machine's tmux in this terminal split (Ghostty / Windows
# Terminal) and keep it there:
#   - reconnects after a dropped connection (lid closed, network change); the
#     work itself lives in the remote tmux server and keeps running meanwhile
#   - attaches to your existing session (most recently used, or [session]) as
#     a grouped session, so this split picks its own window/size without
#     disturbing other clients of that session
#   - runs ssh inside tmux/nav-proxy.py so C-h/j/k/l can cross between this
#     split and its neighbours (tmux/nav.sh); the signals ride in the normal
#     terminal stream, so a crossing costs half a network round trip
# The remote side is tmux/remote-attach.sh from the remote's own checkout of
# this repo (~/work/ohmyconfig); without it, plain `tmux new -A -s main`.
# Detach (prefix d) to end it. Design + progress: docs/terminal-split-nav.md
#
# usage: remote.sh <ssh-host> [session]
#   REMOTE_ATTACH=<path on remote>  use another remote-attach.sh (tests)
set -u

here=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
host=${1:?usage: remote.sh <ssh-host> [session]}
session=${2:-}

if [ "${TERM_PROGRAM:-}" = ghostty ] || [ "${TERM:-}" = xterm-ghostty ]; then kind=ghostty
elif [ -n "${WT_SESSION:-}" ] || [ -d /mnt/c/Windows ]; then kind=wt
else kind=none; fi
# Remotes rarely have Ghostty's terminfo; tmux there refuses to start without
# it. Ghostty still identifies itself to tmux via XTVERSION (client_termtype).
[ "${TERM:-}" = xterm-ghostty ] && export TERM=xterm-256color

attach=${REMOTE_ATTACH:-\$HOME/work/ohmyconfig/tmux/remote-attach.sh}
remote_cmd="a=$attach; if [ -x \"\$a\" ]; then exec \"\$a\" proxy '$session'; fi; "
remote_cmd+="PATH=\$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:\$PATH; exec tmux new -A -s main"

# A host alias with forwards (WSL's momo-dev: DynamicForward 1080 for git) would
# warn "Address already in use" when another connection already holds the port,
# so this one drops its forwards then. If nothing holds them, it keeps them.
forwards() {
  local p
  for p in $(ssh -G "$host" 2>/dev/null |
    awk '$1 == "dynamicforward" || $1 == "localforward" { print $2 }' | sed 's/.*://'); do
    (exec 3<>"/dev/tcp/127.0.0.1/$p") 2>/dev/null && { echo -o ClearAllForwardings=yes; return; }
  done
}

wait=3
while :; do
  start=$(date +%s)
  # shellcheck disable=SC2046 # forwards prints whole words
  python3 "$here/nav-proxy.py" "$here/nav.sh" "$kind" -- \
    ssh -t -o ServerAliveInterval=15 -o ServerAliveCountMax=3 $(forwards) "$host" "$remote_cmd"
  rc=$?
  # 255 = ssh itself failed (connection lost / refused). Anything else means
  # the remote tmux client ended normally (detached): stop.
  [ "$rc" -eq 255 ] || break
  # Back off while it keeps failing straight away (network still down, or an
  # IAP / ProxyCommand that needs a fresh `gcloud auth login`); reset after a
  # connection that lasted.
  if [ $(($(date +%s) - start)) -gt 60 ]; then wait=3; fi
  printf '\r\n[remote.sh] %s: connection lost; reconnecting in %ss (any key to stop)\r\n' "$host" "$wait"
  [ "$wait" -ge 24 ] && printf '[remote.sh] still failing: run `ssh %s` by hand to see why (e.g. gcloud auth)\r\n' "$host"
  read -rsn1 -t "$wait" _ && break
  wait=$((wait * 2 > 30 ? 30 : wait * 2))
done
