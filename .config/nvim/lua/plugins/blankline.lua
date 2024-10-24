return {
  {
    "lukas-reineke/indent-blankline.nvim",
    opts = {
      indent = { char = "│" },
      scope = { char = "│" },
    },
    config = function(_, opts)
      -- dofile(vim.g.base46_cache .. "blankline")

      local hooks = require "ibl.hooks"
      hooks.register(hooks.type.WHITESPACE, hooks.builtin.hide_first_space_indent_level)
      require("ibl").setup(opts)

      -- dofile(vim.g.base46_cache .. "blankline")
    end,
  },
}
