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

    -- Global keybindings for all LSPs via LspAttach (works regardless of how the LSP starts)
    vim.api.nvim_create_autocmd("LspAttach", {
      callback = function(args)
        local bufnr = args.buf
        vim.keymap.set("n", "gi", require("telescope.builtin").lsp_implementations, { buffer = bufnr, desc = "[g]oto [i]mplementations" })
        vim.keymap.set("n", "gr", require("telescope.builtin").lsp_references, { buffer = bufnr, desc = "[g]oto [r]eferences" })
        vim.keymap.set("n", "gd", require("telescope.builtin").lsp_definitions, { buffer = bufnr, desc = "[g]oto [d]efinitions" })
        vim.keymap.set("n", "ga", vim.lsp.buf.code_action, { buffer = bufnr, desc = "[g]oto [a]ctions" })
      end,
    })

    -- jdtls: auto-download Maven sources for navigating into library source code
    vim.lsp.config("jdtls", {
      settings = {
        java = {
          maven = {
            downloadSources = true,
          },
        },
      },
    })

    -- Configure LSP servers using the new vim.lsp.config API
    vim.lsp.config("pyright", {
      capabilities = capabilities,
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
    })

    vim.lsp.config("bashls", {
      capabilities = capabilities,
    })

    vim.lsp.config("ts_ls", {
      capabilities = capabilities,
    })

    vim.lsp.config("dockerls", {
      capabilities = capabilities,
      filetypes = {"dockerfile"},
    })

    vim.lsp.config("docker_compose_language_service", {
      capabilities = capabilities,
      filetypes = {"yaml"},
    })

    -- Enable all configured LSP servers
    vim.lsp.enable({
      "pyright",
      "terraformls",
      "bashls",
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
