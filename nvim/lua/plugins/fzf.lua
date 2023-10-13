return {
  "junegunn/fzf",
  config = function()
    vim.keymap.set("n", "<C-p>", ":FZF<cr>")
  end,
}
