{ config, inputs, ... }:
{
  imports = [ inputs.lazyvim.homeManagerModules.default ];

  programs.lazyvim = {
    enable = true;

    extras = {
      ai.supermaven.enable = true;
      editor.neo-tree.enable = true;
      util.mini-hipatterns.enable = true;

      lang.astro = {
        enable = true;
        installDependencies = true;
        installRuntimeDependencies = true;
      };
      lang.tailwind = {
        enable = true;
        # tailwindcss has no nixpkgs mapping in lazyvim-nix; project's own
        # node_modules / package manager provides the LSP and CLI.
        installDependencies = false;
        installRuntimeDependencies = true;
      };
      lang.typescript = {
        enable = true;
        installDependencies = true;
        installRuntimeDependencies = true;
      };
    };

    plugins = {
      colorscheme = ''
        return {
          {
            "catppuccin/nvim",
            name = "catppuccin",
            lazy = false,
            priority = 1000,
            opts = {
              flavour = "${config.catppuccin.flavor}",
              transparent_background = true,
            },
          },
          {
            "LazyVim/LazyVim",
            opts = { colorscheme = "catppuccin" },
          },
        }
      '';

      tmux-navigator = ''
        return {
          "christoomey/vim-tmux-navigator",
          cmd = {
            "TmuxNavigateLeft",
            "TmuxNavigateDown",
            "TmuxNavigateUp",
            "TmuxNavigateRight",
            "TmuxNavigatePrevious",
            "TmuxNavigatorProcessList",
          },
          keys = {
            { "<c-h>", "<cmd><C-U>TmuxNavigateLeft<cr>" },
            { "<c-j>", "<cmd><C-U>TmuxNavigateDown<cr>" },
            { "<c-k>", "<cmd><C-U>TmuxNavigateUp<cr>" },
            { "<c-l>", "<cmd><C-U>TmuxNavigateRight<cr>" },
            { [[<c-\>]], "<cmd><C-U>TmuxNavigatePrevious<cr>" },
          },
        }
      '';
    };

    # Backstop transparency for UI elements catppuccin's transparent_background
    # doesn't cover (floats, telescope, notify, etc.).
    config.autocmds = ''
      local groups = {
        "Normal", "NormalNC", "NormalFloat", "FloatBorder",
        "Pmenu", "PmenuSel", "EndOfBuffer", "FoldColumn", "Folded",
        "SignColumn", "WhichKeyFloat", "WhichKeyNormal", "WhichKeyBorder",
        "TelescopeNormal", "TelescopeBorder", "TelescopePromptBorder",
        "TelescopePromptNormal", "TelescopePromptTitle",
        "TelescopePreviewNormal", "TelescopePreviewBorder",
        "TelescopeResultsNormal", "TelescopeResultsBorder",
        "NeoTreeNormal", "NeoTreeNormalNC", "NeoTreeVertSplit",
        "NeoTreeWinSeparator", "NeoTreeEndOfBuffer",
        "NotifyINFOBody", "NotifyERRORBody", "NotifyWARNBody",
        "NotifyTRACEBody", "NotifyDEBUGBody",
        "NotifyINFOBorder", "NotifyERRORBorder", "NotifyWARNBorder",
        "NotifyTRACEBorder", "NotifyDEBUGBorder",
      }
      local function apply_transparency()
        for _, group in ipairs(groups) do
          vim.api.nvim_set_hl(0, group, { bg = "none" })
        end
      end
      vim.api.nvim_create_autocmd("ColorScheme", {
        pattern = "*",
        callback = apply_transparency,
      })
      apply_transparency()
    '';
  };
}
