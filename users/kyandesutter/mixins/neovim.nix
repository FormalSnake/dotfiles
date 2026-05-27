{ config, inputs, pkgs, ... }:
{
  imports = [ inputs.lazyvim.homeManagerModules.default ];

  programs.lazyvim = {
    enable = true;

    # LSPs that lazyvim-nix doesn't map to nixpkgs (lang.tailwind, lang.astro,
    # and HTML/CSS/JSON/Emmet) need to be provided here so they land on nvim's PATH.
    extraPackages = with pkgs; [
      tailwindcss-language-server
      astro-language-server
      vscode-langservers-extracted   # html, cssls, jsonls, eslint
      emmet-language-server          # JSX/HTML emmet completions
    ];

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
        # tailwindcss-language-server has no nixpkgs mapping in lazyvim-nix;
        # provided manually via extraPackages above.
        installDependencies = false;
        installRuntimeDependencies = true;
      };
      lang.typescript = {
        enable = true;
        installDependencies = true;
        installRuntimeDependencies = true;
      };
      # vtsls is the real TS LSP — lives under a nested extra, so the bare
      # lang.typescript options never installed it.
      lang.typescript.vtsls = {
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

      persistence = ''
        return {
          "folke/persistence.nvim",
          lazy = false,
          priority = 1000,
          init = function()
            local group = vim.api.nvim_create_augroup("persistence_autoload", { clear = true })

            vim.api.nvim_create_autocmd("StdinReadPre", {
              group = group,
              callback = function()
                vim.g.started_with_stdin = true
              end,
            })

            vim.api.nvim_create_autocmd("VimEnter", {
              group = group,
              nested = true,
              callback = function()
                if vim.fn.argc(-1) == 0 and not vim.g.started_with_stdin then
                  require("persistence").load()
                end
              end,
            })
          end,
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
