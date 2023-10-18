return {
  'nvim-telescope/telescope.nvim', 
  tag = '0.1.4',
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function()
    vim.keymap.set("n", "<C-p>", "<cmd>Telescope find_files<cr>")
    vim.keymap.set("n", "<C-f>", ":Telescope live_grep default_text=<C-r><C-w><cr>")
  end,
}
