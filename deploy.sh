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
SESSION_NAME="development"
if [[ "$TW_JOB_NAME" == "sigma" ]]; then 
  cd ~/si_sigma
  tmux new -d -s $SESSION_NAME
  tmux split-window -t $SESSION_NAME
  tmux send-keys -t $SESSION_NAME:0.0 "vim" ENTER
  tmux send-keys -t $SESSION_NAME:0.1 "haxlsh" ENTER
  tmux new-window -t $SESSION_NAME
  tmux send-keys -t $SESSION_NAME:1.0 "hg ssl" ENTER
elif [[ "$TW_JOB_NAME" == "www" ]]; then 
  cd ~/www
  tmux new -d -s $SESSION_NAME
  tmux send-keys -t $SESSION_NAME:0.0 "vim" ENTER
  tmux new-window -t $SESSION_NAME
  tmux send-keys -t $SESSION_NAME:1.0 "hg ssl" ENTER
fi
exec tmux a -t $SESSION_NAME # #for staying at the folder
