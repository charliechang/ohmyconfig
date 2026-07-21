# ohmyconfig — Claude Code notes

Personal dotfiles / editor config (neovim, tmux, vim). This file orients a Claude Code
session working in this repo.

## Environment topology

The author works from **Windows → WSL → ssh → dev-server**. Neovim and tmux run on the
**dev-server**; edits are made there over ssh. A Claude session running in WSL sees the
repo via git (clone/pull), not the live editor.

## IMPORTANT: two checkouts exist on the dev-server

There are two clones of this repo on the dev-server, and they have **diverged** (different
commits, different remotes):

- `~/work/ohmyconfig` — **the live one.** `~/.config/nvim` symlinks to
  `~/work/ohmyconfig/nvim`, so this is what Neovim actually loads. **Edit here.**
- `/data/work/ohmyconfig` — a separate clone at a different commit. Not loaded by nvim.

Before editing nvim config, confirm the tree: `readlink -f ~/.config/nvim`.

## Neovim layout

- Plugin manager: **lazy.nvim**. `nvim/init.lua` requires `plugins-setup` (bootstraps
  lazy with `import = "plugins"`), then `core.keymaps` and `core.options`.
- Each plugin is one file under `nvim/lua/plugins/` that returns a lazy spec. Add new
  plugins that way — **do not** add `require(...).setup()` calls to `init.lua`.
- Leader key is `<Space>`.

## Feature: render mermaid diagrams

Renders ` ```mermaid ` fenced blocks (and whole `.mmd` / `.mermaid` files) two ways:
**inline ASCII** (always available) and a **real PNG shown as a Sixel image in a tmux
popup** (`<leader>mm`).

### View modes / keymaps

- **`<leader>mm` — PNG in a tmux window** (`:MermaidPopup`). The block under the cursor
  is rendered to a real PNG by `mermaid-cli` (`mmdc`) and displayed as a **Sixel** image
  in a temporary tmux **window**; press any key to close it and return to Neovim. This is
  the high-fidelity view (real mermaid, colors, readable labels). Needs a Sixel-capable
  tmux **and** terminal (see setup below). Two gotchas learned the hard way: (1) the image
  can't render *inline in the buffer* — Neovim redraws its grid over any Sixel; and (2) a
  `tmux display-popup` overlay does **not** composite Sixel, so a real window/pane is used
  instead. `chafa` is run with `--passthrough none` so tmux's **native** Sixel grid stores
  and redraws the image (its default `--passthrough tmux` bypasses that and the image gets
  wiped on the next redraw).
- **`<leader>mi` — inline ASCII toggle** (`:MermaidInlineToggle`). Opening a **markdown**
  buffer auto-renders every ```mermaid block *in place* as ASCII: source lines are
  concealed (`conceal_lines` extmark, needs Neovim ≥ 0.11) and the ASCII diagram is drawn
  as virtual lines where they were. The render **stays put regardless of cursor position**
  (it does *not* reveal source when you move into a block). To edit a block, toggle inline
  off with `<leader>mi` — that reveals all raw source; toggle back on when done.
  `:MermaidInlineRefresh` forces a redraw. Auto-enable is `setup({ auto = true })` in the
  lazy spec. Rendered ASCII is cached by block source, so unchanged blocks never re-run.
- **`<leader>ma` — ASCII float** (`:MermaidRender`). The old float view; a no-dependency
  fallback (only needs `mermaid-ascii`, no tmux/Sixel). Good for wide diagrams.

- Implementation: `nvim/lua/core/mermaid.lua`; popup helper `nvim/scripts/mermaid-popup.sh`
- Lazy spec:       `nvim/lua/plugins/mermaid.lua` (local plugin: `dir = stdpath("config")`)

### Dependencies

- **ASCII** (inline + float): the `mermaid-ascii` Go binary, found on `$PATH` or at
  `~/go/bin/mermaid-ascii`. Install:
  ```sh
  CGO_ENABLED=0 GOBIN=$HOME/go/bin go install github.com/AlexanderGrooff/mermaid-ascii@latest
  ```
  (`CGO_ENABLED=0` avoids the pixi Go toolchain's missing C compiler on this box.)
- **PNG popup**: `mmdc` (`@mermaid-js/mermaid-cli`), `chafa`, and a Sixel tmux + terminal.
  On the dev-server these are already set up (see next section).

### Sixel PNG setup (dev-server)

The stock `tmux 3.4` (apt) is **not** built with Sixel, so images can't pass through it.
Windows Terminal ≥ 1.22 speaks Sixel (confirmed 1.24). The working stack:

- **Sixel tmux**: conda-forge **tmux 3.7b** (built `--enable-sixel`) installed in a pixi
  env at `~/.local/share/tmux-sixel/`, shadowed onto PATH via a wrapper
  **`~/.local/bin/tmux`** (execs the env binary in-place so its RPATH libs resolve). The
  `tmux -u` alias resolves through it. Revert = delete the wrapper (falls back to
  `/usr/bin/tmux` 3.4).
- **`.tmux.conf`**: `set -ag terminal-features ",*:sixel"` advertises Sixel to apps.
- **mermaid-cli**: installed under `~/.local/share/mermaid-cli/`, `mmdc` symlinked into
  `~/.local/bin`. Uses system `/usr/bin/google-chrome` via
  `~/.config/mermaid/puppeteer.json` (no bundled Chromium download).
- **chafa**: `apt install chafa` (encodes PNG → Sixel; `mermaid-popup.sh` runs
  `chafa -f sixels`).
- A binary swap needs the tmux **server restarted** to take effect (`/usr/bin/tmux
  kill-server`, then start `tmux`; verify `tmux -V` → 3.7b). Sixel test in a pane:
  `chafa -f sixels --passthrough none ~/.local/share/mermaid-cli/sixel-test.png` (the
  `--passthrough none` is essential; see the `<leader>mm` note above).

### Limitations

- `mermaid-ascii` (ASCII modes) handles flowcharts/graphs and `sequenceDiagram`;
  class/gantt/state/pie are unsupported and left as **raw source** in inline mode (never
  concealed). `<br/>` in node labels shows literally. Wide diagrams may clip at the window
  edge inline — use `<leader>mm` (PNG popup) or `<leader>ma` (float).
- `mmdc` (PNG popup) renders the **full** mermaid spec (colors, all diagram types).

> To reproduce this whole setup (ASCII + Sixel PNG) on the Windows host **inside WSL**,
> see [`docs/mermaid-wsl-setup.md`](docs/mermaid-wsl-setup.md).
