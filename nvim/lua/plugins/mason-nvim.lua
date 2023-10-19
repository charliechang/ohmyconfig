return  {
  "williamboman/mason.nvim",
  dependencies = {"williamboman/mason-lspconfig.nvim"},
  opts = {
    ensure_installed = {
      "gopls",
      "pyright",
    },
    automatic_installation = true,
  },
}
