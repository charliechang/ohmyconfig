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

-- C-h/j/k/l (normal, visual and terminal mode) live in core/nav.lua: they move
-- between windows and continue into tmux panes / terminal splits at the edge.

-- GitHub Copilot
keymap.set("n", "<leader>ce", ":Copilot enable<CR>", { desc = "Enable Copilot" })
keymap.set("n", "<leader>cd", ":Copilot disable<CR>", { desc = "Disable Copilot" })
keymap.set("n", "<leader>cp", ":Copilot panel<CR>", { desc = "Open Copilot panel" })
keymap.set("i", "<C-j>", 'copilot#Accept("\\<CR>")', { desc = "Accept Copilot suggestion", expr = true, replace_keycodes = false })
