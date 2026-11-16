#!/usr/bin/env bash
# Catppuccin tmux theme, pinned. Manual install (the theme's README advises against
# TPM because its repo is named `tmux`). .tmux.conf loads it when present.
# github.com blocked? Proxy this one command, e.g.
#   ALL_PROXY=socks5h://localhost:1080 tmux/install-catppuccin.sh
set -euo pipefail

tag=v2.3.2
dir=~/.config/tmux/plugins/catppuccin/tmux
mkdir -p "${dir%/*}"
if [ -d "$dir/.git" ]; then
  git -C "$dir" fetch -q --depth 1 origin tag "$tag"
else
  git -c advice.detachedHead=false clone -q --depth 1 --branch "$tag" https://github.com/catppuccin/tmux.git "$dir"
fi
git -C "$dir" -c advice.detachedHead=false checkout -q "$tag"
echo "catppuccin $tag -> $dir"

if tmux info >/dev/null 2>&1; then
  tmux source-file ~/.tmux.conf && echo "reloaded ~/.tmux.conf"
fi
