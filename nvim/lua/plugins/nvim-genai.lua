return {
  'David-Kunz/gen.nvim',
  opts = {
    model = 'llama3',
    display_mode = "split",
  },
  config = function()
    local gen = require('gen')

    gen.prompts['Enhance_Grammar_Spelling_Markdown'] = {
      prompt = "Modify the following text to improve grammar and spelling, just output the final text and try to keep original markdown format:\n$text",
      replace = true,
    }

    vim.keymap.set('v', 'z=', ':Gen Enhance_Grammar_Spelling_Markdown<CR>')
  end,
}
