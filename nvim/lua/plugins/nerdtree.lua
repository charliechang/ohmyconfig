return {
  "scrooloose/nerdtree",
  config = function()
    vim.cmd("set wildignore+=*/tmp/*,*.so,*.swp,*.zip")
    vim.cmd("set wildignore+=*/site-packages/*,*.pyc,*.class,*.o")
    vim.cmd("set wildignore+=*/target/*")
    vim.cmd("let NERDTreeIgnore = ['.o$','.pyc$','.class$']")
    vim.keymap.set("n", "<C-n>", ":NERDTreeToggle<CR>")
  end,
}
