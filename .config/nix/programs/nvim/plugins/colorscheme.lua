require("auto-dark-mode").setup({
  update_interval = 1000,
  set_dark_mode = function()
    vim.api.nvim_set_option_value("background", "dark", { scope = "global" })
    vim.cmd.colorscheme("tokyonight-night")
    if package.loaded["lualine"] then
      require("lualine").setup({ options = { theme = "tokyonight-night" } })
    end
  end,
  set_light_mode = function()
    vim.api.nvim_set_option_value("background", "light", { scope = "global" })
    vim.cmd.colorscheme("tokyonight-day")
    if package.loaded["lualine"] then
      require("lualine").setup({ options = { theme = "tokyonight-day" } })
    end
  end,
})
