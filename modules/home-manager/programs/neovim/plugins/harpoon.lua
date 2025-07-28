local harpoon = require("harpoon")

harpoon:setup({
  settings = {
    save_on_toggle = true,
    sync_on_ui_close = true,
    key = function()
      return vim.loop.cwd()
    end,
  }
})

-- Keymaps
local wk = require("which-key")
wk.add({
  { "<leader>h", group = "harpoon" },
  { "<leader>ha", function() harpoon:list():add() end, desc = "Add file to harpoon" },
  { "<leader>hh", function() harpoon.ui:toggle_quick_menu(harpoon:list()) end, desc = "Toggle harpoon menu" },
  { "<leader>h1", function() harpoon:list():select(1) end, desc = "Go to harpoon file 1" },
  { "<leader>h2", function() harpoon:list():select(2) end, desc = "Go to harpoon file 2" },
  { "<leader>h3", function() harpoon:list():select(3) end, desc = "Go to harpoon file 3" },
  { "<leader>h4", function() harpoon:list():select(4) end, desc = "Go to harpoon file 4" },
  { "<leader>hp", function() harpoon:list():prev() end, desc = "Previous harpoon file" },
  { "<leader>hn", function() harpoon:list():next() end, desc = "Next harpoon file" },
})

-- Quick navigation with Ctrl+number
vim.keymap.set("n", "<C-1>", function() harpoon:list():select(1) end)
vim.keymap.set("n", "<C-2>", function() harpoon:list():select(2) end)
vim.keymap.set("n", "<C-3>", function() harpoon:list():select(3) end)
vim.keymap.set("n", "<C-4>", function() harpoon:list():select(4) end)