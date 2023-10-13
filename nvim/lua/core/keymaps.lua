local keymap = vim.keymap


keymap.set("n", "<C-n>", ":NERDTreeToggle<CR>")
keymap.set("n", "<C-p>", ":FZF<cr>")
keymap.set("n", "<C-f>", ":Rg <C-r><C-w><cr>")
