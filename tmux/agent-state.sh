#!/usr/bin/env bash
# herdr-style agent status for tmux (https://github.com/herdrdev/herdr).
#
# Each tmux pane running Claude Code carries a pane option @agent_state:
#   working  agent is running
#   blocked  agent needs input / approval
#   done     agent finished and you have not looked at it yet
#   idle     agent finished and has been seen
# .tmux.conf rolls the states up into window badges and a status-right summary.
#
# Usage:
#   agent-state.sh set <state>|clear   from Claude Code hooks (uses $TMUX_PANE)
#   agent-state.sh seen <pane>         from tmux hooks: done -> idle
#   agent-state.sh summary             status-right counts
#   agent-state.sh next <client>       jump to next blocked, else done, pane

TMUX_BIN=${TMUX_BIN:-tmux}

refresh() {
  "$TMUX_BIN" list-clients -F '#{client_name}' 2>/dev/null |
    while read -r c; do "$TMUX_BIN" refresh-client -S -t "$c" 2>/dev/null; done
}

# Is the pane currently on screen (active pane, active window, attached session)?
visible() {
  [ "$("$TMUX_BIN" display -p -t "$1" \
    '#{&&:#{pane_active},#{&&:#{window_active},#{session_attached}}}' 2>/dev/null)" = 1 ]
}

cmd_set() {
  local state=$1 pane=$TMUX_PANE prev
  [ -n "$pane" ] || exit 0
  # Claude Code pipes the hook payload on stdin; drain it so the hook never blocks.
  [ -t 0 ] || cat >/dev/null
  prev=$("$TMUX_BIN" show -pqv -t "$pane" @agent_state 2>/dev/null)
  if [ "$state" = clear ]; then
    "$TMUX_BIN" set -pu -t "$pane" @agent_state 2>/dev/null
    refresh
    exit 0
  fi
  if [ "$state" = done ] && visible "$pane"; then
    state=idle
  fi
  [ "$state" = "$prev" ] && exit 0
  "$TMUX_BIN" set -p -t "$pane" @agent_state "$state" 2>/dev/null
  refresh
  if ! visible "$pane"; then
    local where
    where=$("$TMUX_BIN" display -p -t "$pane" '#{session_name}:#{window_index}.#{pane_index} #{window_name}')
    case $state in
      blocked) "$TMUX_BIN" display-message -d 4000 "agent needs you: $where" 2>/dev/null ;;
      done)    "$TMUX_BIN" display-message -d 4000 "agent done: $where" 2>/dev/null ;;
    esac
  fi
  exit 0
}

cmd_seen() {
  local pane=$1
  [ "$("$TMUX_BIN" show -pqv -t "$pane" @agent_state 2>/dev/null)" = done ] || exit 0
  "$TMUX_BIN" set -p -t "$pane" @agent_state idle
  refresh
}

# All agent panes as "<pane_id> <state>". Drops stale state on panes whose
# agent exited without a SessionEnd hook (e.g. killed).
agent_panes() {
  "$TMUX_BIN" list-panes -a -F '#{pane_id} #{@agent_state} #{pane_current_command}' 2>/dev/null |
    while read -r id state cmd; do
      [ -n "$cmd" ] || continue # no state set: the line is "<id>  <cmd>"
      case $cmd in
        claude|node) echo "$id $state" ;;
        *) "$TMUX_BIN" set -pu -t "$id" @agent_state 2>/dev/null ;;
      esac
    done
}

cmd_summary() {
  local b=0 d=0 w=0 out=""
  while read -r _ state; do
    case $state in
      blocked) b=$((b + 1)) ;;
      done)    d=$((d + 1)) ;;
      working) w=$((w + 1)) ;;
    esac
  done < <(agent_panes)
  [ $b -gt 0 ] && out+="#[fg=white,bg=red,bold] !$b #[default] "
  [ $d -gt 0 ] && out+="#[fg=white,bg=colour25,bold] ✓$d #[default] "
  [ $w -gt 0 ] && out+="#[fg=black,bg=colour220] ●$w #[default] "
  printf '%s' "$out"
}

cmd_next() {
  local client=$1 cur want ids=() id state target=""
  cur=$("$TMUX_BIN" display -p -c "$client" '#{pane_id}' 2>/dev/null)
  for want in blocked done; do
    ids=()
    while read -r id state; do
      [ "$state" = "$want" ] && ids+=("$id")
    done < <(agent_panes)
    [ ${#ids[@]} -gt 0 ] || continue
    # Cycle: first matching pane after the current one, wrapping around.
    target=${ids[0]}
    for i in "${!ids[@]}"; do
      if [ "${ids[$i]}" = "$cur" ]; then
        target=${ids[$(((i + 1) % ${#ids[@]}))]}
      fi
    done
    break
  done
  if [ -z "$target" ]; then
    "$TMUX_BIN" display-message -c "$client" "no agent needs attention"
    exit 0
  fi
  "$TMUX_BIN" switch-client -c "$client" -t "$target" \; \
    select-window -t "$target" \; select-pane -t "$target"
  cmd_seen "$target"
}

case $1 in
  set)     cmd_set "$2" ;;
  seen)    cmd_seen "$2" ;;
  summary) cmd_summary ;;
  next)    cmd_next "$2" ;;
  *) echo "usage: $0 {set <state>|set clear|seen <pane>|summary|next <client>}" >&2; exit 2 ;;
esac
