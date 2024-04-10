return {
  'nvim-lualine/lualine.nvim',
  dependencies = { 
    'nvim-tree/nvim-web-devicons',
    'RRethy/base16-nvim'
  },
  config = function()
    require('lualine').setup{
      options = {theme = 'base16'}
    }
  end,
}
