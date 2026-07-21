-- Render mermaid diagrams as ASCII art (local plugin).
-- Implementation lives in lua/core/mermaid.lua; this spec wires it into lazy.
-- Requires the `mermaid-ascii` binary (see lua/core/mermaid.lua header).
return {
  "mermaid-ascii",                    -- local name (not a GitHub repo)
  dir = vim.fn.stdpath("config"),     -- local dir so lazy never clones
  lazy = false,
  keys = {
    { "<leader>mm", "<cmd>MermaidPopup<CR>", desc = "Render mermaid diagram as PNG (Sixel) in a tmux popup" },
    { "<leader>mi", "<cmd>MermaidInlineToggle<CR>", desc = "Toggle inline mermaid ASCII rendering" },
    { "<leader>ma", "<cmd>MermaidRender<CR>", desc = "Render mermaid diagram as ASCII (float)" },
  },
  config = function()
    -- auto = true: markdown buffers render their mermaid blocks in place on open.
    require("core.mermaid").setup({ auto = true })
  end,
}
