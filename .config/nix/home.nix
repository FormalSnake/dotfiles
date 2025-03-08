{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: {
  nixpkgs = {
    overlays = [
      (final: prev: {
        vimPlugins =
          prev.vimPlugins
          // {
            own-auto-dark-mode = prev.vimUtils.buildVimPlugin {
              name = "auto-dark-mode.nvim";
              src = inputs.plugin-auto-dark-mode;
            };
            # own-snacks = prev.vimPlugins.snacks-nvim.overrideAttrs (oldAttrs: rec {
            #   nvimSkipModule = [
            #     "snacks.dashboard"
            #     "snacks.debug"
            #     "snacks.dim"
            #     "snacks.git"
            #     "snacks.image.convert"
            #     "snacks.image.image"
            #     "snacks.image.init"
            #     "snacks.image.placement"
            #     "snacks.indent"
            #     "snacks.input"
            #     "snacks.lazygit"
            #     "snacks.notifier"
            #     "snacks.picker.actions"
            #     "snacks.picker.config.highlights"
            #     "snacks.picker.core.list"
            #     "snacks.scratch"
            #     "snacks.scroll"
            #     "snacks.terminal"
            #     "snacks.win"
            #     "snacks.words"
            #     "snacks.zen"
            #     "trouble.sources.profiler"
            #     "snacks.picker.util.db"
            #   ];
            # });
            # own-snacks = prev.vimUtils.buildVimPlugin {
            #   name = "snacks.nvim";
            #   src = inputs.plugin-snacks;
            # };
          };
      })
    ];
  };
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "kyandesutter";
  home.homeDirectory = "/Users/kyandesutter";

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "24.11";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  home.packages = [
    pkgs.cowsay
    # Text Editors
    # pkgs.neovim # Modern, extensible Vim-based text editor

    # Terminal Multiplexers
    pkgs.tmux # Terminal multiplexer for managing multiple terminal sessions
  ];

  programs.git = {
    enable = true;
    userName = "FormalSnake";
    userEmail = "kyaniserni@gmail.com";
  };

  # configure neovim using the existing lua config
  programs.neovim = let
    toLua = str: "lua << EOF\n${str}\nEOF\n";
    toLuaFile = file: "lua << EOF\n${builtins.readFile file}\nEOF\n";
  in {
    enable = true;
    # extraLuaConfig = ''
    #   ${builtins.readFile ./nvim/init.lua}
    # '';

    extraPackages = with pkgs; [
      lua-language-server
      nil
      astro-language-server
      alejandra
      typescript-language-server
    ];

    plugins = with pkgs.vimPlugins; [
      # tokyonight theme
      {
        plugin = tokyonight-nvim;
      }

      {
        # plugin = own-snacks;
        plugin = snacks-nvim;
        config = toLuaFile ./nvim/plugins/snacks.lua;
      }

      {
        plugin = nvim-lspconfig;
        config = toLuaFile ./nvim/plugins/lsp.lua;
      }

      {
        plugin = own-auto-dark-mode;
        config = toLuaFile ./nvim/plugins/colorscheme.lua;
      }

      {
        plugin = autoclose-nvim;
        config = toLuaFile ./nvim/plugins/autoclose.lua;
      }

      {
        plugin = auto-session;
        config = toLuaFile ./nvim/plugins/autosession.lua;
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
        plugin = image-nvim;
        config = toLuaFile ./nvim/plugins/image.lua;
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

      lazydev-nvim

      noice-nvim

      todo-comments-nvim

      ts-comments-nvim

      dropbar-nvim

      telescope-fzf-native-nvim

      cord-nvim

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
        ]);
        config = toLuaFile ./nvim/plugins/treesitter.lua;
      }

      vim-nix
    ];

    extraLuaConfig = ''
      ${builtins.readFile ./nvim/options.lua}
    '';
  };
}
