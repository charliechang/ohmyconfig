#!/usr/bin/env bash
# Bring tmux sessions back after a reboot:
#   1. clone pinned tmux-resurrect + tmux-continuum into ~/.tmux/plugins
#      (.tmux.conf loads them when present). continuum saves the layout every
#      5 minutes and restores the last save whenever a tmux server starts.
#   2. on a systemd machine that is not WSL: install tmux.service so the server
#      (and the restore) starts at boot, and enable linger so it doesn't wait
#      for a login. WSL only boots when a terminal opens, so there the restore
#      happens on the first `tmux` instead.
#   3. reload the tmux config if a server is running
# github.com blocked? Proxy this one command, e.g.
#   ALL_PROXY=socks5h://localhost:1080 tmux/install-resurrect.sh
set -euo pipefail

here=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
plugins=~/.tmux/plugins
mkdir -p "$plugins"

clone() { # name tag
  local dir="$plugins/$1"
  if [ -d "$dir/.git" ]; then
    git -C "$dir" fetch -q --depth 1 origin tag "$2"
  else
    git -c advice.detachedHead=false clone -q --depth 1 --branch "$2" "https://github.com/tmux-plugins/$1" "$dir"
  fi
  git -C "$dir" -c advice.detachedHead=false checkout -q "$2"
  echo "$1 $2 -> $dir"
}
clone tmux-resurrect v4.0.0
clone tmux-continuum v3.1.0
mkdir -p ~/.local/bin
ln -sfn "$here/resurrect-extras.sh" ~/.local/bin/tmux-resurrect-extras
echo "linked ~/.local/bin/tmux-resurrect-extras (Claude/nvim resume, see .tmux.conf)"

if [ "$(ps -p 1 -o comm=)" = systemd ] && ! grep -qi microsoft /proc/version; then
  unit=~/.config/systemd/user/tmux.service
  mkdir -p "${unit%/*}"
  ln -sfn "$here/tmux.service" "$unit"
  systemctl --user daemon-reload
  systemctl --user enable tmux.service
  echo "enabled $unit (starts the tmux server at boot)"
  if [ "$(loginctl show-user "$USER" -p Linger --value 2>/dev/null)" != yes ]; then
    loginctl enable-linger "$USER" && echo "enabled linger for $USER"
  fi
  # Don't start it now if a server is already up: it would just add a session
  # to that server and exit. It takes over from the next boot.
  if ! tmux info >/dev/null 2>&1; then
    systemctl --user start tmux.service && echo "started tmux.service"
  fi
fi

if tmux info >/dev/null 2>&1; then
  tmux source-file ~/.tmux.conf && echo "reloaded ~/.tmux.conf"
fi
