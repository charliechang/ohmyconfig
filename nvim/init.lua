--[[
  brew install ripgrep fzf neovim
  mkdir -p ~/.config
  ln -sf $(pwd)/nvim ~/.config/nvim
  echo "alias vim='nvim'" >> ~/.zshrc
  echo "alias bat='bat --theme=base16'" >> ~/.zshrc
  echo "export LC_ALL='C'" >> ~/.zshrc
]]

require("plugins-setup")
require("core.keymaps")
require("core.options")
