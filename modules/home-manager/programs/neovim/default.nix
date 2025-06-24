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
      {
        plugin = catppuccin-nvim;
        config = "";
      }
      {
        plugin = snacks-nvim;
        config = toLuaFile ./plugins/snacks.lua;
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
      {
        plugin = own-auto-dark-mode;
        config = toLuaFile ./plugins/colorscheme.lua;
      }
      github-nvim-theme
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
        config = toLuaFile ./plugins/autoclose.lua;
      }
      {
        plugin = auto-session;
        config = toLuaFile ./plugins/autosession.lua;
      }
      {
        plugin = own-bg;
        config = toLua ''
          local ok, bg = pcall(require, "bg")
          if ok then
            bg.setup()
          end
        '';
      }
      {
        plugin = nvim-ts-autotag;
        config = toLuaFile ./plugins/autotag.lua;
      }
      {
        plugin = conform-nvim;
        config = toLuaFile ./plugins/format.lua;
      }
      {
        plugin = gitsigns-nvim;
        config = toLuaFile ./plugins/git-stuff.lua;
      }
      {
        plugin = lsp_lines-nvim;
        config = toLua "require(\"lsp_lines\").setup()";
      }
      {
        plugin = lualine-nvim;
        config = toLuaFile ./plugins/lualine.lua;
      }
      {
        plugin = render-markdown-nvim;
        config = toLuaFile ./plugins/markdown.lua;
      }
      {
        plugin = supermaven-nvim;
        config = toLuaFile ./plugins/supermaven.lua;
      }
      {
        plugin = vim-tmux-navigator;
        config = toLuaFile ./plugins/tmuxnavigator.lua;
      }
      {
        plugin = treesj;
        config = toLuaFile ./plugins/treesj.lua;
      }
      codecompanion-nvim
      {
        plugin = which-key-nvim;
        config = toLuaFile ./plugins/whichkey.lua;
      }
      {
        plugin = noice-nvim;
        config = toLua "require(\"noice\").setup()";
      }
      own-transparent
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
        config = toLuaFile ./plugins/cmp.lua;
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
        config = toLuaFile ./plugins/treesitter.lua;
      }

      vim-nix
    ];

    extraLuaConfig = ''
      ${builtins.readFile ./core/globals.lua}
      ${builtins.readFile ./options.lua}
    '';
  };
}
