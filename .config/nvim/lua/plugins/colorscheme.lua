return {
  -- {
  --   'uZer/pywal16.nvim',
  --   -- for local dev replace with:
  --   -- dir = '~/your/path/pywal16.nvim',
  --   config = function()
  --     vim.cmd.colorscheme("pywal16")
  --   end,
  -- }
  {
    "mellow-theme/mellow.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      vim.g.mellow_transparent = true
      vim.cmd([[colorscheme mellow]])
    end,
  }
}
