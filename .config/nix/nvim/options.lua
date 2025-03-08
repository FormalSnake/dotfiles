vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.opt.termguicolors = true
-- Disable virtual_text since it's redundant due to lsp_lines.
vim.diagnostic.config({
  virtual_text = false,
})

vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

vim.opt.backspace = '2'
vim.opt.showcmd = true
vim.opt.laststatus = 2
vim.opt.autowrite = true
vim.opt.cursorline = true
vim.opt.autoread = true

-- use spaces for tabs and whatnot
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.shiftround = true
vim.opt.expandtab = true

vim.keymap.set('n', '<leader>h', ':nohlsearch<CR>')

vim.opt.relativenumber = true
vim.opt.number = true

-- Paste from Visual/Normal mode
vim.api.nvim_set_keymap('v', '<C-c>p', '"+gp', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<C-c>p', '"+p', { noremap = true, silent = true })

-- Paste from Insert mode to Normal
vim.api.nvim_set_keymap('i', '<C-c>p', '<Esc>"+pi', { noremap = true, silent = true })

-- Cut and Copy mappings in Visual/Normal mode
vim.api.nvim_set_keymap('v', '<C-c>d', '"+d', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<C-c>d', '"+dd', { noremap = true, silent = true })

-- Paste from Insert mode to Normal after cutting
vim.api.nvim_set_keymap('i', '<C-c>d', '<Esc>"+ddi', { noremap = true, silent = true })

-- Copy mappings in Visual/Normal mode
vim.api.nvim_set_keymap('v', '<C-c>y', '"+y', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<C-c>y', '"+yy', { noremap = true, silent = true })

-- Paste from Insert mode to Normal after copying
vim.api.nvim_set_keymap('i', '<C-c>y', '<Esc>"+yyi', { noremap = true, silent = true })

-- Command line paste mapping
vim.api.nvim_set_keymap('c', '<C-c>p', '<C-r>+', { noremap = true, silent = true })
