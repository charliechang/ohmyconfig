return {
  "yetone/avante.nvim",
  event = "VeryLazy",
  lazy = false,
  --version = false,
  version = '0.0.9',
  opts = {
    provider = "azure",
    --provider = "ollama7b",
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
      ollama7b = {
        ["local"] = true,
        endpoint = "127.0.0.1:11434/v1",
        model = "qwen2.5-coder:7b",
        parse_curl_args = function(opts, code_opts)
          return {
            url = opts.endpoint .. "/chat/completions",
            headers = {
              ["Accept"] = "application/json",
              ["Content-Type"] = "application/json",
            },
            body = {
              model = opts.model,
              messages = require("avante.providers").copilot.parse_messages(code_opts), -- you can make your own message, but this is very advanced
              max_tokens = 2048,
              stream = true,
            },
          }
        end,
        parse_response_data = function(data_stream, event_state, opts)
          require("avante.providers").copilot.parse_response(data_stream, event_state, opts)
        end,
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
