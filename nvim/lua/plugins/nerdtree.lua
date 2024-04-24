return {
  "scrooloose/nerdtree",
  event = "VeryLazy",
  dependencies = { 
    "ryanoasis/vim-devicons"
  },
  config = function()
    vim.cmd("set wildignore+=*/tmp/*,*.so,*.swp,*.zip")
    vim.cmd("set wildignore+=*/site-packages/*,*.pyc,*.class,*.o")
    vim.cmd("set wildignore+=*/target/*")
--    vim.cmd("let NERDTreeIgnore = ['.o$','.pyc$','.class$']")
    vim.keymap.set("n", "<C-n>", ":NERDTreeToggle<CR>")
    vim.cmd("let g:NERDTreeWinSize=60")
  end,
}
