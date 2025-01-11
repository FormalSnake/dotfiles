-- set t_Co=256
--
-- set termguicolors
--  set t_Co=256

-- vim.env.NVIM_LISTEN_ADDRESS = '/tmp/nvimsocket'

vim.cmd [[
" set clipboard+=unnamedplus
" set clipboard& clipboard^=unnamed,unnamedplus

let &t_8f="\<Esc>[38;2;%lu;%lu;%lum"
let &t_8b="\<Esc>[48;2;%lu;%lu;%lum"

let g:clipboard = {
    \   'name': 'macos+tmux',
    \   'copy': {
    \      '+': ['/Users/kyandesutter/yank.sh'],
    \      '*': ['pbcopy'],
    \    },
  \      'paste': {
            \      '+': ['tmux', 'save-buffer', '-'],
            \      '*': ['pbpaste'],
            \       },
    \   'cache_enabled': 1,
    \ }
set termguicolors

set conceallevel=1

set guioptions+=c

set nocompatible
set number
set relativenumber
syntax on
set synmaxcol=128
syntax sync minlines=256

set fileencodings=utf-8,latin
set encoding=UTF-8
set title
set autoindent
set nobackup
set nowritebackup
set hlsearch
set showcmd
set cmdheight=0
set laststatus=3
set scrolloff=10
" set shell=/bin/bash
set backupskip=/tmp/*
" set verbose=20

set undofile

set mouse=a
set ttyfast

set timeoutlen=500
set updatetime=300

set inccommand=split
set incsearch

set t_BE=

set nosc noru nosm
set ignorecase
set smarttab
set smartindent

filetype plugin indent on

set shiftwidth=2
set tabstop=2
set expandtab

set ea
set ai
set si
set autoread
" set nowrap
set wrap linebreak
set backspace=start,eol,indent
set path+=**
set wildignore+=*/node_modules/**
set wildignore+=*/Pods/**
set wildignore+=*/build/**
set wildignore+=*/dist/**

set formatoptions+=cro
set formatoptions-=r
set formatoptions-=o

set foldmethod=manual

set cursorline

set splitbelow
set splitright

set signcolumn=yes
set pumheight=10

set hidden


" let g:oscyank_term = 'tmux'

  ]]
