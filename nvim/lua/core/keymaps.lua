local keymap = vim.keymap

-- Normal mode
keymap.set("n", "<C-n>", ":NERDTreeToggle<CR>")
keymap.set("n", "<C-p>", ":FZF<cr>")
keymap.set("n", "<C-f>", ":Rg <C-r><C-w><cr>")

-- Command-line mode
vim.cmd("cnoreabbrev Q! q!")
vim.cmd("cnoreabbrev Wq wq")
vim.cmd("cnoreabbrev WQ wq")
