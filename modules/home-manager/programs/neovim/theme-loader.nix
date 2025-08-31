{pkgs, ...}:
pkgs.vimUtils.buildVimPlugin {
  name = "nix-theme-loader";
  src = pkgs.writeTextDir "plugin/theme-loader.lua" ''
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
        elseif current_theme == "osaka-jade" then
          vim.cmd.colorscheme("bamboo")
        elseif current_theme == "flexoki" then
          vim.cmd.colorscheme("flexoki-dark")
        else
          vim.cmd.colorscheme("catppuccin-mocha")
        end
      end)
      
      if not success then
        -- Try again after a delay if it fails (plugins might not be loaded yet)
        vim.defer_fn(function()
          local retry_success, retry_err = pcall(function()
            if current_theme == "catppuccin" then
              vim.cmd.colorscheme("catppuccin-mocha")
            elseif current_theme == "everforest" then
              vim.cmd.colorscheme("everforest")
            elseif current_theme == "nord" then
              vim.cmd.colorscheme("nord")
            elseif current_theme == "osaka-jade" then
              vim.cmd.colorscheme("bamboo")
            elseif current_theme == "flexoki" then
              vim.cmd.colorscheme("flexoki-dark")
            else
              vim.cmd.colorscheme("catppuccin-mocha")
            end
          end)
          if not retry_success then
            vim.notify("Error applying theme: " .. (retry_err or "unknown error"), vim.log.levels.ERROR)
          end
        end, 100)
      end
    end

    -- Apply theme immediately (will override any default colorscheme)
    apply_theme()

    -- Also apply on VimEnter to ensure it takes effect
    vim.api.nvim_create_autocmd("VimEnter", {
      callback = function()
        vim.defer_fn(apply_theme, 10)
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
  '';
}