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

local Snacks = require("snacks")

-- Key mappings
vim.keymap.set("n", "<leader>.", function() Snacks.scratch() end, { desc = "Toggle Scratch Buffer" })
vim.keymap.set("n", "<leader>S", function() Snacks.scratch.select() end, { desc = "Select Scratch Buffer" })
vim.keymap.set("n", "<leader>n", function() Snacks.notifier.show_history() end, { desc = "Notification History" })
vim.keymap.set("n", "<leader>bd", function() Snacks.bufdelete() end, { desc = "Delete Buffer" })
vim.keymap.set("n", "<leader>cR", function() Snacks.rename.rename_file() end, { desc = "Rename File" })
vim.keymap.set("n", "<leader>gB", function() Snacks.gitbrowse() end, { desc = "Git Browse" })
vim.keymap.set("n", "<leader>gb", function() Snacks.git.blame_line() end, { desc = "Git Blame Line" })
vim.keymap.set("n", "<leader>gf", function() Snacks.lazygit.log_file() end, { desc = "Lazygit Current File History" })
vim.keymap.set("n", "<leader>gg", function() Snacks.lazygit() end, { desc = "Lazygit" })
vim.keymap.set("n", "<leader>gl", function() Snacks.lazygit.log() end, { desc = "Lazygit Log (cwd)" })
vim.keymap.set("n", "<leader>un", function() Snacks.notifier.hide() end, { desc = "Dismiss All Notifications" })
vim.keymap.set("n", "<leader>t", function() Snacks.terminal() end, { desc = "Toggle Terminal" })
vim.keymap.set("n", "<c-_>", function() Snacks.terminal() end, { desc = "which_key_ignore" })
vim.keymap.set({ "n", "t" }, "]]", function() Snacks.words.jump(vim.v.count1) end, { desc = "Next Reference" })
vim.keymap.set({ "n", "t" }, "[[", function() Snacks.words.jump(-vim.v.count1) end, { desc = "Prev Reference" })
vim.keymap.set("n", "<leader>ff", function() Snacks.picker.files() end, { desc = "Telescope find files" })
vim.keymap.set("n", "<leader>fw", function() Snacks.picker.grep() end, { desc = "Telescope live_grep word" })
vim.keymap.set("n", "<leader>/", function() Snacks.picker.lines() end, { desc = "Grep" })
vim.keymap.set("n", "<leader>z", function() Snacks.zen() end, { desc = "Zen Mode" })
vim.keymap.set("n", "<leader>e", function() Snacks.explorer.open() end, { desc = "Toggle Explorer" })
vim.keymap.set("n", "<leader>dim", function() Snacks.dim() end, { desc = "Toggle Dim" })
vim.keymap.set("n", "<leader>N", function()
  Snacks.win({
    file = vim.api.nvim_get_runtime_file("doc/news.txt", false)[1],
    width = 0.6,
    height = 0.6,
    wo = {
      spell = false,
      wrap = false,
      signcolumn = "yes",
      statuscolumn = " ",
      conceallevel = 3,
    },
  })
end, { desc = "Neovim News" })
