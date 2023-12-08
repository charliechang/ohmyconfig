return {
  "rcarriga/nvim-dap-ui",
  dependencies = {
    "mfussenegger/nvim-dap",
  },
  config = function(_, opts)
    require("dapui").setup()
  end
}
