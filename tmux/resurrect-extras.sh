#!/usr/bin/env bash
# Claude Code + nvim state that tmux-resurrect doesn't keep on its own.
# Called from resurrect hooks set in .tmux.conf:
#   resurrect-extras.sh save      post-save-all: write claude-panes.tsv next to
#                                 the resurrect save (pane -> Claude session ids)
#   resurrect-extras.sh markers   pre-restore-pane-processes: tell each nvim that
#                                 is about to be relaunched to reload its session
#   resurrect-extras.sh restore   post-restore-all: `claude --resume <id>` in
#                                 every pane that was running Claude
# Session ids come from the pane option @claude_sessions, kept up to date by
# the Claude Code hooks in agent-state.sh. Claude running inside nvim is
# resumed by nvim itself (nvim/lua/core/session.lua) from the marker file.

TMUX_BIN=${TMUX_BIN:-tmux}

resurrect_dir() {
  local d
  d=$("$TMUX_BIN" show -gqv @resurrect-dir)
  d=${d:-$HOME/.tmux/resurrect}
  d=${d//\$HOME/$HOME}
  echo "${d/#\~/$HOME}"
}
tsv="$(resurrect_dir)/claude-panes.tsv"
markers=${XDG_STATE_HOME:-$HOME/.local/state}/nvim/tmux-restore

# Same key nvim computes for its pane (session_window_pane, unsafe chars -> _).
pane_key() { printf '%s_%s_%s' "$1" "$2" "$3" | sed 's/[^A-Za-z0-9_.-]/_/g'; }

# The directory a Claude session ran in, from its transcript.
session_cwd() {
  local f
  f=$(ls ~/.claude/projects/*/"$1".jsonl 2>/dev/null | head -1)
  [ -n "$f" ] && grep -m1 -o '"cwd":"[^"]*"' "$f" | sed 's/"cwd":"\(.*\)"/\1/'
}

# "<pane_id> <session_id>" for every live Claude process. Claude writes
# ~/.claude/sessions/<pid>.json with its current sessionId and its tmux pane
# ("tmux":"0:@1.%2"; inside nvim that is nvim's pane). This catches sessions
# no hook has reported yet, e.g. ones started before the hooks were installed.
live_sessions() {
  local f pid json id pane
  for f in ~/.claude/sessions/*.json; do
    [ -f "$f" ] || continue
    pid=${f##*/}
    pid=${pid%.json}
    case $(ps -p "$pid" -o comm= 2>/dev/null) in
      claude | */claude) ;;
      *) continue ;; # stale file, process gone (or pid reused)
    esac
    json=$(<"$f")
    id=$(printf '%s' "$json" | sed -n 's/.*"sessionId" *: *"\([^"]*\)".*/\1/p')
    pane=$(printf '%s' "$json" | sed -n 's/.*"tmux" *: *"[^"]*\.\(%[0-9]*\)".*/\1/p')
    [ -n "$id" ] && [ -n "$pane" ] && echo "$pane $id"
  done
}

cmd_save() {
  # session<TAB>window<TAB>pane<TAB>command<TAB>ids (space-separated, newest last)
  # ids = what the hooks recorded (@claude_sessions) plus each live Claude's
  # current session, which goes last so it is the one resumed.
  "$TMUX_BIN" list-panes -a -F \
    '#{pane_id}	#{session_name}	#{window_index}	#{pane_index}	#{pane_current_command}	#{@claude_sessions}' |
    LIVE="$(live_sessions)" awk -F'\t' -v OFS='\t' '
      BEGIN {
        n = split(ENVIRON["LIVE"], rows, "\n")
        for (i = 1; i <= n; i++) if (split(rows[i], f, " ") == 2) cur[f[1]] = cur[f[1]] " " f[2]
      }
      {
        ids = $6
        m = split(cur[$1], add, " ")
        for (i = 1; i <= m; i++) {
          gsub("(^| )" add[i] "( |$)", " ", ids)
          ids = ids " " add[i]
        }
        gsub(/^ +| +$/, "", ids); gsub(/  +/, " ", ids)
        if (ids != "") print $2, $3, $4, $5, ids
      }' >"$tsv.tmp" && mv "$tsv.tmp" "$tsv"
}

cmd_markers() {
  local last s w p cmd ids
  last="$(resurrect_dir)/last"
  [ -f "$last" ] || return 0
  mkdir -p "$markers"
  # Every nvim pane in the save gets a marker; it holds the Claude session to
  # resume inside that nvim, if any.
  awk -F'\t' '$1 == "pane" && $10 == "nvim" { print $2 "\t" $3 "\t" $6 }' "$last" |
    while IFS=$'\t' read -r s w p; do
      ids=$(awk -F'\t' -v s="$s" -v w="$w" -v p="$p" \
        '$1 == s && $2 == w && $3 == p && $4 == "nvim" { print $5 }' "$tsv" 2>/dev/null)
      printf '%s\n' "${ids##* }" >"$markers/$(pane_key "$s" "$w" "$p")"
    done
}

cmd_restore() {
  local s w p cmd ids id dir
  [ -f "$tsv" ] || return 0
  while IFS=$'\t' read -r s w p cmd ids; do
    [ "$cmd" = claude ] || continue
    id=${ids##* }
    dir=$(session_cwd "$id")
    "$TMUX_BIN" send-keys -t "$s:$w.$p" \
      "${dir:+cd $(printf '%q' "$dir") && }claude --resume $id" C-m
  done <"$tsv"
}

case $1 in
  save) cmd_save ;;
  markers) cmd_markers ;;
  restore) cmd_restore ;;
  *) echo "usage: $0 {save|markers|restore}" >&2; exit 2 ;;
esac
