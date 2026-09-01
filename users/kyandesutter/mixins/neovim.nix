{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
let
  # kepano/flexoki-neovim (the only actively-maintained Flexoki colorscheme, by
  # Flexoki's author). Not in nixpkgs and unknown to lazyvim-nix's plugin data,
  # so package it here and hand lazy.nvim a `dir =` store path: fully pinned, no
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

  # GnRlLeclerc/dynamic-base16.nvim: same situation as flexoki-neovim above:
  # not in nixpkgs, unknown to lazyvim-nix ("Could not resolve plugin" at
  # build), so pin it and hand lazy.nvim a `dir =` store path.
  dynamicBase16Nvim = pkgs.vimUtils.buildVimPlugin {
    pname = "dynamic-base16-nvim";
    version = "0-unstable-2024-07-21";
    src = pkgs.fetchFromGitHub {
      owner = "GnRlLeclerc";
      repo = "dynamic-base16.nvim";
      rev = "b104678db460fc16bdbfac500ed5b677bd9567d8";
      hash = "sha256-tKKCHo5/ro5T5cre3LFfozSP4K74RluNoppUDsE3xk8=";
    };
  };
in
{
  imports = [ inputs.lazyvim.homeManagerModules.default ];

  programs.lazyvim = {
    enable = true;

    # Tools lazyvim-nix has no dependency mapping for, so `installDependencies`
    # on the matching extra installs nothing. Everything listed here lands on
    # nvim's PATH via the wrapper, not on the login shell's.
    extraPackages = with pkgs; [
      # LazyVim core: lua_ls is configured in lazyvim.plugins.lsp, stylua is the
      # core lua formatter. Neither has an extra to enable.
      lua-language-server
      stylua

      # lang.tailwind / lang.astro / HTML / CSS / JSON / Emmet
      tailwindcss-language-server
      astro-language-server
      vscode-langservers-extracted   # html, cssls, jsonls, eslint
      emmet-language-server          # JSX/HTML emmet completions

      # lang.nix
      nil
      nixfmt
      statix

      # lang.yaml / lang.markdown / lang.docker
      yaml-language-server
      marksman
      dockerfile-language-server
      docker-compose-language-service
    ];

    # sourcekit-lsp ships with Xcode and there is no LazyVim swift extra, so
    # the parser has to be requested by hand.
    treesitterParsers = with pkgs.vimPlugins.nvim-treesitter-parsers; [ swift ];

    extras = {
      util.mini-hipatterns.enable = true;

      # LazyVim uses blink.cmp for completion whether or not this extra is on,
      # but lazyvim-nix only pins the plugin when it is, and an unpinned
      # blink.cmp is a runtime git clone whose prebuilt Rust matcher has to
      # match the checkout. Enable it so completion comes from the store.
      coding.blink.enable = true;

      # Debug adapters come from the lang extras (delve via lang.go); dap.core
      # on its own only supplies the UI and the <leader>d keymaps.
      dap.core.enable = true;

      editor.neo-tree.enable = true;
      editor.illuminate.enable = true;
      editor.inc-rename.enable = true;
      editor.outline.enable = true;

      ui.indent-blankline.enable = true;
      ui.treesitter-context.enable = true;

      formatting.prettier = {
        enable = true;
        installDependencies = true;
        installRuntimeDependencies = true;
      };
      linting.eslint = {
        enable = true;
        installDependencies = true;
      };

      lang.docker = {
        enable = true;
        installDependencies = true;
      };
      lang.git.enable = true;
      lang.go = {
        enable = true;
        installDependencies = true;
        # go itself is already in the user profile.
        installRuntimeDependencies = false;
      };
      lang.json = {
        enable = true;
        installDependencies = true;
      };
      lang.markdown = {
        enable = true;
        installDependencies = true;
        installRuntimeDependencies = true;
      };
      lang.nix.enable = true;
      # rust-analyzer, cargo and rustc come from rustup in ~/.cargo/bin; a
      # second copy from nixpkgs would shadow the toolchain the projects use.
      lang.rust.enable = true;
      lang.toml = {
        enable = true;
        installDependencies = true;
      };
      lang.yaml.enable = true;

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
      # vtsls is the real TS LSP: lives under a nested extra, so the bare
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
              -- it below). Defaults to dark, reach light with `:set background=light`.
              -- Transparency isn't a plugin option here, the ColorScheme autocmd
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

      # Wallpaper-derived colours (Linux/DMS). matugen renders the live M3
      # palette into ~/.config/nvim/lua/dank_base16.lua as a base00..base0F
      # table (see the `neovim` user template in mixins/dms.nix),
      # dynamic-base16.nvim maps it onto all Treesitter/LSP highlight groups and,
      # with watch = true, hot-reloads when DMS rewrites the file (on every
      # wallpaper change / light-dark flip). flexoki (above) stays the base
      # colourscheme and the fallback: the setup is pcall-guarded so a missing file
      # (cold start before the first palette, or the macOS host where DMS
      # doesn't run) never breaks startup. nvim simply stays on flexoki until
      # the file exists (restart nvim once after the first palette is generated).
      dynamic-base16 = ''
        return {
          dir = "${dynamicBase16Nvim}",
          name = "dynamic-base16.nvim",
          lazy = false,
          priority = 999,
          config = function()
            pcall(function()
              require("dynamic-base16").setup({
                module = "dank_base16",
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
          dir = "${pkgs.vimPlugins.auto-dark-mode-nvim}",
          name = "auto-dark-mode.nvim",
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

      # LazyVim has no swift extra. sourcekit-lsp ships inside the Xcode
      # toolchain, so lspconfig's default cmd (`xcrun sourcekit-lsp`) resolves
      # without anything on nvim's PATH.
      sourcekit = ''
        return {
          "neovim/nvim-lspconfig",
          opts = {
            servers = {
              sourcekit = {
                filetypes = { "swift", "objc", "objcpp" },
              },
            },
          },
        }
      '';

      # nvim-dap-ui and lang.go's dap block pull these three in as bare
      # dependencies, so lazyvim-nix's plugin data has no entry for them and
      # lazy.nvim would clone each one at startup. Hand it the store paths.
      dap-deps = ''
        return {
          { dir = "${pkgs.vimPlugins.nvim-nio}", name = "nvim-nio", lazy = true },
          { dir = "${pkgs.vimPlugins.nvim-dap-virtual-text}", name = "nvim-dap-virtual-text", lazy = true },
          { dir = "${pkgs.vimPlugins.nvim-dap-go}", name = "nvim-dap-go", lazy = true },
        }
      '';

      # nil asks "Some flake inputs are not available. Fetch them now?" through
      # a showMessageRequest the first time it evaluates a flake whose inputs
      # are not all in the store, which is every cold open of this repo. false
      # means never fetch and never ask.
      nil-ls = ''
        return {
          "neovim/nvim-lspconfig",
          opts = {
            servers = {
              nil_ls = {
                settings = {
                  ["nil"] = {
                    nix = {
                      flake = {
                        autoArchive = false,
                        autoEvalInputs = false,
                      },
                    },
                  },
                },
              },
            },
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

            -- During session :source the foreground :edit fires BufReadPre,
            -- which lazy.nvim hijacks to load nvim-lspconfig / nvim-treesitter.
            -- Empirically the natural :edit continuation (BufRead → filetype
            -- detect → FileType) does not complete for that buffer. &filetype
            -- ends up empty, so vim.lsp.enable's FileType autocmd and the TS
            -- highlighter never match anything. Re-run filetype detection on
            -- every restored buffer, setting &filetype fires FileType, which
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

      # vim-tmux-navigator IS in nixpkgs, but lazyvim-nix's resolver doesn't
      # know the mapping. Hand it the store path directly.
      tmux-navigator = ''
        return {
          dir = "${pkgs.vimPlugins.vim-tmux-navigator}",
          name = "vim-tmux-navigator",
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

  # vim.loader validates its bytecode cache on (path, size, mtime). Every file
  # under /nix/store carries mtime 1, and a plugin spec whose only change is the
  # store hash keeps the same byte length, so the cache never invalidates: nvim
  # goes on loading specs that point at store paths the last GC removed, and
  # every plugin behind one of them silently fails to load. Drop the cache on
  # activation, nvim recompiles it on the next start.
  home.activation.clearNvimLuacCache = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD rm -rf $VERBOSE_ARG "${config.home.homeDirectory}/.cache/nvim/luac"
  '';
}
