# Terminal-split navigation: one set of keys across local + remote tmux

Progress log for working on the **Mac + 10.0.0.4** pair and then the **WSL +
dev-server** pair. Update the *Status* and *Lessons* sections as you go, so each side
can learn from the other.

## Goal

A large monitor split by the **terminal app** (Ghostty on the Mac, Windows Terminal on
WSL): e.g. local tmux on the left, a remote tmux on the right, any mix of side-by-side
and stacked. **`C-h/j/k/l` moves through everything** — nvim windows, tmux panes and the
terminal's own splits, local or remote — and entering a split lands on the side you came
from. Remote work must survive a dropped connection (lid closed).

```
┌──────────── Ghostty / Windows Terminal window ─────────────┐
│ split: local tmux        │ split: remote.sh dev            │
│  (nvim, claude, ...)     │  → ssh → dev-server tmux        │
│                          ├─────────────────────────────────┤
│                          │ split: remote.sh 10.0.0.4       │
└────────────────────────────────────────────────────────────┘
```

No tmux inside tmux: each split has its own tmux and status bar, so images (Sixel /
kitty), clipboard and `C-b` behave exactly as before.

## How it works

| Piece | Role |
|---|---|
| `nvim/lua/core/nav.lua` | `C-h/j/k/l` (normal/visual/terminal mode) moves between nvim windows; at nvim's edge calls `nav.sh move`. Publishes `@nvim_sock`/`@nvim_bin` on its tmux pane so it can be told "you were entered moving X" over RPC. Replaces `nvim-tmux-navigation`. |
| `.tmux.conf` | `C-h/j/k/l`: nvim panes get the key, others run `nav.sh move` (no wrap-around). `client-focus-in` hook → `nav.sh focus-in`. `user-keys` `ESC[9001~..9004~` → `User90..93` → `nav.sh enter` (entry side from the proxy). |
| `tmux/nav.sh` | `move`: next tmux pane, else leave this tmux — local: move the terminal split (`term-move`), remote: put `@@nav:<dir>:<n>@@` in the title tmux sends. `enter`: select the pane (and nvim window) on the entry side. `term-move`: Ghostty AppleScript `perform action "goto_split:<dir>"` / `wt.exe -w 0 move-focus <dir>`; records the move in `$TMPDIR/tmux-nav-<uid>/pending` for 2 s. |
| `tmux/remote.sh <host> [session]` | Runs `ssh -t` inside `nav-proxy.py`; reconnects when ssh exits 255 (connection lost), stops on detach. Sets `TERM=xterm-256color` for Ghostty. |
| `tmux/nav-proxy.py` | Pty proxy in the byte stream. Terminal→remote: on focus-in (`ESC[I`) with a fresh pending move, inserts the entry key **before** the focus-in. Remote→terminal: strips the title marker and runs `nav.sh term-move`. Everything else passes through. |
| `tmux/remote-attach.sh` | Remote end: tmux server outside the ssh login (tmux.service / `systemd-run --scope` on Linux), picks the most recently attached session, attaches as a **grouped** session (`destroy-unattached`, `set-titles` for the marker), marks the client tty `@navproxy<tty>`. |
| `tmux/split-remote.sh <host> [session] [right\|down\|tab\|window]` | Opens a terminal split running `remote.sh` (Ghostty AppleScript `split`, WT `split-pane`); `tab`/`window`: a new WT tab/window (WSL only). |
| `terminal/ghostty-nav.conf`, `terminal/windows-terminal-nav.json` | Fallback `ctrl+alt+h/j/k/l` split navigation, same on both. |
| `terminal/install-windows-terminal.sh [host] [session]` | WSL: merges those WT keys into WT's `settings.json` and adds a **dev-server** profile running `remote.sh momo-dev 0` (fixed GUID, keeps `settings.json.bak`). |

Flows (dir = direction of travel):

- **Inside a tmux:** nvim → nav.sh move → `select-pane` → if the new pane is nvim, RPC
  `enter(dir)` → nvim jumps to its window on the entry side.
- **Local tmux edge → next split:** `term-move` writes pending, moves the terminal focus →
  the new split's terminal sends `ESC[I` → its local tmux hook takes pending → `enter`;
  a remote split's proxy takes pending → sends `ESC[900x~` + `ESC[I` → remote `enter`.
- **Remote tmux edge → next split:** remote nav.sh sets the title marker → proxy (local)
  sees it in the output, strips it, runs `term-move` locally → as above.
- **nvim with no tmux** in a split: `nav.lua` calls `term-move` at its edge and takes
  pending itself on `FocusGained`.

Debug log (both machines): `$TMPDIR/tmux-nav-<uid>/log` (`/tmp/tmux-nav-<uid>/log` when
`TMPDIR` is unset) — `move`, `term-move`, `enter`, `proxy focus-in` / `edge marker`.

## Status

### Mac + 10.0.0.4 (2026-11-22)

Tested headless (separate tmux servers, simulated keys with `send-keys -K`, a pty test
driver instead of Ghostty), over the real VPN connection to 10.0.0.4:

| Check | Result |
|---|---|
| tmux pane moves all 4 directions, no wrap at the outer edge | ✅ |
| nvim windows ↔ tmux panes, entering nvim lands on the entry-side window | ✅ |
| `C-l` out of an nvim `:terminal` (Claude) stays in terminal mode | ✅ |
| local split entered (focus-in + pending) selects the entry-side pane / nvim window | ✅ |
| remote edge → title marker → proxy → local `term-move`; marker never reaches the terminal | ✅ |
| remote split entered: proxy entry key → remote `enter` | ✅ 6/6 (after the key-order fix) |
| connection dropped (ssh SIGTERM → 255): reconnects in 3 s, remote process survives, old grouped session removed | ✅ |
| `prefix d` (detach) ends remote.sh, no reconnect | ✅ |
| attaches to the existing session as a grouped copy (`work` → `work-1`) | ✅ |
| **Real Ghostty, local splits** (Step A): AppleScript `goto_split`, focus-in entry from real splits | ✅ 13 moves each followed by the right-side `enter`; 3 `-> false` at the outer edge (correct); no permission prompt problems |
| **Real Ghostty + 10.0.0.4** (Step B): `split-remote.sh host 0`, `C-l` into / `C-h` out of the remote, side by side | ✅ (after reopening the split, lesson 10) |
| Step B stacked splits (`split-remote.sh host 0 down`, `C-j` / `C-k` across local ↔ remote) | ✅ |
| Step B several remote splits at once (own grouped session each: `0-3`, `0-4`, …) | ✅ |
| Step B sleep / lid close + reconnect | ⏳ |

Measured: ping to 10.0.0.4 ≈ 435 ms avg (VPN, `utun4`). Entry key → remote redraw
visible ≈ 0.41 s (≈ 1 round trip, like a keystroke echo).

### WSL + dev-server (2026-11-23)

Both on `c2b0c69` + this change; tmux 3.7b (Sixel build) on both, configs reloaded.
WSL reaches the dev-server through its existing IAP alias **`momo-dev`** (no new `dev`
alias needed). Driven from WSL with `nav.sh` calls in a real Windows Terminal window
(remote split left, local split right), not real keypresses yet:

| # | Check | Result |
|---|---|---|
| 1 | `tmux -V` | ✅ 3.7b on both (user-keys, client-focus-in OK) |
| 2 | `split-remote.sh momo-dev 0 window` | ✅ new WT window, grouped session `0-2`, `@navproxy_dev_pts_12` set |
| 4 | `nav.sh term-move L wt` | ✅ `wt.exe` runs **directly** from WSL (`-> sent`, no `cmd.exe` fallback), ≈ 190 ms per move |
| 5 | entering the remote split | ✅ WT sends focus events: `proxy focus-in, entered moving L` → dev-server `enter … moving L -> %0` |
| 6 | remote edge (`nav.sh move R` at the dev-server's right edge) | ✅ `title marker 1` → WSL `proxy edge marker 1: move R` → `term-move R wt -> sent`, < 1 s |
| 7 | connection dropped (local ssh SIGTERM) | ✅ reconnected as `0-3`; the old grouped session lingers until the dev-server's sshd drops the dead client (`ClientAliveInterval 120`, up to ~6 min) — harmless. Real sleep/lid close: ⏳ |
| 8 | tmux server unit | ✅ `tmux.service` (use `ps -o uunit=`: `unit=` shows the system-level `user@….service`) |
| 3, 9 | real `C-h/j/k/l` keypresses, incl. nvim and repeated entries on 3.7b | ⏳ needs a person at the keyboard (and nvim restarted for `core.nav`) |

## Lessons learned

1. **`select-pane -L` wraps** around at the edge; `nav.sh` checks `#{pane_at_left}` etc.
   and leaves the tmux instead.
2. **Reverse ssh socket (`ssh -R`) bridge was too slow over the VPN**: every request opens
   a new ssh channel, 1.5–2 round trips → 0.7–1 s per crossing. Replaced by in-band
   signalling in the existing byte stream (proxy): ½ round trip, and no python/sockets
   needed on the remotes.
3. **tmux drops a key that directly follows a focus event** (`ESC[I` + key) unless another
   key came in between — the first one works, repeats don't. Sending the key **before**
   `ESC[I` works every time. (tmux 3.6a; check 3.4 / 3.7b.)
4. **Title as the remote→local channel**: tmux only sends a title when it changes, so the
   marker carries a counter; the proxy ignores repeats and nav.sh clears the marker after
   1 s. `set-titles` is set only on the grouped session `remote-attach.sh` creates.
5. **Remotes lack `xterm-ghostty` terminfo** → tmux there refuses to start. `remote.sh`
   uses `TERM=xterm-256color`; Ghostty still identifies itself via XTVERSION
   (`client_termtype`), which `mermaid-popup.sh` uses for kitty graphics.
6. **Ghostty 1.4 AppleScript** (`Ghostty.app/Contents/Resources/Ghostty.sdef`):
   `perform action "goto_split:left" on focused terminal of selected tab of front window`
   returns `true`/`false` (false = no split that way); directions are
   `left|right|up|down`. `split <terminal> direction right with configuration cfg`,
   `set command of cfg to "..."`. Also `send key`, `input text` (paste), `tty`, `pid`.
7. **10.0.0.4**: user is `charlie.chang` (key auth works); tmux lives in `/opt/homebrew/bin`,
   which a non-login ssh command doesn't have on PATH → `remote-attach.sh` sets PATH.
   Its checkout has an uncommitted comment edit in
   `nvim/lua/plugins/vim-tmux-navigator.lua`, a file this change deletes: run
   `git checkout -- nvim/lua/plugins/vim-tmux-navigator.lua` there before pulling.
8. The tmux server on 10.0.0.4 (macOS) already survives disconnects (up since Nov 14);
   on Linux, `KillUserProcesses=yes` could kill a tmux started inside the ssh login —
   `remote-attach.sh` starts it via tmux.service or `systemd-run --user --scope`.
9. Testing: macOS `script` won't take a FIFO as stdin → use a python pty driver; killing
   the driver doesn't kill remote.sh/proxy/ssh children; `pgrep -f 'ssh -t'` also matches
   the proxy (its argv contains the ssh command) — match `'^ssh -t'`. Opening a new ssh
   connection to 10.0.0.4 takes ~5 s; use ControlMaster for test commands.
10. **Step B, first try (2026-11-22)**: a split opened *before* 10.0.0.4 pulled fell back
    to `tmux new -A -s main` (no titles); a later split on the same remote tty set
    `@navproxy_dev_ttys000`. Back in the old split, remote `C-h` sent markers (log:
    `title marker 27..32`) but `set-titles` was off in `main`, so nothing reached the Mac.
    Fix: nav.sh now switches titles on for the session whenever it signals a proxy
    client. Also: after the remote tmux server restarted (resurrect), all sessions looked
    equally recent and `remote-attach.sh` picked the stray `main` over `0` — pass the
    session explicitly (`split-remote.sh host 0`) until the choice is smarter.
11. **Windows terminal choice**: Ghostty has no official Windows build (only community
    forks). WezTerm runs from its portable zip without admin and has
    `wezterm cli activate-pane-direction` — an option if Windows Terminal's `wt.exe`
    focus moves feel too slow. Windows Terminal itself needs nothing installed.

12. **WSL + dev-server (2026-11-23)**: (a) a non-login `ssh host cmd` on the dev-server
    has no `~/.local/bin` on PATH, so a bare `tmux` there is apt's 3.4 client, which can't
    talk to the 3.7b server ("server exited unexpectedly"). `remote-attach.sh` sets PATH
    and `tmux.service` sets it for `run-shell`, so real use is fine — but prefix PATH when
    calling `nav.sh` over ssh in tests. (b) WSL's `momo-dev` has `DynamicForward 1080`
    (git → github/gitlab); a second connection used to warn "Address already in use", so
    `remote.sh` now adds `-o ClearAllForwardings=yes` when one of the host's forward ports
    is already listening (and keeps the forward when nothing holds it). (c) `wt.exe` splits
    its arguments on `;` — keep it out of commands passed through `split-remote.sh`.

## Try it on the Mac (Ghostty)

1. `tmux source ~/.tmux.conf` in the local tmux (or restart it); restart nvim (new
   `core.nav`; `:Lazy clean` removes the old nvim-tmux-navigation plugin).
2. In a Ghostty split running local tmux: `~/work/ohmyconfig/tmux/split-remote.sh charlie.chang@10.0.0.4`
   → a split on the right attached to 10.0.0.4's session.
   - First use: macOS may ask to allow controlling Ghostty — allow it.
   - 10.0.0.4 needs this repo pulled first (lesson 7) and `tmux source ~/.tmux.conf`
     in its server.
3. `C-l` from the local side → into the remote split's left pane / nvim window;
   `C-h` from the remote's leftmost pane → back to the local side's right pane.
4. Close the lid, reopen → the right split shows "reconnecting" and comes back with
   everything running.
5. Note anything odd in *Status* (and the log lines around it).

## WSL + dev-server checklist

Before: `git pull` on WSL and on the dev-server; `tmux source ~/.tmux.conf` in both
tmux servers; restart nvim on both (`:Lazy clean`); on WSL run
`terminal/install-windows-terminal.sh` (adds the **dev-server** WT profile = `remote.sh
momo-dev 0`, and the `ctrl+alt+h/j/k/l` fallback keys). From a shell:
`tmux/split-remote.sh momo-dev 0 [right|down|tab|window]`.

**WSL reaches the dev-server through Google IAP.** `remote.sh` runs plain
`ssh -t <host> …`, so give the dev-server an ssh alias whose `ProxyCommand` opens the IAP
tunnel (then `ssh dev`, `remote.sh dev` and `split-remote.sh dev` all work unchanged):

```
# ~/.ssh/config on WSL
Host dev
  HostName <instance-name>
  User <your-os-login-user>
  IdentityFile ~/.ssh/google_compute_engine
  ProxyCommand gcloud compute start-iap-tunnel %h 22 --listen-on-stdin --project=<project> --zone=<zone> --verbosity=warning
```

(`gcloud compute ssh --tunnel-through-iap` can't be dropped in: it takes its own flags
where remote.sh passes ssh's.) If WSL already has such an alias, use it. What IAP changes:

- Connecting is slower (gcloud starts a tunnel per connection) — fine, it only happens on
  (re)connect; all navigation signals ride the open connection.
- Reconnect after sleep may fail until `gcloud auth login` is redone; `remote.sh` backs
  off (3 → 6 → … 30 s) and says to run `ssh dev` by hand once it keeps failing.
- Record the crossing latency through IAP (log timestamps / feel) in *Status*.

| # | Check | Expect | Notes |
|---|---|---|---|
| 1 | `tmux -V` on WSL / dev-server | user-keys + client-focus-in need ≥ 3.2 | |
| 2 | In WT, split (`Alt+Shift+=`), run `tmux` left; right: `tmux/remote.sh dev` | dev-server session appears (grouped) | or `tmux/split-remote.sh dev` from the left split |
| 3 | `C-l` / `C-h` inside one tmux, incl. nvim | as on the Mac | |
| 4 | `C-l` at the local tmux's right edge | WT focus moves right | log: `term-move R wt -> sent` or `sent-cmd`; which one works? how long does it take? |
| 5 | Entering the dev-server split | lands on its left pane / nvim window | needs WT to send focus events (`ESC[I`) — log: `proxy focus-in, entered moving R` |
| 6 | `C-h` at the dev-server's left edge | WT focus moves left, lands on the local right pane | log: `proxy edge marker n: move L` then `term-move L wt` |
| 7 | Lid close / sleep, wake | "reconnecting", same session, work still running | through IAP: how long until back? needed `gcloud auth login`? |
| 8 | `ps -o uunit= -p $(tmux display -p '#{pid}')` on the dev-server | `tmux.service`, not `session-N.scope` | |
| 9 | Key-order lesson (3) on tmux 3.4 / 3.7b | entry works repeatedly | |

Unknowns going in (answered 2026-11-23): `wt.exe` runs directly from WSL; a WT focus
move takes ≈ 190 ms; WT reports focus in/out to the app.

## Open items / ideas

- Entering a terminal split can't align by position (terminals expose no split geometry);
  tmux picks the entry-side pane closest to the previously active one.
- The terminal's split layout isn't restored after a reboot (tmux-resurrect restores each
  tmux, not the terminal splits); `split-remote.sh` rebuilds a remote split in one command.
- Ghostty could get the entry side without timing (AppleScript `send key` into the new
  split) if the pending window ever misfires.
