local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  "scrooloose/nerdtree",
  "christoomey/vim-tmux-navigator",
  "Yggdroot/indentLine",
  "vim-airline/vim-airline",
  "bling/vim-bufferline",
  "junegunn/fzf",
  "duane9/nvim-rg",
  "xiyaowong/transparent.nvim",
})
