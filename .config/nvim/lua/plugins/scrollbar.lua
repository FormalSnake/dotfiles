return {
  {
    "petertriho/nvim-scrollbar",
    config = function()
      local scrollbar = require("scrollbar")
      scrollbar.setup({
        show = true,
        handle = {
          color = "#2e303e",
        },
        marks = {},
        handlers = {
          cursor = false,
        },
        excluded_filetypes = {
          "prompt",
          "TelescopePrompt",
          "noice",
          "NvimTree",
          "alpha",
        },
      })

      local group = vim.api.nvim_create_augroup("_scrollbar", { clear = true })
    end,
  },
}
