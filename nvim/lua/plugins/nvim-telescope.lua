return {
  "nvim-telescope/telescope.nvim", 
  tag = "v0.2.1",
  dependencies = { 
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    "nvim-treesitter/nvim-treesitter",
  },
  config = function()
    vim.keymap.set("n", "<C-p>", "<cmd>Telescope find_files<cr>")
    vim.keymap.set("n", "<C-f>", "<cmd>Telescope grep_string<cr>")
    vim.keymap.set("n", "<C-g>", "<cmd>Telescope live_grep<cr>")
  end,
}
