local function get_current_theme()
  local theme_file = vim.fn.expand("~/.config/nix-themes/current")
  if vim.fn.filereadable(theme_file) == 1 then
    local lines = vim.fn.readfile(theme_file)
    if lines and #lines > 0 and lines[1] then
      local theme = vim.fn.trim(lines[1])
      return theme
    end
  end
  return "catppuccin"
end

local function apply_theme()
  local current_theme = get_current_theme()
  
  local success, err = pcall(function()
    if current_theme == "catppuccin" then
      vim.cmd.colorscheme("catppuccin-mocha")
    elseif current_theme == "everforest" then
      vim.cmd.colorscheme("everforest")
    elseif current_theme == "nord" then
      vim.cmd.colorscheme("nord")
    else
      vim.cmd.colorscheme("catppuccin-mocha")
    end
  end)
  
  if not success then
    vim.notify("Error applying theme: " .. (err or "unknown error"), vim.log.levels.ERROR)
  end
end

-- Apply theme after plugins are loaded
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    apply_theme()
  end,
})

-- Create user command to reload theme manually
vim.api.nvim_create_user_command("ReloadTheme", function()
  apply_theme()
  vim.notify("Theme reloaded!", vim.log.levels.INFO)
end, {})

-- Watch for theme changes and reload
vim.api.nvim_create_autocmd("Signal", {
  pattern = "SIGUSR1", 
  callback = function()
    apply_theme()
    vim.notify("Theme reloaded via signal!", vim.log.levels.INFO)
  end,
})