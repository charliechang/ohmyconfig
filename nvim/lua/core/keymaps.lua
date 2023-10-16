local keymap = vim.keymap

-- Command-line mode
vim.cmd("cnoreabbrev Q! q!")
vim.cmd("cnoreabbrev Wq wq")
vim.cmd("cnoreabbrev WQ wq")

keymap.set("n", "b1", ":b1<CR>")
keymap.set("n", "b2", ":b2<CR>")
keymap.set("n", "b3", ":b3<CR>")
keymap.set("n", "b4", ":b4<CR>")
keymap.set("n", "b5", ":b5<CR>")
keymap.set("n", "b6", ":b6<CR>")
keymap.set("n", "b7", ":b7<CR>")
keymap.set("n", "b8", ":b8<CR>")
keymap.set("n", "b9", ":b9<CR>")

keymap.set("n", "<C-S>", ":w!<CR>")
