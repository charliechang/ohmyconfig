return   {
  "neovim/nvim-lspconfig",
  dependencies = {
    "hrsh7th/cmp-nvim-lsp",
  },
  config = function()
    local lspconfig = require("lspconfig")
    local util = require "lspconfig/util"
    local cmp_nvim_lsp = require("cmp_nvim_lsp")
    local capabilities = cmp_nvim_lsp.default_capabilities()
    local opts = { noremap = true, silent = true }
    local on_attach = function(client, bufnr)
      opts.buffer = bufnr

      -- set keybinds
      vim.cmd('noremap <silent> gi :Telescope lsp_implementations<CR>')
      vim.cmd('noremap <silent> gr :Telescope lsp_references<CR>')
      vim.cmd('noremap <silent> gd :Telescope lsp_definitions<CR>')
      vim.cmd('noremap <silent> ga :lua vim.lsp.buf.code_action()<CR>')
    end

    require("mason").setup()
    require("mason-lspconfig").setup()

    lspconfig.gopls.setup {
      on_attach = on_attach,
      capabilities = capabilities,
      cmd = {"gopls"},
      filetypes = { "go", "gomod", "gowork", "gotmpl" },
      root_dir = util.root_pattern("go.work", "go.mod", ".git"),
      settings = {
        gopls = {
          completeUnimported = true,
          usePlaceholders = true,
          analyses = {
            unusedparams = true,
          },
        },
      },
    }
  end,
}
