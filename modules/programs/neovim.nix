{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  toLua = str: "lua << EOF\n${str}\nEOF\n";
  toLuaFile = file: "lua << EOF\n${builtins.readFile file}\nEOF\n";
in {
  programs.neovim = {
    enable = true;

    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    extraPackages = with pkgs; [
      alejandra
    ];

    plugins = with pkgs.vimPlugins; [
      # {
      #   plugin = tokyonight-nvim;
      #   config = "colorscheme tokyonight-night";
      # }
      {
        plugin = snacks-nvim;
        config = toLuaFile ./nvim/plugins/snacks.lua;
      }
      lsp-zero-nvim
      nvim-lspconfig
      {
        plugin = lazy-lsp-nvim;
        config = toLua ''
          local lsp_zero = require("lsp-zero")

          lsp_zero.on_attach(function(client, bufnr)
            -- see :help lsp-zero-keybindings to learn the available actions
            lsp_zero.default_keymaps({
              buffer = bufnr,
              preserve_mappings = false
            })
          end)

          require("lazy-lsp").setup {
            excluded_servers = {
              "denols",
              "eslint",
              "oxlint",
              "quick_lint_js",
              "biome"
            },
          }
        '';
      }
      # {
      #   plugin = nvim-lspconfig;
      #   config = toLuaFile ./nvim/plugins/lsp.lua;
      # }
      {
        plugin = own-auto-dark-mode;
        config = toLuaFile ./nvim/plugins/colorscheme.lua;
      }
      github-nvim-theme
      # {
      #   plugin = own-base16;
      #   config = toLuaFile ./nvim/plugins/colorscheme.lua;
      # }
      {
        plugin = own-visual-whitespace;
        config = toLua ''
        vim.g.visual_whitespace = {
          enabled = true,
  highlight = { link = "Visual", default = true },
  match_types = {
    space = true,
    tab = true,
    nbsp = true,
    lead = false,
    trail = false,
  },
  list_chars = {
    space = "·",
    tab = "↦",
    nbsp = "␣",
    lead = "‹",
    trail = "›",
  },
  fileformat_chars = {
    unix = "↲",
    mac = "←",
    dos = "↙",
  },
  ignore = { filetypes = {}, buftypes = {} },
        }
        '';
      }
      {
        plugin = own-tidy;
        config = toLua "require(\"tidy\").setup()";
      }
      {
        plugin = autoclose-nvim;
        config = toLuaFile ./nvim/plugins/autoclose.lua;
      }
      # {
      #   plugin = statuscol-nvim;
      #   config = toLuaFile ./nvim/plugins/statuscol.lua;
      # }
      {
        plugin = auto-session;
        config = toLuaFile ./nvim/plugins/autosession.lua;
      }
      {
        plugin = own-bg;
        config = toLua "require(\"bg\").setup()";
      }
      {
        plugin = nvim-ts-autotag;
        config = toLuaFile ./nvim/plugins/autotag.lua;
      }
      {
        plugin = conform-nvim;
        config = toLuaFile ./nvim/plugins/format.lua;
      }
      {
        plugin = gitsigns-nvim;
        config = toLuaFile ./nvim/plugins/git-stuff.lua;
      }
      {
        plugin = lsp_lines-nvim;
        config = toLua "require(\"lsp_lines\").setup()";
      }
      {
        plugin = lualine-nvim;
        config = toLuaFile ./nvim/plugins/lualine.lua;
      }
      {
        plugin = render-markdown-nvim;
        config = toLuaFile ./nvim/plugins/markdown.lua;
      }
      {
        plugin = supermaven-nvim;
        config = toLuaFile ./nvim/plugins/supermaven.lua;
      }
      {
        plugin = vim-tmux-navigator;
        config = toLuaFile ./nvim/plugins/tmuxnavigator.lua;
      }
      {
        plugin = treesj;
        config = toLuaFile ./nvim/plugins/treesj.lua;
      }
      {
        plugin = which-key-nvim;
        config = toLuaFile ./nvim/plugins/whichkey.lua;
      }
      {
        plugin = noice-nvim;
        config = toLua "require(\"noice\").setup()";
      }
      {
        plugin = own-aider;
        config = toLua ''
          require("nvim_aider").setup({})
          local wk = require("which-key")
          wk.add({
            { "<leader>a/", "<cmd>AiderTerminalToggle<CR>", desc = "Open Aider" },
            { "<leader>as", "<cmd>AiderTerminalSend<CR>", desc = "Send to Aider", mode = { "n", "v" } },
            { "<leader>ac", "<cmd>AiderQuickSendCommand<CR>", desc = "Send Command To Aider" },
            { "<leader>ab", "<cmd>AiderQuickSendBuffer<CR>", desc = "Send Buffer To Aider" },
            { "<leader>a+", "<cmd>AiderQuickAddFile<CR>", desc = "Add File to Aider" },
            { "<leader>a-", "<cmd>AiderQuickDropFile<CR>", desc = "Drop File from Aider" },
            { "<leader>ar", "<cmd>AiderQuickReadOnlyFile<CR>", desc = "Add File as Read-Only" },
          })
        '';
      }

      lazydev-nvim
      todo-comments-nvim
      ts-comments-nvim
      dropbar-nvim
      telescope-fzf-native-nvim
      neocord
      nvim-web-devicons

      {
        plugin = nvim-cmp;
        config = toLuaFile ./nvim/plugins/cmp.lua;
      }

      cmp_luasnip
      cmp-nvim-lsp
      luasnip
      friendly-snippets
      cmp-buffer
      lspkind-nvim
      cmp-path

      {
        plugin = nvim-treesitter.withPlugins (p: [
          p.tree-sitter-nix
          p.tree-sitter-vim
          p.tree-sitter-bash
          p.tree-sitter-lua
          p.tree-sitter-python
          p.tree-sitter-json
          p.tree-sitter-astro
          p.tree-sitter-typescript
          p.tree-sitter-css
          p.tree-sitter-tsx
        ]);
        config = toLuaFile ./nvim/plugins/treesitter.lua;
      }

      vim-nix
    ];

    extraLuaConfig = ''
      ${builtins.readFile ./nvim/options.lua}
      ${builtins.readFile ./nvim/core/globals.lua}
    '';
  };
}