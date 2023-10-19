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
      vim.keymap.set("n", 'gi', require("telescope.builtin").lsp_implementations, { buffer = bufnr, desc = "[g]oto [i]mplementations" })
      vim.keymap.set("n", 'gr', require("telescope.builtin").lsp_references, { buffer = bufnr, desc = "[g]oto [r]eferences" })
      vim.keymap.set("n", 'gd', require("telescope.builtin").lsp_definitions, { buffer = bufnr, desc = "[g]oto [d]efinitions" })
      vim.keymap.set("n", 'ga', vim.lsp.buf.code_action, { buffer = bufnr, desc = "[g]oto [a]ctions" })
    end

    lspconfig["gopls"].setup {
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
    lspconfig["pyright"].setup({
      capabilities = capabilities,
      on_attach = on_attach,
      filetypes = {"python"},
      root_dir = util.root_pattern("requirements.txt",".git"),
    })

    lspconfig["terraformls"].setup{}
    vim.api.nvim_create_autocmd({"BufWritePre"}, {
      pattern = {"*.tf", "*.tfvars"},
      callback = function()
        vim.lsp.buf.format()
      end,
    })

    lspconfig["bashls"].setup{}
    vim.api.nvim_create_autocmd('FileType', {
      pattern = 'sh',
      callback = function()
        vim.lsp.start({
          name = 'bash-language-server',
          cmd = { 'bash-language-server', 'start' },
        })
      end,
    })

  end,
}
