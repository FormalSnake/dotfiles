require("auto-dark-mode").setup({
  update_interval = 1000,
  set_dark_mode = function()
    vim.api.nvim_set_option_value("background", "dark", { scope = "global" })
    vim.cmd.colorscheme("github_dark_high_contrast")
    if package.loaded["lualine"] then
      require("lualine").setup({ options = { theme = "github_dark_high_contrast" } })
    end
  end,
  set_light_mode = function()
    vim.api.nvim_set_option_value("background", "light", { scope = "global" })
    vim.cmd.colorscheme("github_light_high_contrast")
    if package.loaded["lualine"] then
      require("lualine").setup({ options = { theme = "github_light_high_contrast" } })
    end
  end,
})

-- local base16 = require('base16-colorscheme')
-- local colors = require('colors.matugen')
--
-- -- Apply the colors
-- base16.setup(colors)
--
-- -- Set colorscheme (optional, depends on plugin)
-- vim.opt.termguicolors = true
-- -- vim.cmd("colorscheme base16-matugen")
