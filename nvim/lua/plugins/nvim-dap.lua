return {
  "mfussenegger/nvim-dap",
  config = function(_, opts)
    local dap = require("dap")
    dap.adapters.go = {
      type = "server",
      port = 40000,
    }
    dap.configurations.go = {
      {
        type = "go",
        name = "delve container debug",
        request = "attach",
        mode = "remote",
        substitutepath = {{
          from = "${workspaceFolder}",
          to = "/go/src",
        }},
      },
    }
    vim.keymap.set("n", '<leader>gdc', dap.continue, { desc = "[g]oto [d]ebug - [c]ontinue" })
    vim.keymap.set("n", '<leader>gdb', dap.toggle_breakpoint, { desc = "[g]oto [d]ebug - toggle [b]reakpoint" })
    vim.keymap.set("n", '<leader>gdo', dap.step_over, { desc = "[g]oto [d]ebug - step [o]ver" })
    vim.keymap.set("n", '<leader>gdi', dap.step_into, { desc = "[g]oto [d]ebug - step [i]nto" })
    vim.keymap.set("n", '<leader>gdp', ":lua require'dap'.repl.open({}, 'vsplit')<CR>")
  end
}
