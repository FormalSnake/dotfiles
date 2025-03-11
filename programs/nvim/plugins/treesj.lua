require('treesj').setup({})
local map = vim.keymap.set

-- Plugin: Wansmer/treesj
vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  callback = function()
    require("treesj").setup({
      use_default_keymaps = false,
      max_join_length = 150,
    })
  end,
})

-- Key mapping for Treesitter Join
map("n", "J", "<cmd>TSJToggle<cr>", { desc = "Join Toggle (Treesj)" })
