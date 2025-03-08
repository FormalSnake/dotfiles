return {
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {},
  },
  {
    "f-person/auto-dark-mode.nvim",
    opts = {
      update_interval = 1000,
      set_dark_mode = function()
        vim.api.nvim_set_option_value('background', 'dark', { scope = 'global' })

        vim.cmd.colorscheme 'tokyonight-night'

        -- only change theme on lualine if it's loaded
        if package.loaded['lualine'] then
          ---@diagnostic disable-next-line: redundant-parameter
          require('lualine').setup { options = { theme = 'tokyonight-night' } }
        end
      end,
      set_light_mode = function()
        vim.api.nvim_set_option_value('background', 'light', { scope = 'global' })

        vim.cmd.colorscheme 'tokyonight-day'

        -- only change theme on lualine if it's loaded
        if package.loaded['lualine'] then
          ---@diagnostic disable-next-line: redundant-parameter
          require('lualine').setup { options = { theme = 'tokyonight-day' } }
        end
      end,
    }
  }
}
