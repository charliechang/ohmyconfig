#!/usr/bin/env python3
"""Pty proxy between the terminal split and `ssh -t` (used by tmux/remote.sh).

It passes every byte through unchanged, except for two in-band signals that
let C-h/j/k/l cross between the terminal app's splits and a *remote* tmux at
the speed of a keystroke (half a network round trip, no extra connection):

  terminal -> remote: when the terminal reports focus-in (ESC [ I) and the
      local machine just moved split focus (nav.sh's pending record), send a
      private key sequence just before it, telling the remote tmux which way
      the move went,
      so it selects the pane / nvim window on the side it was entered from.
      The remote tmux maps these sequences to User90..User93 (.tmux.conf).

  remote -> terminal: when the remote tmux runs off its edge, nav.sh puts a
      marker "@@nav:<L|D|U|R>:<n>@@" into the title the remote tmux sends.
      The marker is removed from the title here and the local split focus is
      moved (nav.sh term-move). <n> increases per request; repeats are ignored.

usage: nav-proxy.py <nav.sh> <ghostty|wt|none> -- <command...>
Exits with the command's exit status (remote.sh reconnects on ssh's 255).
"""
import errno
import fcntl
import os
import re
import select
import signal
import struct
import subprocess
import sys
import termios
import time
import tty

nav, kind = sys.argv[1], sys.argv[2]
cmd = sys.argv[sys.argv.index("--") + 1:]

state = os.path.join((os.environ.get("TMPDIR") or "/tmp").rstrip("/"), f"tmux-nav-{os.getuid()}")
pending = os.path.join(state, "pending")
ENTRY = {d: f"\x1b[{9001 + i}~".encode() for i, d in enumerate("LDUR")}
FOCUS_IN = b"\x1b[I"
MARK = re.compile(rb"@@nav:([LDUR]):(\d+)@@")


def note(msg):
    try:
        with open(os.path.join(state, "log"), "a") as f:
            f.write(time.strftime("%Y-%m-%d %H:%M:%S ") + f"proxy {msg}\n")
    except OSError:
        pass


def take():
    """nav.sh take, inline (it runs on every focus-in)."""
    try:
        with open(pending) as f:
            words = f.read().split()
        os.unlink(pending)
    except OSError:
        return None
    if len(words) == 2 and words[0] in ENTRY and time.time() - int(words[1]) <= 2:
        return words[0]
    return None


def winsize(fd_from, fd_to):
    try:
        size = fcntl.ioctl(fd_from, termios.TIOCGWINSZ, b"\0" * 8)
        fcntl.ioctl(fd_to, termios.TIOCSWINSZ, size)
    except OSError:
        pass


pid, master = os.forkpty()
if pid == 0:
    os.execvp(cmd[0], cmd)

stdin, stdout = sys.stdin.fileno(), sys.stdout.fileno()
winsize(stdin, master)
signal.signal(signal.SIGWINCH, lambda *_: (winsize(stdin, master), os.kill(pid, signal.SIGWINCH)))
saved = termios.tcgetattr(stdin) if os.isatty(stdin) else None
if saved:
    tty.setraw(stdin)

last_seq = None
held = b""  # output tail that may be the start of a split title sequence


def handle_output(data):
    global last_seq, held
    data = held + data
    held = b""
    # Hold back an unterminated OSC at the end (title split across reads).
    start = data.rfind(b"\x1b]")
    if start != -1 and b"\x07" not in data[start:] and b"\x1b\\" not in data[start + 2:]:
        if len(data) - start < 1024:
            data, held = data[:start], data[start:]

    def strip(m):
        global last_seq
        seq = (m.group(1).decode(), m.group(2).decode())
        if seq != last_seq:
            last_seq = seq
            note(f"edge marker {seq[1]}: move {seq[0]}")
            subprocess.Popen([nav, "term-move", seq[0], kind],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return b""

    return MARK.sub(strip, data) if b"@@nav:" in data else data


try:
    while True:
        try:
            ready, _, _ = select.select([stdin, master], [], [])
        except InterruptedError:
            continue
        if master in ready:
            try:
                data = os.read(master, 65536)
            except OSError as e:
                if e.errno == errno.EIO:  # child closed the pty
                    break
                raise
            if not data:
                break
            os.write(stdout, handle_output(data))
        if stdin in ready:
            data = os.read(stdin, 65536)
            if not data:
                break
            if FOCUS_IN in data:
                d = take()
                if d:
                    # Key *before* focus-in: tmux (3.6a) drops a key that
                    # directly follows a focus event unless another key came
                    # in between (docs/terminal-split-nav.md, lessons).
                    data = data.replace(FOCUS_IN, ENTRY[d] + FOCUS_IN, 1)
                note(f"focus-in, entered moving {d or '-'}")
            os.write(master, data)
finally:
    if held:
        os.write(stdout, held)
    if saved:
        termios.tcsetattr(stdin, termios.TCSAFLUSH, saved)

_, status = os.waitpid(pid, 0)
sys.exit(os.waitstatus_to_exitcode(status) if hasattr(os, "waitstatus_to_exitcode") else status >> 8)
