return  {
  "mason-org/mason-lspconfig.nvim",
  dependencies = {
    {"mason-org/mason.nvim", opts = {} },
    "neovim/nvim-lspconfig",
    "WhoIsSethDaniel/mason-tool-installer.nvim",
  },
  config = function()
    require("mason").setup()
    require("mason-lspconfig").setup({
      ensure_installed = {
        "pyright",
        "terraformls",
        "bashls",
        "ts_ls",
        "dockerls",
        "docker_compose_language_service",
        "jdtls",
      },
    })
    require("mason-tool-installer").setup({
      ensure_installed = {},
    })
  end,
}
