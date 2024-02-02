vim.g.mapleader = " "

function map(mode, lhs, rhs, opts)
  local options = { noremap = true, silent = true, nowait = true }
  if opts then
    options = vim.tbl_extend("force", options, opts)
  end
  vim.api.nvim_set_keymap(mode, lhs, rhs, options)
end

-- map('n', '<leader>ff', ':Telescope find_files<CR>')
-- map('n', '<leader>fg', ':Telescope live_grep<CR>')
-- map('n', '<leader>fb', ':Telescope buffers<CR>')
-- map('n', '<leader>fh', ':Telescope help_tags<CR>')
-- map('n', '<leader>fx', ':Telescope treesitter<CR>')
map('n', '<leader>lt', ':TroubleToggle<CR>')
map('n', '<leader>gdf', ':DiffviewOpen<CR>')
map('n', '<leader>lo', ':TSToolsOrganizeImports<CR>')
map('n', '<leader>rf', ':TSToolsRenameFile<CR>')
map('n', '+', '<C-a>')
map('n', '-', '<C-x>')


-- vim.keymap.set('n', '<leader>v', function() require("nvterm.terminal").toggle "horizontal" end)
vim.keymap.set('n', '<leader>dl', function()
  require("nvim-lightbulb").debug()
end)

-- Define a function to set your window options
vim.wo.number = true
vim.wo.relativenumber = true
