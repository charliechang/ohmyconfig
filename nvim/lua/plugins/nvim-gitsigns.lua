return {
  "lewis6991/gitsigns.nvim",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    local gitsigns = require('gitsigns')

    gitsigns.setup{
       signs = {
         add          = { text = '' },
         change       = { text = '' },
         delete       = { text = '' },
         topdelete    = { text = '' },
         changedelete = { text = '' },
         untracked    = { text = '' },
       },
    }

    vim.keymap.set('n', 'hb', gitsigns.toggle_current_line_blame, {buffer = bufnr, desc = "gitsigns toogle [b]lame line"})
    vim.keymap.set('n', 'hB', function() gitsigns.blame_line{full=true} end, {buffer = bufnr, desc = "gitsigns toogle blame line with details"})
  end,
}
