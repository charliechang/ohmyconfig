return  {
  "williamboman/mason.nvim",
  dependencies = {
    "williamboman/mason-lspconfig.nvim",
    "WhoIsSethDaniel/mason-tool-installer.nvim",
  },
  config = function()
    local mason = require("mason")
    local mason_lspconfig = require("mason-lspconfig")
    local mason_tool_installer = require("mason-tool-installer")

    mason.setup()

    mason_lspconfig.setup({
      -- list of servers for mason to install
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
      automatic_installation = true, -- not the same as ensure_installed
    })

    mason_tool_installer.setup({
      ensure_installed = {
        "pylint" ,          -- linter: python
        "golangci-lint",    -- linter: go
        "codelldb",         -- for Rust
      },
    })
  end,
}
