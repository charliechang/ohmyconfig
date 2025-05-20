return  {
  "mason-org/mason-lspconfig.nvim",
  dependencies = {
    {"mason-org/mason.nvim", opts = {} },
    "neovim/nvim-lspconfig",
    "WhoIsSethDaniel/mason-tool-installer.nvim",
  },
  opts = {
    ensure_installed = {
      "gopls",
      "pyright",
      "terraformls",
      "bashls",
      "rust_analyzer",
      "ts_ls",
      "dockerls",
      "docker_compose_language_service",
    },
  },
  config = function()
    local mason_tool_installer = require("mason-tool-installer")
    mason_tool_installer.setup({
      ensure_installed = {
        "pylint" ,          -- linter: python
        "codelldb",         -- for Rust
      },
    })
  end,
}
