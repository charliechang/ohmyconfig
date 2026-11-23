#!/usr/bin/env bash
# Windows Terminal setup, run from WSL (a no-op elsewhere). Edits WT's
# settings.json (keeps settings.json.bak; WT reloads it by itself):
#   1. a "dev-server" profile that opens the remote tmux through tmux/remote.sh
#      (reconnects, grouped session, C-h/j/k/l across splits)
#   2. the fallback ctrl+alt+h/j/k/l split moves from windows-terminal-nav.json
# Reruns replace both (the profile by its fixed GUID, actions by their keys).
# From a shell, the same thing without the profile:
#   tmux/split-remote.sh momo-dev 0 window|tab|right|down
# Design + progress: docs/terminal-split-nav.md
#
# usage: install-windows-terminal.sh [ssh-host] [session]   (default: momo-dev 0)
set -euo pipefail

if ! grep -qi microsoft /proc/version; then
  echo "not WSL: nothing to do"
  exit 0
fi

here=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
repo=${here%/*}
host=${1:-momo-dev}
session=${2:-0}

localappdata=$(wslpath "$(cd /mnt/c && cmd.exe /c 'echo %LOCALAPPDATA%' 2>/dev/null | tr -d '\r')")
settings=
for f in "$localappdata"/Packages/Microsoft.WindowsTerminal_*/LocalState/settings.json \
         "$localappdata/Microsoft/Windows Terminal/settings.json"; do
  [ -f "$f" ] && { settings=$f; break; }
done
[ -n "$settings" ] || { echo "Windows Terminal settings.json not found" >&2; exit 1; }

python3 - "$settings" "$here/windows-terminal-nav.json" "${WSL_DISTRO_NAME:-Ubuntu}" \
  "$repo/tmux/remote.sh $host $session" "$host" <<'PY'
import json, shutil, sys
path, nav, distro, cmd, host = sys.argv[1:]
try:
    cfg = json.load(open(path, encoding="utf-8-sig"))
except ValueError as e:
    sys.exit(f"{path} is not plain JSON (comments?): {e}. Edit it by hand.")

profile = {
    "guid": "{9a6f39c8-273a-42f0-b0b9-5a2450bde616}",
    "name": "dev-server",
    "commandline": f'wsl.exe -d {distro} --cd ~ -e bash -lc "{cmd}"',
    "tabTitle": host,
    "icon": "\U0001F5A5",
    "hidden": False,
}
profiles = cfg.setdefault("profiles", {})
if isinstance(profiles, list):
    profiles = cfg["profiles"] = {"list": profiles}
lst = [p for p in profiles.setdefault("list", []) if p.get("guid") != profile["guid"]]
profiles["list"] = lst + [profile]

new = json.load(open(nav))["actions"]
keys = {a["keys"] for a in new}
cfg["actions"] = [a for a in cfg.get("actions", []) if a.get("keys") not in keys] + new
# Newer WT keeps key bindings in "keybindings"; drop clashing ones there too.
if "keybindings" in cfg:
    cfg["keybindings"] = [k for k in cfg["keybindings"] if k.get("keys") not in keys]

shutil.copy2(path, path + ".bak")
with open(path, "w", encoding="utf-8") as f:
    json.dump(cfg, f, indent=4, ensure_ascii=False)
    f.write("\n")
print(f"profile 'dev-server' ({cmd}) + {len(new)} ctrl+alt nav keys -> {path}")
PY
