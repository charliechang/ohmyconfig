--[[
  brew install ripgrep fzf neovim
  mkdir -p ~/.config
  ln -sf $(pwd)/nvim ~/.config/nvim
  echo "alias vim='nvim'" >> ~/.zshrc
  echo "alias bat='bat --theme=base16'" >> ~/.zshrc
  echo "export LC_ALL='C'" >> ~/.zshrc
  brew tap homebrew/cask-fonts
  brew install font-hack-nerd-font
  go install github.com/go-delve/delve/cmd/dlv@latest

  :MasonInstall rust-analyzer
  # Install Ollama (<https://ollama.com/>) and run `ollama pull llama3`
]]

require("plugins-setup")
require("core.keymaps")
require("core.options")
