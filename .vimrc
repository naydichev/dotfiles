" Julian Naydichev <rublind@gmail.com>
" .vimrc

set nocompatible                " necessary to ensure that vim runs as vim

" enable pathogen plugin:
silent! call pathogen#infect()

syntax enable                   " enable syntax highlighting
filetype plugin indent on       " filetype detection: go

set showcmd                     " display incomplete commands
set showmode                    " show the current mode
set showmatch                   " show matching brackets

set backspace=indent,eol,start  " intiuitive backspace

set hidden                      " allow multiple buffers in a better fashion

set wildmenu                    " command line completion
set wildmode=list:longest       " make it like a shell

set ignorecase                  " case insensitive searching
set smartcase                   " but smartly

set number                      " line numbers
set numberwidth=5               " good 'til 99999
set ruler                       " cursor position

set incsearch                   " match as you type (searching)
set hlsearch                    " highlight searches

set wrap                        " enable line wrapping
set scrolloff=3                 " show 3 lines around the cursor

set title                       " set the terminal's title

set visualbell                  " no more beeping please

set dir=$HOME/.vim/tmp/,.      " keep swap files in one spot 

set tabstop=4                   " global tab width
set softtabstop=4               " tabs
set shiftwidth=4                " same thing
set expandtab                   " do I want spaces or tabs?
set autoindent

set laststatus=2                " show status line at all times!

set list                        " enable showing of tabs
set listchars=tab:>-,trail:-    " show tabs and spaces easily
colorscheme vividchalk

set completeopt=menu,longest    " improve autocomplete 

" FLAGS_SPECIALSAUCE
" thanks to nate for this:
set tags=./tags;                " search up our tree for tags

" enable persistent undo
if v:version >= 703

    " ensure undo directory exists
    if !isdirectory("~/.vimundo")
        call system("mkdir ~/.vimundo")
    endif

    set undodir=~/.vimundo
    set undofile
    set undolevels=1000
    set undoreload=10000
endif

" thank you kaitlyn for the following:
vnoremap C :s/^/#/<CR>:nohl<CR>
vnoremap c :s/^#//<CR>:nohl<CR>

map <leader>nt :NERDTree<CR>

" auto things
autocmd BufNewFile *.php 0r ~/.vim/skeleton/php
autocmd BufNewFile *.pl  0r ~/.vim/skeleton/perl
autocmd BufNewFile *.sh  0r ~/.vim/skeleton/sh

" FuzzyFinder - thanks Nate!
let g:fuf_modesDisable = [ 'mrucmd', ]
let g:fuf_coveragefile_exclude = '\v\~$|blib|\.(o|exe|dll|bak|orig|swp)$|(^|[/\\])\.(hg|git|bzr)($|[/\\])'
let g:fuf_mrufile_exclude = '\v\~$|\.(o|exe|dll|bak|orig|sw[po])$|^(\/\/|\\\\|\/mnt\/|\/media\/)|svn-base$'
let g:fuf_maxMenuWidth = 150

noremap <leader>ff :FufCoverageFile<CR>
noremap <leader>fr :FufMruFile<CR>
noremap <leader>ft :FufTag<CR>
noremap <leader>fb :FufBuffer<CR>

