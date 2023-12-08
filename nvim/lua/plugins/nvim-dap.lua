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
  end
}
