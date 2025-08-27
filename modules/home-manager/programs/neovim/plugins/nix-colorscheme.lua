print("Theme Debug: Loading nix-colorscheme.lua")

local M = {}

local function get_current_theme()
  local theme_file = vim.fn.expand("~/.config/nix-themes/current")
  print("Theme Debug: Checking theme file: " .. theme_file)
  if vim.fn.filereadable(theme_file) == 1 then
    local lines = vim.fn.readfile(theme_file)
    if lines and #lines > 0 and lines[1] then
      local theme = vim.fn.trim(lines[1])
      print("Theme Debug: Read theme from file: " .. theme)
      return theme
    end
  end
  print("Theme Debug: Using fallback theme: catppuccin")
  return "catppuccin"
end

local function apply_theme()
  local current_theme = get_current_theme()
  print("Theme Debug: Applying theme: " .. current_theme)
  
  -- Wait a bit for plugins to be ready
  vim.schedule(function()
    local success, err = pcall(function()
      if current_theme == "catppuccin" then
        vim.cmd.colorscheme("catppuccin-mocha")
        print("Theme Debug: Applied catppuccin-mocha")
      elseif current_theme == "everforest" then
        vim.cmd.colorscheme("everforest")
        print("Theme Debug: Applied everforest")
      elseif current_theme == "nord" then
        vim.cmd.colorscheme("nord")
        print("Theme Debug: Applied nord")
      else
        vim.cmd.colorscheme("catppuccin-mocha")
        print("Theme Debug: Applied fallback catppuccin-mocha")
      end
    end)
    
    if not success then
      print("Theme Debug: Error applying theme: " .. (err or "unknown error"))
    end
  end)
end

-- Setup function
function M.setup()
  print("Theme Debug: Setting up nix colorscheme system")
  
  -- Apply theme on startup
  apply_theme()
  
  -- Create user command to reload theme manually
  vim.api.nvim_create_user_command("ReloadTheme", function()
    print("Theme Debug: Manual reload triggered")
    apply_theme()
    vim.notify("Theme reloaded!", vim.log.levels.INFO)
  end, {})
  
  -- Watch for theme changes and reload
  vim.api.nvim_create_autocmd("Signal", {
    pattern = "SIGUSR1", 
    callback = function()
      print("Theme Debug: Received SIGUSR1 signal")
      apply_theme()
      vim.notify("Theme reloaded via signal!", vim.log.levels.INFO)
    end,
  })
  
  print("Theme Debug: Setup complete")
end

-- Also expose the apply function
M.apply_theme = apply_theme

return M