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
      # LSP servers
      lua-language-server
      nil # Nix LSP
      nodePackages.typescript-language-server
      nodePackages.vscode-langservers-extracted # HTML, CSS, JSON
      nodePackages."@astrojs/language-server"
      nodePackages."@tailwindcss/language-server"
      # Formatters
      nodePackages.prettier
      stylua
      # Tools
      ripgrep
      fd
      # Image and document processing
      ghostscript
      # tectonic
      nodePackages.mermaid-cli
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
      {
        plugin = nvim-lspconfig;
        config = toLuaFile ./plugins/lsp.lua;
      }
      {
        plugin = own-auto-dark-mode;
        config = toLuaFile ./plugins/colorscheme.lua;
      }
      nvim-scrollview
      {
        plugin = minimap-vim;
      }
      opencode-nvim
      {
        plugin = claudecode-nvim;
        config = toLua ''
          require("claudecode").setup()
        '';
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

      # Phase 1: Essential Navigation Tools
      {
        plugin = nvim-surround;
        config = toLuaFile ./plugins/surround.lua;
      }
      vim-repeat

      # Phase 3: Productivity Tools
      {
        plugin = nvim-spectre;
        config = toLuaFile ./plugins/spectre.lua;
      }
      {
        plugin = yanky-nvim;
        config = toLuaFile ./plugins/yanky.lua;
      }
      {
        plugin = nvim-various-textobjs;
        config = toLuaFile ./plugins/various-textobjs.lua;
      }
      # Phase 4: UI and Visual Feedback
      {
        plugin = fidget-nvim;
        config = toLuaFile ./plugins/fidget.lua;
      }

      lazydev-nvim
      todo-comments-nvim
      ts-comments-nvim
      dropbar-nvim
      telescope-fzf-native-nvim
      neocord
      nvim-web-devicons

      # Better diagnostics and quickfix
      {
        plugin = trouble-nvim;
        config = toLua ''
          require("trouble").setup({
            auto_close = true,
            auto_preview = true,
            indent_guides = true,
          })
        '';
      }

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
      cmp-cmdline

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
          p.tree-sitter-html
          p.tree-sitter-javascript
          p.tree-sitter-markdown
          p.tree-sitter-yaml
          p.tree-sitter-latex
          p.tree-sitter-scss
          p.tree-sitter-svelte
          p.tree-sitter-vue
          p.tree-sitter-regex
          p.tree-sitter-norg
          p.tree-sitter-typst
        ]);
        config = toLuaFile ./plugins/treesitter.lua;
      }
      nvim-treesitter-textobjects

      vim-nix

      # Tailwind CSS support
      {
        plugin = nvim-colorizer-lua;
        config = toLua ''
          require("colorizer").setup({
            filetypes = { "*" },
            user_default_options = {
              RGB = true,
              RRGGBB = true,
              names = true,
              RRGGBBAA = false,
              AARRGGBB = false,
              rgb_fn = false,
              hsl_fn = false,
              css = false,
              css_fn = false,
              mode = "background",
              tailwind = true,
              sass = { enable = false, parsers = { "css" } },
              virtualtext = "■",
            },
            buftypes = {},
          })
        '';
      }
    ];

    extraLuaConfig = ''
      ${builtins.readFile ./core/globals.lua}
      ${builtins.readFile ./options.lua}
      ${builtins.readFile ./core/keymaps.lua}
      ${builtins.readFile ./core/autocmds.lua}
    '';
  };
}
