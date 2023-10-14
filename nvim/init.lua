--[[
  brew install ripgrep fzf neovim
  mkdir -p ~/.config
  ln -sf $(pwd)/nvim ~/.config/nvim
  echo "alias vim='nvim'" >> ~/.zshrc
  echo "alias bat='bat --theme=base16'" >> ~/.zshrc
  echo "export LC_ALL='C'" >> ~/.zshrc
  brew tap homebrew/cask-fonts
  brew install font-hack-nerd-font
]]

require("plugins-setup")
require("core.keymaps")
require("core.options")
