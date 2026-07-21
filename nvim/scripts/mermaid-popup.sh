#!/usr/bin/env bash
# Render a mermaid source file to PNG (mmdc + google-chrome) and display it as a
# Sixel image, then wait for a keypress. Intended to be run in a temporary tmux
# window (a real pane -- display-popup overlays do NOT composite Sixel):
#   tmux new-window 'mermaid-popup.sh /path/to/block.mmd'
# Requires: mmdc (mermaid-cli), chafa, and a Sixel-capable tmux + terminal.
# Deletes its input file ($1) on exit.
set -uo pipefail

LOG="${MERMAID_POPUP_LOG:-/tmp/mermaid-popup.log}"

# Resolve tools even under a bare non-interactive shell (popups don't source
# .zshrc), by putting the known bin dirs on PATH.
export PATH="$HOME/.local/bin:$HOME/.pixi/bin:$HOME/.pixi/envs/nodejs/bin:$PATH"

src="${1:?usage: mermaid-popup.sh <mermaid-source-file>}"
cfg="${MERMAID_PUPPETEER_CONFIG:-$HOME/.config/mermaid/puppeteer.json}"
scale="${MERMAID_PNG_SCALE:-3}"
tmp="$(mktemp)"
png="$(mktemp --suffix=.png)"
trap 'rm -f "$png" "$tmp" "$src"' EXIT

log() { printf '%s %s\n' "$(date '+%T')" "$*" >>"$LOG" 2>&1; }
hold() { read -rsn1 _ </dev/tty 2>/dev/null || true; }

log "===== start src=$src TERM=$TERM COLUMNS=${COLUMNS:-?} LINES=${LINES:-?}"
log "mmdc=$(command -v mmdc || echo MISSING) node=$(command -v node || echo MISSING) chafa=$(command -v chafa || echo MISSING)"

clear
printf '  rendering mermaid…'

cfg_arg=()
[ -f "$cfg" ] && cfg_arg=(-p "$cfg")

if ! mmdc "${cfg_arg[@]}" -i "$src" -o "$png" -b white -s "$scale" >"$tmp" 2>&1; then
  log "mmdc FAILED rc=$?: $(tr '\n' '|' <"$tmp")"
  clear
  printf '  mermaid render failed (unsupported diagram or syntax error):\n\n'
  sed 's/^/    /' "$tmp" | tail -n 15
  hold
  exit 0
fi
log "mmdc ok png_bytes=$(wc -c <"$png")"

# IMPORTANT: draw the image LAST and emit nothing after it. Any trailing text
# (or newline) can scroll the pane, and tmux clears the Sixel on that scroll.
#
# --passthrough none: hand raw Sixel to tmux so its NATIVE Sixel support stores
# and redraws the image. (chafa defaults to --passthrough tmux inside tmux, which
# forwards raw Sixel to the outer terminal and bypasses tmux's grid, so tmux wipes
# the image on the next redraw. With a Sixel-built tmux we want native handling.)
clear
chafa -f sixels --passthrough none --polite on "$png" 2>"$tmp"
rc=$?
log "chafa rc=$rc stderr=$(tr '\n' '|' <"$tmp")"
[ "$rc" -ne 0 ] && { printf '  chafa failed:\n\n'; sed 's/^/    /' "$tmp" | tail -n 15; }
hold
