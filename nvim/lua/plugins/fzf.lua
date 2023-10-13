return {
  "junegunn/fzf.vim",
  dependencies = {
    "junegunn/fzf",
  },
  config = function()
    vim.keymap.set("n", "<C-p>", ":Files<cr>")
    vim.keymap.set("n", "<C-f>", ":Rg <C-r><C-w><cr>")
  end,
}
