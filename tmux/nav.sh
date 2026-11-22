#!/usr/bin/env bash
# One set of keys (C-h/j/k/l) across nvim windows, tmux panes and the terminal
# app's own splits (Ghostty on macOS, Windows Terminal on WSL), whether the
# tmux in a split is local or remote (opened with tmux/remote.sh).
# Design + progress log: docs/terminal-split-nav.md
#
#   nav.sh move <L|D|U|R> [pane] [client_tty]
#       tmux binding (pane not nvim) or nvim at its own edge. Moves to the
#       neighbouring tmux pane; at this tmux's edge, moves the terminal split:
#       directly when this tmux is local, or (remote tmux behind
#       nav-proxy.py) by putting "@@nav:<dir>:<n>@@" in the title it sends.
#   nav.sh focus-in <client_tty>
#       tmux client-focus-in hook (local clients): if the terminal just moved
#       into this split, enter from that side. Proxy clients get the same
#       information as a key (User90..93 -> nav.sh enter) instead.
#   nav.sh enter <client_tty> <L|D|U|R>
#       this split was entered moving <dir>: select the pane, and nvim window,
#       on the side it came in from.
#   nav.sh term-move <L|D|U|R> <ghostty|wt|none>
#       move the terminal app's split focus; records the move for focus-in.
#   nav.sh take
#       print + clear the recorded move if it is fresh.
#   nav.sh nvim-enter <pane> <L|D|U|R>
#       tell the nvim in <pane> it was entered moving <dir>.

TMUX_BIN=${TMUX_BIN:-tmux}
state=${TMPDIR:-/tmp}
state=${state%/}/tmux-nav-$(id -u)
pending=$state/pending
log=$state/log
mkdir -p "$state" 2>/dev/null

t() { "$TMUX_BIN" "$@"; }
note() { printf '%s %s\n' "$(date '+%F %T')" "$*" >>"$log" 2>/dev/null; }

edge_of() { case $1 in L) echo left ;; R) echo right ;; U) echo top ;; D) echo bottom ;; esac; }
entry_of() { case $1 in L) echo right ;; R) echo left ;; U) echo bottom ;; D) echo top ;; esac; }

# The client that typed last: nvim doesn't know which client pressed the key
# (a window can be shown by several, e.g. grouped sessions).
latest_client() {
  t list-clients -F '#{client_activity} #{client_tty}' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-
}

# Is this client a remote.sh connection (behind nav-proxy.py)?
is_proxy() {
  local key
  key=$(printf '%s' "$1" | sed 's/[^A-Za-z0-9]/_/g')
  [ "$(t show -gqv "@navproxy$key" 2>/dev/null)" = 1 ]
}

term_kind() {
  case "$(t display -p -c "$1" '#{client_termname} #{client_termtype}' 2>/dev/null)" in
    *[Gg]hostty*) echo ghostty ;;
    *) [ -d /mnt/c/Windows ] && echo wt || echo none ;;
  esac
}

cmd_term_move() {
  local dir=$1 kind=$2 r
  printf '%s %s\n' "$dir" "$(date +%s)" >"$pending"
  case $kind in
    ghostty)
      local g
      case $dir in L) g=left ;; R) g=right ;; U) g=up ;; D) g=down ;; esac
      r=$(osascript -e "tell application \"Ghostty\" to perform action \"goto_split:$g\" on focused terminal of selected tab of front window" 2>>"$log")
      [ "$r" = true ] || rm -f "$pending" # no split that way: nothing to enter
      ;;
    wt)
      local w
      case $dir in L) w=left ;; R) w=right ;; U) w=up ;; D) w=down ;; esac
      # Execution aliases may not run from WSL; cmd.exe needs a Windows cwd.
      if (cd /mnt/c && wt.exe -w 0 move-focus "$w") >/dev/null 2>>"$log"; then r=sent
      elif (cd /mnt/c && cmd.exe /c wt.exe -w 0 move-focus "$w") >/dev/null 2>>"$log"; then r=sent-cmd
      else r=failed; rm -f "$pending"; fi
      ;;
    *) r=none; rm -f "$pending" ;;
  esac
  note "term-move $dir $kind -> ${r:-error}"
  echo "${r:-error}"
}

cmd_take() {
  local dir ts
  [ -f "$pending" ] || return 0
  read -r dir ts <"$pending"
  rm -f "$pending"
  # Fresh only: an old record must not hijack a later click or app switch.
  [ -n "$ts" ] && [ $(($(date +%s) - ts)) -le 2 ] && echo "$dir"
}

cmd_nvim_enter() {
  local pane=$1 dir=$2 sock bin
  sock=$(t show -pqv -t "$pane" @nvim_sock 2>/dev/null)
  bin=$(t show -pqv -t "$pane" @nvim_bin 2>/dev/null)
  [ -n "$sock" ] && [ -S "$sock" ] && [ -x "$bin" ] || return 0
  "$bin" --clean --headless --server "$sock" \
    --remote-expr "v:lua.require'core.nav'.enter('$dir')" </dev/null >/dev/null 2>>"$log"
}

cmd_move() {
  local dir=$1 pane=${2:-${TMUX_PANE:-}} ctty=${3:-} at win sess n
  [ -n "$pane" ] || pane=$(t display -p '#{pane_id}')
  [ -n "$ctty" ] || ctty=$(latest_client)
  at=$(t display -p -t "$pane" "#{pane_at_$(edge_of "$dir")}#{window_zoomed_flag}")
  note "move $dir pane=$pane client=$ctty edge/zoom=$at"
  if [ "$at" = 00 ]; then
    win=$(t display -p -t "$pane" '#{window_id}')
    t select-pane -t "$pane" "-$dir"
    cmd_nvim_enter "$(t display -p -t "$win" '#{pane_id}')" "$dir"
    return
  fi
  # At this tmux's edge (or zoomed): leave it.
  if is_proxy "$ctty"; then
    sess=$(t display -p -c "$ctty" '#{session_id}')
    n=$(($(t show -gqv @navseq 2>/dev/null || echo 0) + 1))
    # Titles carry the marker; switch them on here too, in case this client
    # came in some other way than remote-attach.sh (e.g. a stale @navproxy
    # flag on a reused tty).
    t set -g @navseq "$n" \; set -t "$sess" set-titles on \; \
      set -t "$sess" set-titles-string '#{@navmsg}#h: #S:#W' \; \
      set -t "$sess" @navmsg "@@nav:$dir:$n@@" \; refresh-client -S -t "$ctty"
    note "move $dir: title marker $n to proxy client $ctty"
    # Drop the marker once sent; the proxy also ignores repeats of <n>.
    (sleep 1; t set -u -t "$sess" @navmsg \; refresh-client -S -t "$ctty") >/dev/null 2>&1 &
  else
    cmd_term_move "$dir" "$(term_kind "$ctty")" >/dev/null
  fi
}

cmd_enter() {
  local ctty=$1 dir=$2 win side axis active pick
  win=$(t display -p -c "$ctty" '#{window_id}')
  side=$(entry_of "$dir")
  # Among panes on the entry side, keep the active one if it is there,
  # otherwise take the one closest to it along the edge.
  case $dir in L | R) axis='#{pane_top} #{pane_bottom}' ;; *) axis='#{pane_left} #{pane_right}' ;; esac
  pick=$(t list-panes -t "$win" -F "#{pane_id} #{pane_active} #{pane_at_$side} $axis" |
    awk '{ c = ($4 + $5) / 2 } $2 == 1 { ac = c; aid = $1; aon = $3 }
         $3 == 1 { id[$1] = c }
         END { if (aon) { print aid; exit }
               best = ""; for (p in id) { d = id[p] - ac; if (d < 0) d = -d
                 if (best == "" || d < bd) { best = p; bd = d } }
               print best }')
  [ -n "$pick" ] && t select-pane -t "$pick"
  active=$(t display -p -t "$win" '#{pane_id}')
  cmd_nvim_enter "$active" "$dir"
  note "enter $ctty moving $dir -> $active"
}

cmd_focus_in() {
  local ctty=$1 dir
  is_proxy "$ctty" && return 0 # nav-proxy.py sends the direction as a key
  dir=$(cmd_take)
  case $dir in L | R | U | D) cmd_enter "$ctty" "$dir" ;; esac
}

case ${1:-} in
  move) cmd_move "${2:?dir}" "${3:-}" "${4:-}" ;;
  focus-in) cmd_focus_in "${2:?client_tty}" ;;
  enter) cmd_enter "${2:?client_tty}" "${3:?dir}" ;;
  term-move) cmd_term_move "${2:?dir}" "${3:-none}" ;;
  take) cmd_take ;;
  nvim-enter) cmd_nvim_enter "${2:?pane}" "${3:?dir}" ;;
  *) echo "usage: $0 {move <dir> [pane] [client]|focus-in <client>|enter <client> <dir>|term-move <dir> <kind>|take|nvim-enter <pane> <dir>}" >&2; exit 2 ;;
esac
