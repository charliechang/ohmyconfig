return {
   "duane9/nvim-rg",
  config = function()
    vim.keymap.set("n", "<C-f>", ":Rg <C-r><C-w><cr>")
  end,
 }
