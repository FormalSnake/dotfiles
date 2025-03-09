vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  callback = function()
    local wk = require("which-key")
    wk.add({
      { "<leader>f", group = "telescope" },
      { "<leader>g", group = "git" },
    })

    vim.keymap.set("n", "<leader>?", function()
      wk.show({ global = false })
    end, { desc = "Buffer Local Keymaps (which-key)" })
  end,
})
