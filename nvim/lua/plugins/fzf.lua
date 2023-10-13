return {
  "junegunn/fzf.vim",
  dependencies = {
    "junegunn/fzf",
  },
  config = function()
    vim.keymap.set("n", "<C-p>", ":Files<cr>")
  end,
}
