return {
  {
    "rasulomaroff/reactive.nvim",
    opts = function()
      local react = require("reactive")
      react.setup({
        builtin = {
          cursorline = true,
          cursor = true,
          modemsg = true,
        },
      })
    end,
  },
}
