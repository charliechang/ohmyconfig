-- Render markdown (headings, tables, code blocks, lists, ...) in the buffer.
-- Paired with the inline mermaid renderer: <leader>mi toggles BOTH together
-- (see lua/core/md_render.lua). Rendering stays put regardless of cursor
-- position -- toggle off to edit.
return {
  "MeanderingProgrammer/render-markdown.nvim",
  dependencies = {
    "nvim-treesitter/nvim-treesitter", -- main branch; parsers ensured in config
    "nvim-tree/nvim-web-devicons",
  },
  ft = { "markdown" },
  keys = {
    {
      "<leader>mi",
      function()
        require("core.md_render").toggle()
      end,
      desc = "Toggle markdown + mermaid rendering",
    },
  },
  opts = {
    -- Stay rendered regardless of cursor / mode -- no auto-reveal for editing
    -- (matches the mermaid inline behaviour; toggle off with <leader>mi).
    anti_conceal = { enabled = false },
    render_modes = true, -- render in every mode, incl. insert
  },
  config = function(_, opts)
    -- Ensure the markdown treesitter parsers exist (nvim-treesitter main branch
    -- API). Without them render-markdown silently renders nothing.
    local ok, ts = pcall(require, "nvim-treesitter")
    if ok then
      local installed = ts.get_installed()
      local need = {}
      for _, lang in ipairs({ "markdown", "markdown_inline" }) do
        if not vim.list_contains(installed, lang) then
          need[#need + 1] = lang
        end
      end
      if #need > 0 then
        pcall(ts.install, need)
      end
    end

    require("render-markdown").setup(opts)
  end,
}
