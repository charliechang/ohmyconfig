return {
  "yetone/avante.nvim",
  event = "VeryLazy",
  lazy = false,
  version = '0.0.23',
  opts = {
    --provider = "azure",
    provider = "llm-gateway",
    openai = {
      model = "gpt-4o-mini",
    },
    azure = {
      api_version = "2024-02-15-preview",
      deployment = "CTOTestingUsage",
      endpoint = "https://ctoenvtestingcanadaeast.openai.azure.com",
    },
    vendors = {
      ---@type AvanteProvider
      ["llm-gateway"] = {
        __inherited_from = 'openai',
        endpoint = "https://llm-gateway.engineering-dev.kkcompany-internal.com/v1",
        model = "gpt-4o",
        api_key_name = "LLM_GATEWAY_TOKEN",
      },
    },
    windows = {
      width = 50,
    },
    auto_suggestions_provider = "azure",
    behaviour = {
      auto_suggestions = false,
    },
  },
  -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
  build = "make",
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "stevearc/dressing.nvim",
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    --- The below dependencies are optional,
    "echasnovski/mini.pick", -- for file_selector provider mini.pick
    "nvim-telescope/telescope.nvim", -- for file_selector provider telescope
    "hrsh7th/nvim-cmp", -- autocompletion for avante commands and mentions
    "ibhagwan/fzf-lua", -- for file_selector provider fzf
    "nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
    "zbirenbaum/copilot.lua", -- for providers='copilot'
    {
      -- support for image pasting
      "HakonHarnes/img-clip.nvim",
      event = "VeryLazy",
      opts = {
        -- recommended settings
        default = {
          embed_image_as_base64 = false,
          prompt_for_file_name = false,
          drag_and_drop = {
            insert_mode = true,
          },
          -- required for Windows users
          use_absolute_path = true,
        },
      },
    },
    {
      -- Make sure to set this up properly if you have lazy=true
      'MeanderingProgrammer/render-markdown.nvim',
      opts = {
        file_types = { "markdown", "Avante" },
      },
      ft = { "markdown", "Avante" },
    },
  },
}
