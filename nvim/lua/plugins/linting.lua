return {
  "mfussenegger/nvim-lint",
  lazy = true,
  event = { "BufReadPre", "BufNewFile" }, -- to disable, comment this out
  config = function()
    local lint = require("lint")
    lint.linters_by_ft = {
      python = { "pylint" },
      go = { "golangcilint" },
    }

    -- Configure pylint to use the correct Python interpreter
    lint.linters.pylint.cmd = vim.fn.exepath("python3") or vim.fn.exepath("python")
    lint.linters.pylint.args = {
      "-m", "pylint",
      "--output-format=text",
      "--msg-template='{path}:{line}:{column}:{C}: [{symbol}] {msg}'",
      "--reports=no"
    }

    local lint_augroup = vim.api.nvim_create_augroup("lint", { clear = true })
    vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
      group = lint_augroup,
      callback = function()
        lint.try_lint()
      end,
    })
  end,
}
