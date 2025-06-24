local map = vim.keymap.set

-- Plugin: christoomey/vim-tmux-navigator
vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  callback = function()
    vim.cmd([[
      command! TmuxNavigateLeft TmuxNavigateLeft
      command! TmuxNavigateDown TmuxNavigateDown
      command! TmuxNavigateUp TmuxNavigateUp
      command! TmuxNavigateRight TmuxNavigateRight
      command! TmuxNavigatePrevious TmuxNavigatePrevious
    ]])
  end,
})

-- Key mappings for Tmux navigation
map("n", "<c-h>", "<cmd><C-U>TmuxNavigateLeft<cr>", { desc = "Navigate Left (Tmux)" })
map("n", "<c-j>", "<cmd><C-U>TmuxNavigateDown<cr>", { desc = "Navigate Down (Tmux)" })
map("n", "<c-k>", "<cmd><C-U>TmuxNavigateUp<cr>", { desc = "Navigate Up (Tmux)" })
map("n", "<c-l>", "<cmd><C-U>TmuxNavigateRight<cr>", { desc = "Navigate Right (Tmux)" })
map("n", "<c-\\>", "<cmd><C-U>TmuxNavigatePrevious<cr>", { desc = "Navigate Previous (Tmux)" })
