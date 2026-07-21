# Replicating the mermaid rendering (ASCII + Sixel PNG) in WSL

This is a **self-contained runbook** to reproduce the Neovim mermaid features on a
Windows host, running everything **natively inside WSL** (Ubuntu). It mirrors the
dev-server setup documented in `../CLAUDE.md`, minus the `ssh` layer.

There are two features to reproduce:

1. **Inline ASCII** — opening a markdown file auto-renders every ` ```mermaid ` block in
   place as ASCII (`mermaid-ascii`). Toggle with `<leader>mi`. No image tech required.
2. **PNG in a tmux window** (`<leader>mm`) — renders the block under the cursor to a real
   PNG (`mermaid-cli` + Chromium) and shows it as a **Sixel** image in a temporary tmux
   window. Requires a Sixel-capable tmux **and** terminal.

---

## 0. Architecture in WSL

```
Windows Terminal (>= 1.22, speaks Sixel)
        │
        ▼
   WSL (Ubuntu)  ──►  tmux (Sixel build)  ──►  nvim
                                              ├─ mermaid-ascii  (inline ASCII)
                                              └─ <leader>mm → tmux new-window
                                                    → mmdc (PNG) → chafa (Sixel)
```

Unlike the dev-server (Windows → WSL → ssh → dev-server), here nvim/tmux run **in WSL**,
so the Sixel path is just `WSL tmux → Windows Terminal`. Simpler — no ssh in the middle.

> **This repo is the source of truth for config.** WSL can `git pull` `ohmyconfig`, and can
> also reach the dev-server (`scp`/`rsync`) if you'd rather copy a prebuilt binary than
> build it (noted where relevant).

---

## 1. Prerequisites (verify first)

| Component | Need | Check |
|---|---|---|
| Windows Terminal | ≥ 1.22 (Sixel) | Settings → About. 1.24 confirmed working. |
| Neovim | ≥ 0.11 (`conceal_lines` extmark) | `nvim --version` (dev-server runs 0.12.2) |
| Go | any recent | `go version` (only for building `mermaid-ascii`) |
| Node.js | ≥ 18 | `node --version` (dev-server: v26) |

If Neovim is older than 0.11, the inline renderer's line-conceal won't work. Install a
current Neovim (unstable PPA, the official AppImage, or `pixi global install neovim`).

Reference versions that work on the dev-server: nvim 0.12.2, tmux 3.7b, node 26, chafa
1.14, mermaid-cli (`mmdc`) 11.16, Chrome 149.

---

## 2. Clone the repo and symlink config

```sh
git clone <ohmyconfig-remote> ~/work/ohmyconfig      # or your preferred path
mkdir -p ~/.config ~/.local/bin

ln -sfn ~/work/ohmyconfig/nvim      ~/.config/nvim
ln -sf  ~/work/ohmyconfig/.tmux.conf ~/.tmux.conf

# Ensure ~/.local/bin is on PATH (add to ~/.zshrc or ~/.bashrc if missing):
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc ;; esac
```

The repo's `.tmux.conf` already contains the Sixel advertise line:

```tmux
set -ag terminal-features ",*:sixel"
```

---

## 3. Inline ASCII dependency — `mermaid-ascii`

The Lua module finds `mermaid-ascii` on `$PATH`, else `~/go/bin/mermaid-ascii`.

**Build it (needs Go):**

```sh
CGO_ENABLED=0 GOBIN=$HOME/go/bin go install github.com/AlexanderGrooff/mermaid-ascii@latest
```

`CGO_ENABLED=0` avoids needing a C compiler.

**Or copy it from the dev-server** (same Linux/x86_64 — a static Go binary):

```sh
scp <dev-server>:~/go/bin/mermaid-ascii ~/go/bin/mermaid-ascii
chmod +x ~/go/bin/mermaid-ascii
```

Verify: `~/go/bin/mermaid-ascii -h`. At this point, open any markdown file with a mermaid
block — **inline ASCII already works** (`<leader>mi` toggles). The rest of this doc is only
for the `<leader>mm` PNG view.

---

## 4. Sixel-capable tmux

WSL's apt tmux (3.4) is **not** built with Sixel. Two ways to get one:

### Option A — conda-forge tmux 3.7b via pixi (matches dev-server, no compiler)

```sh
# If you don't have pixi: curl -fsSL https://pixi.sh/install.sh | bash   (then restart shell)
mkdir -p ~/.local/share/tmux-sixel && cd ~/.local/share/tmux-sixel
pixi init . && pixi add tmux           # pulls tmux 3.7b (built --enable-sixel)

# Wrapper so `tmux` on PATH resolves to the Sixel build (runs the env binary
# in-place so its RPATH libs resolve):
cat > ~/.local/bin/tmux <<'SH'
#!/bin/sh
exec "$HOME/.local/share/tmux-sixel/.pixi/envs/default/bin/tmux" "$@"
SH
chmod +x ~/.local/bin/tmux
```

(`micromamba`/`conda` work too: `micromamba create -n tmux -c conda-forge tmux` and point
the wrapper at that env's `bin/tmux`.)

### Option B — build tmux from source with `--enable-sixel`

```sh
sudo apt update
sudo apt install -y build-essential libevent-dev libncurses-dev bison pkg-config git
git clone https://github.com/tmux/tmux.git /tmp/tmux && cd /tmp/tmux
sh autogen.sh
./configure --enable-sixel --prefix="$HOME/.local"
make -j"$(nproc)" && make install     # installs ~/.local/bin/tmux
```

### Verify the build has Sixel

```sh
tmux -V                                # tmux 3.7b (or your built version)
strings "$(command -v tmux)" | grep -qi sixel && echo "sixel: present" || echo "sixel: MISSING"
```

---

## 5. chafa (PNG → Sixel encoder)

```sh
sudo apt install -y chafa
chafa --version
```

---

## 6. mermaid-cli (`mmdc`) + a browser

`mmdc` renders mermaid → PNG using headless Chromium (via puppeteer).

```sh
# Chromium runtime libs puppeteer needs:
sudo apt install -y libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 \
  libxkbcommon0 libxcomposite1 libxdamage1 libxfixes3 libxrandr2 libgbm1 \
  libpango-1.0-0 libcairo2 libasound2

# Install mermaid-cli into a dedicated dir (survives node/pixi churn) + symlink mmdc:
mkdir -p ~/.local/share/mermaid-cli && cd ~/.local/share/mermaid-cli
echo '{}' > package.json
npm install @mermaid-js/mermaid-cli          # lets puppeteer download a matching Chromium
ln -sf ~/.local/share/mermaid-cli/node_modules/.bin/mmdc ~/.local/bin/mmdc
```

**Browser choice:**

- **Simplest (WSL):** let puppeteer download its bundled Chromium — the `npm install` above
  does this. No config file needed; skip the `puppeteer.json` below.
- **Use a system browser instead** (e.g. you installed Google Chrome in WSL, or want to
  match the dev-server): create `~/.config/mermaid/puppeteer.json` and the render script
  will pass it automatically:

  ```sh
  mkdir -p ~/.config/mermaid
  cat > ~/.config/mermaid/puppeteer.json <<'JSON'
  {
    "executablePath": "/usr/bin/google-chrome",
    "args": ["--no-sandbox", "--disable-gpu", "--disable-dev-shm-usage"]
  }
  JSON
  ```

  (If you skip this file, `mermaid-popup.sh` just runs `mmdc` with no `-p`, using the
  bundled Chromium.)

Verify:

```sh
printf 'flowchart LR\n A-->B\n' > /tmp/t.mmd
mmdc -i /tmp/t.mmd -o /tmp/t.png && file /tmp/t.png     # -> PNG image data
```

---

## 7. Restart tmux and verify Sixel end-to-end

A binary swap only takes effect on a **fresh tmux server**.

```sh
# From OUTSIDE tmux (or kill the old server first):
tmux kill-server 2>/dev/null
tmux                                    # new server = the Sixel build
tmux -V                                 # confirm 3.7b / your build
```

**Sixel smoke test — must show the image and it must STAY:**

```sh
mmdc -i /tmp/t.mmd -o /tmp/t.png -b white -s 3
chafa -f sixels --passthrough none /tmp/t.png ; sleep 5
```

- ✅ image stays for 5s → Sixel works through tmux.
- ❌ image flashes then vanishes → you dropped `--passthrough none` (see Troubleshooting).

---

## 8. Verify the Neovim features

```sh
nvim some-file-with-mermaid.md
```

- **Inline ASCII**: mermaid blocks auto-render on open. `<leader>mi` toggles rendering off
  (reveals raw source for editing) and back on — see §9, it toggles markdown too.
  `:MermaidRender` = ASCII in a float. `<leader>mm` = the PNG view.
- **PNG**: cursor inside a **flowchart** block → `<leader>mm` → a new tmux window shows the
  crisp diagram; press any key to return to nvim.

Render log for debugging: `/tmp/mermaid-popup.log`.

---

## 9. Markdown rendering (render-markdown.nvim)

Separate from mermaid, the config renders markdown in the buffer (headings, tables, code,
lists…) via `render-markdown.nvim`, and **`<leader>mi` toggles markdown + mermaid together**.
lazy installs the plugin automatically; you only need the treesitter pieces:

```sh
# 1) tree-sitter CLI — REQUIRED to compile parsers on nvim-treesitter's `main`
#    branch (there is no bundled C-compiler path anymore).
mkdir -p ~/.local/share/tree-sitter-cli && cd ~/.local/share/tree-sitter-cli
echo '{}' > package.json
npm install tree-sitter-cli
ln -sf ~/.local/share/tree-sitter-cli/node_modules/.bin/tree-sitter ~/.local/bin/tree-sitter
tree-sitter --version
```

The `render-markdown.lua` spec self-installs the `markdown` + `markdown_inline` parsers on
first load (`require('nvim-treesitter').install(...)`). To do it up front:

```sh
nvim --headless -c 'lua require("nvim-treesitter").install({"markdown","markdown_inline"})' -c 'sleep 60' -c qa
# verify:
ls ~/.local/share/nvim/site/parser/ | grep markdown     # markdown.so, markdown_inline.so
```

`nvim-treesitter` (main branch) and `nvim-web-devicons` come in as plugins; a C compiler
(`cc`/`gcc`) must also be present for the CLI to build the parser objects.

**Verify:** open a markdown file with a table → it renders as a bordered box; `<leader>mi`
toggles the table **and** the mermaid diagrams off/on together. Rendering stays put
regardless of the cursor (toggle off to edit).

**Gotcha:** if parser install fails with `'tree-sitter' … no such file or directory`, the
CLI (above) isn't on `PATH`.

---

## 10. Troubleshooting (all learned the hard way)

| Symptom | Cause / fix |
|---|---|
| Sixel image **flashes then disappears** | `chafa` defaults to `--passthrough tmux`, which bypasses tmux's native Sixel grid so tmux wipes it on redraw. Always use **`--passthrough none`** (the script does). |
| `<leader>mm` window shows text but **no image** | You're using `tmux display-popup` — popup overlays **don't composite Sixel**. Use a real window/pane (the script uses `tmux new-window`). |
| `<leader>mm` popup empty / mmdc failed | `node` not on the popup's PATH (a non-interactive shell doesn't source `.zshrc`). `mermaid-popup.sh` prepends `~/.local/bin ~/.pixi/bin ~/.pixi/envs/nodejs/bin`; if your node lives elsewhere, add its dir to that `export PATH=` line, or `tmux set-environment -g PATH ...`. |
| No image at all, even standalone | Windows Terminal < 1.22 (no Sixel), or your tmux lacks the Sixel build (`strings $(command -v tmux) \| grep sixel`). |
| Inline ASCII doesn't conceal source | Neovim < 0.11 (no `conceal_lines`). Upgrade Neovim. |
| Some blocks stay as raw source inline | `mermaid-ascii` can't render class/gantt/state/pie — expected; use `<leader>mm` (full mermaid via `mmdc`). |
| `mmdc` errors about sandbox / Chromium | Install the libs in §6; puppeteer needs `--no-sandbox` under some WSL setups (already in `puppeteer.json`). |
| **Markdown/tables don't render** (`<leader>mi`) | markdown treesitter parsers missing (§9). If parser install said `'tree-sitter' … no such file`, the `tree-sitter` CLI isn't on `PATH`; install it (§9) then re-open. |

---

## 11. Reverting

```sh
rm ~/.local/bin/tmux            # back to system tmux (3.4)
tmux kill-server && tmux        # restart
# optional: remove the Sixel line from .tmux.conf, and the ~/.local/share/{tmux-sixel,mermaid-cli} dirs
```

---

## Files involved (in this repo)

- `nvim/lua/core/mermaid.lua` — mermaid rendering (ASCII float, inline, PNG window).
- `nvim/lua/plugins/mermaid.lua` — mermaid lazy spec + `<leader>mm` keymap.
- `nvim/scripts/mermaid-popup.sh` — the `mmdc` → `chafa` Sixel render script.
- `nvim/lua/plugins/render-markdown.lua` — markdown rendering + `<leader>mi` combined toggle.
- `nvim/lua/core/md_render.lua` — flips markdown + mermaid rendering together.
- `.tmux.conf` — `set -ag terminal-features ",*:sixel"`.
- `CLAUDE.md` — the dev-server-side notes this doc parallels.
