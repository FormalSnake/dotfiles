{ inputs, pkgs, ... }:
let
  # kepano/flexoki-neovim (the only actively-maintained Flexoki colorscheme, by
  # Flexoki's author). Not in nixpkgs and unknown to lazyvim-nix's plugin data,
  # so package it here and hand lazy.nvim a `dir =` store path — fully pinned, no
  # runtime git clone. `variant = "auto"` tracks vim.o.background.
  flexokiNvim = pkgs.vimUtils.buildVimPlugin {
    pname = "flexoki-neovim";
    version = "0-unstable-2025-08-26";
    src = pkgs.fetchFromGitHub {
      owner = "kepano";
      repo = "flexoki-neovim";
      rev = "c3e2251e813d29d885a7cbbe9808a7af234d845d";
      hash = "sha256-TlBP99MBAT/H0Uut1MF8SnIDoeetcdHLKrWal2oO2Ug=";
    };
  };
in
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
            dir = "${flexokiNvim}",
            name = "flexoki",
            lazy = false,
            priority = 1000,
            config = function()
              -- variant = "auto" follows vim.o.background (auto-dark-mode toggles
              -- it below). Defaults to dark; reach light with `:set background=light`.
              -- Transparency isn't a plugin option here; the ColorScheme autocmd
              -- backstop at the bottom of this file paints the backgrounds none.
              require("flexoki").setup({ variant = "auto" })
            end,
          },
          {
            "LazyVim/LazyVim",
            opts = { colorscheme = "flexoki" },
          },
        }
      '';

      # Wallpaper-derived colours (Linux/Noctalia). Noctalia renders the live M3
      # palette into ~/.config/nvim/lua/noctalia_base16.lua as a base00..base0F
      # table (see the `neovim` user template in mixins/noctalia.nix);
      # dynamic-base16.nvim maps it onto all Treesitter/LSP highlight groups and,
      # with watch = true, hot-reloads when Noctalia rewrites the file (on every
      # wallpaper change / light-dark flip). flexoki (above) stays the base
      # colourscheme and the fallback: the setup is pcall-guarded so a missing file
      # (cold start before the first palette, or the macOS host where Noctalia
      # doesn't run) never breaks startup — nvim simply stays on flexoki until
      # the file exists (restart nvim once after the first palette is generated).
      dynamic-base16 = ''
        return {
          "GnRlLeclerc/dynamic-base16.nvim",
          lazy = false,
          priority = 999,
          config = function()
            pcall(function()
              require("dynamic-base16").setup({
                module = "noctalia_base16",
                transparent = true,
                watch = true,
              })
            end)
          end,
        }
      '';

      # Follow the macOS appearance at runtime. Toggling vim.o.background makes
      # flexoki (variant = "auto") swap light <-> dark. We also re-run
      # :colorscheme so the ColorScheme autocmd fires and the transparency
      # backstop below re-applies on every flip.
      auto-dark-mode = ''
        return {
          "f-person/auto-dark-mode.nvim",
          lazy = false,
          priority = 999,
          dependencies = { "flexoki" },
          opts = {
            update_interval = 1000,
            set_dark_mode = function()
              vim.o.background = "dark"
              vim.cmd.colorscheme("flexoki")
            end,
            set_light_mode = function()
              vim.o.background = "light"
              vim.cmd.colorscheme("flexoki")
            end,
          },
        }
      '';

      # LazyVim's lang.astro extra injects @astrojs/ts-plugin into vtsls via a
      # hard-coded Mason path. With Mason disabled (Nix setup), that path is
      # stale leftover data and the resulting plugin load has been observed to
      # SIGTERM the tsserver child, killing TS completions while leaving the
      # vtsls client "attached". Strip the entry so tsserver stays healthy.
      vtsls = ''
        return {
          "neovim/nvim-lspconfig",
          opts = function(_, opts)
            local vtsls = opts.servers and opts.servers.vtsls
            if vtsls and vtsls.settings and vtsls.settings.vtsls and vtsls.settings.vtsls.tsserver then
              vtsls.settings.vtsls.tsserver.globalPlugins = nil
            end
          end,
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

            -- During session :source the foreground :edit fires BufReadPre,
            -- which lazy.nvim hijacks to load nvim-lspconfig / nvim-treesitter.
            -- Empirically the natural :edit continuation (BufRead → filetype
            -- detect → FileType) does not complete for that buffer — &filetype
            -- ends up empty, so vim.lsp.enable's FileType autocmd and the TS
            -- highlighter never match anything. Re-run filetype detection on
            -- every restored buffer; setting &filetype fires FileType, which
            -- in turn starts LSP (via vim.lsp.enable's autocmd) and TS.
            vim.api.nvim_create_autocmd("User", {
              pattern = "VeryLazy",
              group = group,
              nested = true,
              once = true,
              callback = function()
                if vim.fn.argc(-1) ~= 0 then return end
                if vim.g.started_with_stdin then return end
                require("persistence").load()
                vim.schedule(function()
                  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == "" then
                      vim.api.nvim_buf_call(buf, function()
                        vim.cmd("filetype detect")
                      end)
                    end
                  end
                end)
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

    # Backstop transparency for all UI backgrounds (flexoki has no transparent
    # option): floats, telescope, notify, neo-tree, etc.
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
