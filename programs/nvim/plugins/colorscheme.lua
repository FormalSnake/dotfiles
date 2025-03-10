require("auto-dark-mode").setup({
  update_interval = 1000,
  set_dark_mode = function()
    vim.api.nvim_set_option_value("background", "dark", { scope = "global" })
    vim.cmd.colorscheme("catppuccin-mocha")
    if package.loaded["lualine"] then
      require("lualine").setup({ options = { theme = "catppuccin-mocha" } })
    end
  end,
  set_light_mode = function()
    vim.api.nvim_set_option_value("background", "light", { scope = "global" })
    vim.cmd.colorscheme("catppuccin-latte")
    if package.loaded["lualine"] then
      require("lualine").setup({ options = { theme = "catppuccin-latte" } })
    end
  end,
})
