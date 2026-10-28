#!/usr/bin/env bash
# Render a mermaid source file and display it as a Sixel image, then wait for a
# keypress. Intended to be run in a temporary tmux window (a real pane --
# display-popup overlays do NOT composite Sixel):
#   tmux new-window 'mermaid-popup.sh /path/to/block.mmd'
# Renderer: Pele (pele-render.mjs -> SVG, no browser) when node + pele are
# installed; otherwise, or when Pele rejects the diagram, mmdc (mermaid-cli +
# headless Chrome -> PNG). chafa encodes the image as Sixel.
# Requires: chafa, node + pele and/or mmdc, and a Sixel-capable tmux + terminal.
# Deletes its input file ($1) on exit.
set -uo pipefail

LOG="${MERMAID_POPUP_LOG:-/tmp/mermaid-popup.log}"

# Resolve tools even under a bare non-interactive shell (popups don't source
# .zshrc), by putting the known bin dirs on PATH. nvm's node (WSL) is only set
# up by .bashrc, so add its newest version too.
export PATH="$HOME/.local/bin:$HOME/.pixi/bin:$HOME/.pixi/envs/nodejs/bin:$PATH"
nvm_bin=$(ls -d "$HOME"/.nvm/versions/node/*/bin 2>/dev/null | sort -V | tail -n 1)
[ -n "$nvm_bin" ] && PATH="$PATH:$nvm_bin"

here="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
pele_dir="${PELE_DIR:-$HOME/.local/share/pele}"
src="${1:?usage: mermaid-popup.sh <mermaid-source-file>}"
cfg="${MERMAID_PUPPETEER_CONFIG:-$HOME/.config/mermaid/puppeteer.json}"
scale="${MERMAID_PNG_SCALE:-3}"
tmp="$(mktemp)"
png="$(mktemp --suffix=.png)"
trap 'rm -f "$png" "$tmp" "$src"' EXIT

log() { printf '%s %s\n' "$(date '+%T')" "$*" >>"$LOG" 2>&1; }
hold() { read -rsn1 _ </dev/tty 2>/dev/null || true; }

log "===== start src=$src TERM=$TERM COLUMNS=${COLUMNS:-?} LINES=${LINES:-?}"
log "node=$(command -v node || echo MISSING) pele=$([ -d "$pele_dir/node_modules/pele" ] && echo "$pele_dir" || echo MISSING) mmdc=$(command -v mmdc || echo MISSING) chafa=$(command -v chafa || echo MISSING)"

clear
printf '  rendering mermaid…'

fail() {
  clear
  printf '  mermaid render failed (unsupported diagram or syntax error):\n\n'
  sed 's/^/    /' "$tmp" | tail -n 15
  hold
  exit 0
}

img=""
pele_err=""
if command -v node >/dev/null && [ -d "$pele_dir/node_modules/pele" ]; then
  svg="$(mktemp --suffix=.svg)"
  trap 'rm -f "$png" "$svg" "$tmp" "$src"' EXIT
  if PELE_DIR="$pele_dir" node "$here/pele-render.mjs" "$scale" <"$src" >"$svg" 2>"$tmp"; then
    log "pele ok svg_bytes=$(wc -c <"$svg")"
    img="$svg"
  else
    log "pele FAILED: $(tr '\n' '|' <"$tmp")"
    pele_err="$(cat "$tmp")"
  fi
fi

if [ -z "$img" ] && command -v mmdc >/dev/null; then
  cfg_arg=()
  [ -f "$cfg" ] && cfg_arg=(-p "$cfg")
  if mmdc "${cfg_arg[@]}" -i "$src" -o "$png" -b white -s "$scale" >"$tmp" 2>&1; then
    log "mmdc ok png_bytes=$(wc -c <"$png")"
    img="$png"
  else
    log "mmdc FAILED rc=$?: $(tr '\n' '|' <"$tmp")"
  fi
fi

if [ -z "$img" ]; then
  # Pele's parse errors are short and point at the line; prefer them over
  # mmdc's puppeteer stack trace.
  [ -n "$pele_err" ] && printf '%s\n' "$pele_err" >"$tmp"
  [ -s "$tmp" ] || echo "no renderer: install pele (node) or mmdc -- see CLAUDE.md" >"$tmp"
  fail
fi

# IMPORTANT: draw the image LAST and emit nothing after it. Any trailing text
# (or newline) can scroll the pane, and tmux clears the Sixel on that scroll.
#
# --passthrough none: hand raw Sixel to tmux so its NATIVE Sixel support stores
# and redraws the image. (chafa defaults to --passthrough tmux inside tmux, which
# forwards raw Sixel to the outer terminal and bypasses tmux's grid, so tmux wipes
# the image on the next redraw. With a Sixel-built tmux we want native handling.)
clear
chafa -f sixels --passthrough none --polite on "$img" 2>"$tmp"
rc=$?
log "chafa rc=$rc stderr=$(tr '\n' '|' <"$tmp")"
[ "$rc" -ne 0 ] && { printf '  chafa failed:\n\n'; sed 's/^/    /' "$tmp" | tail -n 15; }
hold
