return {
  'David-Kunz/gen.nvim',
  opts = {
    model = 'llama3',
    display_mode = "split",
  },
  config = function()
    local gen = require('gen')

    gen.prompts['01_Fix_Typo_Only'] = {
      prompt = "Fix the following text if there are any typos, just output the final text:\n$text",
      replace = true,
    }

    gen.prompts['02_Enhance_Grammar_Spelling_Markdown'] = {
      prompt = "Modify the following text to improve grammar and spelling, just output the final text and try to keep original markdown format:\n$text",
      replace = true,
    }

    gen.prompts['03_Code_Completion'] = {
      prompt = "Complete the following code, just output the final code and comments without additional markdown around it:\n$text",
      replace = true,
    }

    gen.prompts['04_Explain_Code'] = {
      prompt = "Explain the following $filetype code:\n$text",
      replace = false,
    }

    vim.keymap.set('v', 'z=', ':Gen 01_Fix_Typo_Only<CR>')
    vim.keymap.set('v', 'zg', ':Gen<CR>')
  end,
}
