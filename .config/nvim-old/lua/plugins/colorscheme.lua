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
      update_interval = 1000,
      set_dark_mode = function()
        vim.api.nvim_set_option_value('background', 'dark', { scope = 'global' })

        vim.cmd.colorscheme 'flexoki-dark'

        -- only change theme on lualine if it's loaded
        if package.loaded['lualine'] then
          ---@diagnostic disable-next-line: redundant-parameter
          require('lualine').setup { options = { theme = 'flexoki-dark' } }
        end
      end,
      set_light_mode = function()
        vim.api.nvim_set_option_value('background', 'light', { scope = 'global' })

        vim.cmd.colorscheme 'flexoki-light'

        -- only change theme on lualine if it's loaded
        if package.loaded['lualine'] then
          ---@diagnostic disable-next-line: redundant-parameter
          require('lualine').setup { options = { theme = 'flexoki-light' } }
        end
      end,
    }
  }
}
