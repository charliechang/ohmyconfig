" #### Actions ####
" brew install ripgrep fzf neovim
" mkdir -p ~/.config/nvim
" ln -sf $(pwd)/nvim ~/.config/nvim
" echo "alias vim='nvim'" >> ~/.zshrc
" echo "export LC_ALL='C'" >> ~/.zshrc
" python3 -m pip install --user --upgrade pynvim
" python2 -m pip install --user --upgrade pynvim
" curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
"    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
" xcode-select --install # May need this line for new Mac OS before running
" nvim +PlugInstall


set nocompatible              " be iMproved, required

filetype plugin indent on
" filetype off                  " required
call plug#begin()
    Plug 'scrooloose/nerdtree'
    Plug 'Yggdroot/indentLine'
    Plug 'vim-airline/vim-airline'
    Plug 'bling/vim-bufferline'
    Plug 'christoomey/vim-tmux-navigator'
    Plug 'junegunn/fzf'
    Plug 'duane9/nvim-rg'
    Plug 'xiyaowong/transparent.nvim'
call plug#end()
filetype plugin indent on    " required

set clipboard=unnamed
set backspace=indent,eol,start
set rnu
set nu
syntax on
color peachpuff
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
nnoremap <C-p> :FZF<cr>
nnoremap <C-f> :Rg <C-r><C-w><cr>

" nnoremap cdc :cd %:p:h<CR>:pwd<CR>
" noremap gs :vimgrep /<C-r><C-w>/gj ./**<CR>
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
nnoremap b1 :b1<CR>
nnoremap b2 :b2<CR>
nnoremap b3 :b3<CR>
nnoremap b4 :b4<CR>
nnoremap b5 :b5<CR>
nnoremap b6 :b6<CR>
nnoremap b7 :b7<CR>
nnoremap b8 :b8<CR>
nnoremap b9 :b9<CR>

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
" cnoreabbrev Ack Ack!
cnoreabbrev Q! q!
cnoreabbrev Wq wq
cnoreabbrev WQ wq
set splitbelow
set splitright
