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
- **`<leader>mi` — toggle inline rendering** (markdown **and** mermaid together, see the
  *render markdown* section below). Opening a **markdown** buffer auto-renders every
  ```mermaid block *in place* as ASCII: source lines are concealed (`conceal_lines`
  extmark, needs Neovim ≥ 0.11) and the ASCII diagram is drawn as virtual lines where they
  were. The render **stays put regardless of cursor position** (it does *not* reveal source
  when you move into a block). To edit, toggle off with `<leader>mi` — that reveals all raw
  source (both the mermaid blocks and the markdown) — then toggle back on. Rendered ASCII is
  cached by block source, so unchanged blocks never re-run. Mermaid-only commands still
  exist: `:MermaidInlineToggle` / `:MermaidInlineRefresh`. Auto-enable is
  `setup({ auto = true })` in the lazy spec.
- **`:MermaidRender` — ASCII float** (no keymap). A no-dependency fallback (only needs
  `mermaid-ascii`, no tmux/Sixel). Good for wide diagrams.

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
  edge inline — use `<leader>mm` (PNG popup) or `:MermaidRender` (ASCII float).
- `mmdc` (PNG popup) renders the **full** mermaid spec (colors, all diagram types).

> To reproduce this whole setup (ASCII + Sixel PNG) on the Windows host **inside WSL**,
> see [`docs/mermaid-wsl-setup.md`](docs/mermaid-wsl-setup.md).

## Feature: render markdown (render-markdown.nvim)

Renders markdown **in the buffer** — headings, tables, code blocks, lists, quotes, etc. —
via [`render-markdown.nvim`](https://github.com/MeanderingProgrammer/render-markdown.nvim).

- Lazy spec: `nvim/lua/plugins/render-markdown.lua` (loads on `ft = markdown`). Configured
  with `anti_conceal = { enabled = false }` and `render_modes = true` so the render **stays
  put regardless of cursor or mode** (no per-line auto-reveal) — matching the mermaid inline
  behaviour. Toggle off to edit.
- **`<leader>mi` toggles markdown *and* mermaid together.** The keymap lives in the
  render-markdown spec and calls `nvim/lua/core/md_render.lua`, which flips both renderers
  for the buffer in sync (mermaid inline is the source of truth for the shared on/off
  state). Both auto-render when a markdown buffer opens.
- Dependencies: **`nvim-treesitter` (main branch)** with the **`markdown` + `markdown_inline`
  parsers**, and **`nvim-web-devicons`** — all already installed. The render-markdown spec
  self-installs the parsers if missing (`require('nvim-treesitter').get_installed()` /
  `.install()`).
- **`tree-sitter` CLI** is required to *compile* parsers on the treesitter `main` branch
  (the classic `:TSInstall` C-compiler path is gone). Installed under
  `~/.local/share/tree-sitter-cli/` with `tree-sitter` symlinked into `~/.local/bin`
  (`npm install tree-sitter-cli`). Without it, parser install fails with
  `'tree-sitter' … no such file or directory`.

> The WSL replication runbook [`docs/mermaid-wsl-setup.md`](docs/mermaid-wsl-setup.md)
> covers this too (treesitter parsers + `tree-sitter` CLI + render-markdown).
