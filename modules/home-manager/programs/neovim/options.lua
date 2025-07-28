-- Leader keys
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- UI settings
vim.opt.termguicolors = true
vim.opt.backspace = '2'
vim.opt.showcmd = true
vim.opt.laststatus = 2
vim.opt.autowrite = true
vim.opt.cursorline = true
vim.opt.autoread = true

-- Line numbers
vim.opt.relativenumber = true
vim.opt.number = true

-- Tabs and indentation
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.shiftround = true
vim.opt.expandtab = true

-- Clipboard - separate vim and system clipboards
-- vim.opt.clipboard = "unnamedplus"  -- Commented out to separate clipboards

-- Enhanced editor settings
vim.opt.updatetime = 250
vim.opt.timeoutlen = 300
vim.opt.conceallevel = 2
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "nvim_treesitter#foldexpr()"
vim.opt.foldenable = false
vim.opt.signcolumn = "yes"
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8
vim.opt.wrap = false
vim.opt.linebreak = true
vim.opt.breakindent = true
vim.opt.showbreak = "↪ "
vim.opt.list = true
vim.opt.listchars = { tab = "→ ", trail = "·", nbsp = "␣" }
vim.opt.fillchars = { fold = " " }

-- Better search
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.inccommand = "split"

-- Better splits
vim.opt.splitright = true
vim.opt.splitbelow = true

-- Undo and backup
vim.opt.undofile = true
vim.opt.undolevels = 10000
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.swapfile = false

-- Performance
vim.opt.lazyredraw = false
vim.opt.synmaxcol = 300

-- LSP diagnostics (moved from above)

