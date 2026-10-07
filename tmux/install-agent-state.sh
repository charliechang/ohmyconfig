#!/usr/bin/env bash
# Install the herdr-style tmux agent status (see agent-state.sh):
#   1. symlink agent-state.sh to ~/.local/bin/tmux-agent-state (used by .tmux.conf)
#   2. merge Claude Code hooks into ~/.claude/settings.json (idempotent; other hooks kept)
#   3. reload the tmux config if a server is running
set -euo pipefail

here=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
mkdir -p ~/.local/bin
ln -sfn "$here/agent-state.sh" ~/.local/bin/tmux-agent-state
echo "linked ~/.local/bin/tmux-agent-state -> $here/agent-state.sh"

settings=~/.claude/settings.json
mkdir -p ~/.claude
[ -f "$settings" ] || echo '{}' >"$settings"
cp "$settings" "$settings.bak"

python3 - "$settings" <<'PY'
import json, sys

path = sys.argv[1]
with open(path) as f:
    cfg = json.load(f)

CMD = "$HOME/.local/bin/tmux-agent-state set "
# (event, matcher, state)
WANT = [
    ("UserPromptSubmit", None, "working"),
    ("PreToolUse", None, "working"),
    ("PostToolUse", None, "working"),
    ("Notification", "permission_prompt|elicitation_dialog", "blocked"),
    ("Stop", None, "done"),
    ("SessionEnd", None, "clear"),
]

hooks = cfg.setdefault("hooks", {})
# Drop any previous copy of our entries, then re-add.
for event, groups in list(hooks.items()):
    for g in groups:
        g["hooks"] = [h for h in g.get("hooks", []) if "tmux-agent-state" not in h.get("command", "")]
    hooks[event] = [g for g in groups if g["hooks"]]
    if not hooks[event]:
        del hooks[event]

for event, matcher, state in WANT:
    group = {"hooks": [{"type": "command", "command": CMD + state, "timeout": 5}]}
    if matcher:
        group["matcher"] = matcher
    hooks.setdefault(event, []).append(group)

with open(path, "w") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
    f.write("\n")
print(f"merged agent-state hooks into {path} (backup: {path}.bak)")
PY

if tmux info >/dev/null 2>&1; then
  tmux source-file ~/.tmux.conf && echo "reloaded ~/.tmux.conf"
fi
echo "restart running Claude Code sessions to pick up the hooks"
