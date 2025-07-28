local utils = require("core.utils")

-- Auto-resize splits when Vim is resized
utils.create_augroup("ResizeSplits", { clear = true })
vim.api.nvim_create_autocmd("VimResized", {
  group = "ResizeSplits",
  pattern = "*",
  command = "tabdo wincmd =",
  desc = "Resize splits when terminal is resized",
})

-- Highlight on yank
utils.create_augroup("HighlightYank", { clear = true })
vim.api.nvim_create_autocmd("TextYankPost", {
  group = "HighlightYank",
  pattern = "*",
  callback = function()
    vim.highlight.on_yank({ higroup = "IncSearch", timeout = 300 })
  end,
  desc = "Highlight when yanking text",
})

-- Remove whitespace on save
utils.create_augroup("TrimWhitespace", { clear = true })
vim.api.nvim_create_autocmd("BufWritePre", {
  group = "TrimWhitespace",
  pattern = "*",
  callback = function()
    local save_cursor = vim.fn.getpos(".")
    pcall(function() vim.cmd([[%s/\s\+$//e]]) end)
    vim.fn.setpos(".", save_cursor)
  end,
  desc = "Remove trailing whitespace on save",
})

-- Auto create directories when saving files
utils.create_augroup("AutoCreateDir", { clear = true })
vim.api.nvim_create_autocmd("BufWritePre", {
  group = "AutoCreateDir",
  pattern = "*",
  callback = function(event)
    if event.match:match("^%w%w+://") then
      return
    end
    local file = vim.loop.fs_realpath(event.match) or event.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
  end,
  desc = "Auto create directory when saving a file",
})

-- Close certain windows with 'q'
utils.create_augroup("CloseWithQ", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
  group = "CloseWithQ",
  pattern = {
    "PlenaryTestPopup",
    "help",
    "lspinfo",
    "man",
    "notify",
    "qf",
    "spectre_panel",
    "startuptime",
    "tsplayground",
    "neotest-output",
    "checkhealth",
    "neotest-summary",
    "neotest-output-panel",
    "aerial",
  },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = event.buf, silent = true })
  end,
  desc = "Close certain windows with 'q'",
})

-- Set wrap and spell for text filetypes
utils.create_augroup("TextFiletypes", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
  group = "TextFiletypes",
  pattern = { "gitcommit", "markdown", "text" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
  end,
  desc = "Enable wrap and spell for text filetypes",
})

-- Fix conceallevel for json files
utils.create_augroup("JsonConceal", { clear = true })
vim.api.nvim_create_autocmd({ "BufWinEnter", "BufRead" }, {
  group = "JsonConceal",
  pattern = "*.json",
  callback = function()
    vim.opt_local.conceallevel = 0
  end,
  desc = "Disable concealing for JSON files",
})

-- Don't auto comment new line
utils.create_augroup("NoAutoComment", { clear = true })
vim.api.nvim_create_autocmd("BufEnter", {
  group = "NoAutoComment",
  pattern = "*",
  callback = function()
    vim.opt.formatoptions = vim.opt.formatoptions - { "c", "r", "o" }
  end,
  desc = "Disable automatic comment insertion",
})

-- Show cursor line only in active window
utils.create_augroup("CursorLineOnlyInActiveWindow", { clear = true })
vim.api.nvim_create_autocmd({ "VimEnter", "WinEnter", "BufWinEnter" }, {
  group = "CursorLineOnlyInActiveWindow",
  pattern = "*",
  callback = function()
    vim.opt_local.cursorline = true
  end,
  desc = "Show cursor line in active window",
})

vim.api.nvim_create_autocmd("WinLeave", {
  group = "CursorLineOnlyInActiveWindow",
  pattern = "*",
  callback = function()
    vim.opt_local.cursorline = false
  end,
  desc = "Hide cursor line in inactive windows",
})

-- Check if we need to reload the file when it changed
utils.create_augroup("CheckTime", { clear = true })
vim.api.nvim_create_autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
  group = "CheckTime",
  pattern = "*",
  command = "checktime",
  desc = "Check if file needs to be reloaded",
})

-- Go to last loc when opening a buffer
utils.create_augroup("LastLoc", { clear = true })
vim.api.nvim_create_autocmd("BufReadPost", {
  group = "LastLoc",
  pattern = "*",
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
  desc = "Go to last cursor location when opening buffer",
})

-- Auto toggle hlsearch
utils.create_augroup("AutoHlsearch", { clear = true })
vim.api.nvim_create_autocmd("CmdlineEnter", {
  group = "AutoHlsearch",
  pattern = "/,\\?",
  callback = function()
    vim.opt.hlsearch = true
  end,
  desc = "Enable hlsearch when entering search",
})

vim.api.nvim_create_autocmd("CmdlineLeave", {
  group = "AutoHlsearch",
  pattern = "/,\\?",
  callback = function()
    vim.opt.hlsearch = false
  end,
  desc = "Disable hlsearch when leaving search",
})