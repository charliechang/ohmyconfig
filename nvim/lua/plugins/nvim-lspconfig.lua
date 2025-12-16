return {
  "neovim/nvim-lspconfig",
  dependencies = {
    "hrsh7th/cmp-nvim-lsp",
  },
  config = function()
    local cmp_nvim_lsp = require("cmp_nvim_lsp")
    local capabilities = cmp_nvim_lsp.default_capabilities()
    -- Set default position encoding to silence the warning
    capabilities.general = capabilities.general or {}
    capabilities.general.positionEncodings = { "utf-16" }

    local on_attach = function(client, bufnr)
      -- set keybinds
      vim.keymap.set("n", 'gi', require("telescope.builtin").lsp_implementations, { buffer = bufnr, desc = "[g]oto [i]mplementations" })
      vim.keymap.set("n", 'gr', require("telescope.builtin").lsp_references, { buffer = bufnr, desc = "[g]oto [r]eferences" })
      vim.keymap.set("n", 'gd', require("telescope.builtin").lsp_definitions, { buffer = bufnr, desc = "[g]oto [d]efinitions" })
      vim.keymap.set("n", 'ga', vim.lsp.buf.code_action, { buffer = bufnr, desc = "[g]oto [a]ctions" })
    end

    -- Configure LSP servers using the new vim.lsp.config API
    vim.lsp.config("gopls", {
      capabilities = capabilities,
      on_attach = on_attach,
      cmd = {"gopls"},
      filetypes = { "go", "gomod", "gowork", "gotmpl" },
      root_markers = {"go.work", "go.mod", ".git"},
      settings = {
        gopls = {
          completeUnimported = true,
          usePlaceholders = true,
          analyses = {
            unusedparams = true,
          },
        },
      },
    })

    vim.lsp.config("pyright", {
      capabilities = capabilities,
      on_attach = on_attach,
      filetypes = {"python"},
      root_markers = {"requirements.txt", ".git"},
      settings = {
        python = {
          pythonPath = vim.fn.exepath("python3") or vim.fn.exepath("python"),
        },
      },
    })

    vim.lsp.config("terraformls", {
      capabilities = capabilities,
      on_attach = on_attach,
    })

    vim.lsp.config("bashls", {
      capabilities = capabilities,
      on_attach = on_attach,
    })

    vim.lsp.config("rust_analyzer", {
      capabilities = capabilities,
      on_attach = on_attach,
      filetypes = {"rust"},
      root_markers = {"Cargo.toml"},
    })

    vim.lsp.config("ts_ls", {
      capabilities = capabilities,
      on_attach = on_attach,
    })

    vim.lsp.config("dockerls", {
      capabilities = capabilities,
      on_attach = on_attach,
      filetypes = {"dockerfile"},
    })

    vim.lsp.config("docker_compose_language_service", {
      capabilities = capabilities,
      on_attach = on_attach,
      filetypes = {"yaml"},
    })

    -- Enable all configured LSP servers
    vim.lsp.enable({
      "gopls",
      "pyright",
      "terraformls",
      "bashls",
      "rust_analyzer",
      "ts_ls",
      "dockerls",
      "docker_compose_language_service",
    })

    -- Terraform format on save
    vim.api.nvim_create_autocmd({"BufWritePre"}, {
      pattern = {"*.tf", "*.tfvars"},
      callback = function()
        vim.lsp.buf.format()
      end,
    })
  end,
}
