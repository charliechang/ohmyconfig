" #### Actions ####
" brew install ack
" ln -sf $(pwd)/.vimrc ~/
" vim +PluginInstall +qall
" stty -ixon >> ~/.zshrc


set nocompatible              " be iMproved, required

filetype plugin indent on
" filetype off                  " required
" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
    Plugin 'VundleVim/Vundle.vim'
    Plugin 'scrooloose/nerdtree'
    Plugin 'ctrlpvim/ctrlp.vim'
    Plugin 'Raimondi/delimitMate'
    Plugin 'Yggdroot/indentLine'
    Plugin 'vim-airline/vim-airline'
    Plugin 'bling/vim-bufferline'
    Plugin 'Valloric/YouCompleteMe'
    Plugin 'mileszs/ack.vim'
    Plugin 'christoomey/vim-tmux-navigator'
    call vundle#end()            " required
    filetype plugin indent on    " required

set clipboard=unnamed
set backspace=indent,eol,start
set rnu
set nu
syntax on
set tabstop=4
set shiftwidth=4
set softtabstop=4
set expandtab
set wildmenu
set wildmode=list:longest,full

set cursorline
highlight  CursorLine ctermbg=None ctermfg=None
autocmd InsertEnter * highlight  CursorLine ctermbg=DarkBlue ctermfg=LightGreen
autocmd InsertLeave * highlight  CursorLine ctermbg=None ctermfg=None

set t_Co=256
set hlsearch
set incsearch
set autoindent
set ic
set foldmethod=indent
set foldlevel=1

" autocmd VimEnter * NERDTree
nnoremap <C-n> :NERDTreeToggle<CR>
nnoremap cdc :cd %:p:h<CR>:pwd<CR>
noremap gs :vimgrep /<C-r><C-w>/gj ./**<CR>
set laststatus=2
" enable tabline
 let g:airline#extensions#tabline#enabled = 1
" " set left separator
 let g:airline#extensions#tabline#left_sep = ' '
" " set left separator which are not editting
 let g:airline#extensions#tabline#left_alt_sep = '|'
" " show buffer number
 let g:airline#extensions#tabline#buffer_nr_show = 1
set hidden
nnoremap bn :bn<CR>
nnoremap bp :bp<CR>
nnoremap bd :bd<CR>
nnoremap bp :bp<CR>
nnoremap b1 :b1<CR>
nnoremap b2 :b2<CR>
nnoremap b3 :b3<CR>
nnoremap b4 :b4<CR>
nnoremap b5 :b5<CR>
nnoremap b6 :b6<CR>
nnoremap b7 :b7<CR>
nnoremap b8 :b8<CR>
nnoremap b9 :b9<CR>
nnoremap ls :ls<CR>

nnoremap <leader>b  :YcmCompleter GoTo<CR>
let g:ycm_global_ycm_extra_conf = '~/.vim/bundle/YouCompleteMe/third_party/ycmd/.ycm_extra_conf.py'

set switchbuf=useopen
set autoread

" If the current buffer has never been saved, it will have no name,
" call the file browser to save it, otherwise just save it.
command -nargs=0 -bar Update if &modified
                           \|    if empty(bufname('%'))
                           \|        browse confirm write
                           \|    else
                           \|        confirm write
                           \|    endif
                           \|endif
nnoremap <silent> <C-S> :<C-u>Update<CR>

set wildignore+=*/tmp/*,*.so,*.swp,*.zip
set wildignore+=*/site-packages/*,*.pyc,*.class,*.o
set wildignore+=*/target/*
let NERDTreeIgnore = ['\.o$','\.pyc$','\.class$']
