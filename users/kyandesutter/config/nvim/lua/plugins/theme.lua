-- Dynamic theme loading with fallback to tokyonight
local theme_path = vim.fn.expand("~/.config/formalconf/current/theme/neovim.lua")
local theme_config = nil

-- Try to load theme from formalconf
if vim.fn.filereadable(theme_path) == 1 then
  local ok, config = pcall(dofile, theme_path)
  if ok then
    theme_config = config
  end
end

-- Fallback to tokyonight if no theme found or loading failed
if not theme_config then
  theme_config = {
    { "folke/tokyonight.nvim", lazy = false, priority = 1000 },
    {
      "LazyVim/LazyVim",
      opts = {
        colorscheme = "tokyonight",
      },
    },
  }
end

return theme_config
