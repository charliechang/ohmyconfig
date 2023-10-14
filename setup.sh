#!/bin/bash
# Install homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install zsh git
brew install zsh git

# initialization $HOME~/.zshrc
touch ~/.zshrc
echo 'ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"' >> ~/.zshrc
echo 'alias ll="ls -la --color=auto"' >> ~/.zshrc
echo 'alias tmux="tmux -u"' >> ~/.zshrc
source ~/.zshrc

# Install powerlevel10k
git clone https://github.com/romkatv/powerlevel10k.git $ZSH_CUSTOM/themes/powerlevel10k
echo 'ZSH_THEME="powerlevel10k/powerlevel10k"' >> ~/.zshrc
echo 'source "$ZSH_CUSTOM/themes/powerlevel10k/powerlevel10k.zsh-theme"' >> ~/.zshrc
source ~/.zshrc
