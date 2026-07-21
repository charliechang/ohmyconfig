-- Load nvim-jdtls to register its jdt:// URI handler (BufReadCmd autocmd).
-- jdtls itself is started by mason-lspconfig + lspconfig's built-in config.
return {
  "mfussenegger/nvim-jdtls",
  ft = "java",
}
