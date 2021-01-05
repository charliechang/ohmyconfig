#!/bin/bash

# Configure tmux.conf
ln -sf /tmp/ohmyconfig/.tmux.conf.fb.it2 ~/.tmux.conf

# Configure nvim
mkdir -p ~/.config/nvim
ln -sf /tmp/ohmyconfig/init.vim.fb.it2 ~/.config/nvim/init.vim
curl $(fwdproxy-config curl) -o ~/nvim -LO https://github.com/neovim/neovim/releases/download/stable/nvim.appimage

# Environment
chmod +x ~/nvim /tmp/ohmyconfig/mypbcopy.sh /tmp/ohmyconfig/sigma-lsp-status.sh /tmp/ohmyconfig/hgco
echo -e "alias vim=~/nvim\nalias hgco=/tmp/ohmyconfig/hgco\n" >> ~/.bashrc
source ~/.bashrc

# vim plugin
curl $(fwdproxy-config curl) -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
export https_proxy=http://fwdproxy:8080;~/nvim +PlugInstall +qall; unset https_proxy

# cd to right folder
if [[ "$TW_JOB_NAME" == "sigma" ]]; then 
  cd ~/si_sigma
elif [[ "$TW_JOB_NAME" == "www" ]]; then 
  cd ~/www
fi
