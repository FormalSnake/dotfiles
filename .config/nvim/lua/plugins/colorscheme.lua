return {
  -- {
  --   "wtfox/jellybeans.nvim",
  --   priority = 1000,
  --   config = function()
  --     require("jellybeans").setup({
  --       transparent = true,
  --     })
  --     vim.cmd.colorscheme("jellybeans")
  --   end,
  -- },
  { 'kepano/flexoki-neovim', name = 'flexoki' },
  -- Lua
  {
    "f-person/auto-dark-mode.nvim",
    opts = {
      set_dark_mode = function()
        vim.cmd.colorscheme("flexoki-light")
      end,
      set_light_mode = function()
        vim.cmd.colorscheme("flexoki-dark")
      end,
      -- your configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
    }
  }
}
