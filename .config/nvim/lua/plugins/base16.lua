return {
  {
    "tinted-theming/base16-vim",
    priority = 1000,
    enabled = true,
    config = function()
      local cmd = vim.cmd
      local g = vim.g
      local current_theme_name = os.getenv("BASE16_THEME")
      -- if current_theme_name == 'black-metal-bathory' then
      --   cmd('colorscheme vesper')
      --[[ else ]]
      if current_theme_name and g.colors_name ~= "base16-" .. current_theme_name then
        cmd("let base16colorspace=256")
        cmd("colorscheme base16-" .. current_theme_name)
      end
    end,
  },
}
