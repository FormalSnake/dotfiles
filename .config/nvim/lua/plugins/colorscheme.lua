return {
  {
    "Shatur/neovim-ayu",
    lazy = false,
    priority = 1000,
    config = function()
      require('ayu').setup({
    mirage = false, -- Set to `true` to use `mirage` variant instead of `dark` for dark background.
    terminal = true, -- Set to `false` to let terminal manage its own colors.
    overrides = {}, -- A dictionary of group names, each associated with a dictionary of parameters (`bg`, `fg`, `sp` and `style`) and colors in hex.
})
      vim.cmd([[colorscheme ayu]])
    end,
  }
--   {
--     "ayu-theme/ayu-vim",
--     lazy = false, -- load this during startup as your main colorscheme
--     priority = 1000, -- load this before other plugins
--     config = function()
--         vim.opt.termguicolors = true -- enable true colors support
--         vim.g.ayucolor = "dark" -- set theme variant ("light", "mirage", "dark")
--         vim.cmd([[colorscheme ayu]]) -- apply the colorscheme
--     end,
-- }
}
