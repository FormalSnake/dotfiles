{
  config,
  pkgs,
  lib,
  ...
}: {
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
      rnix-lsp

      xclip
      wl-clipboard
    ];

    plugins = with pkgs.vimPlugins; [
      # tokyonight theme
      {
        plugin = tokyonight-nvim;
        config = toLua "colorscheme tokyonight-night";
      }

      {
        plugin = autoclose-nvim;
        config = toLuaFile ./nvim/plugins/autoclose.lua;
      }

      {
        plugin = auto-session;
        config = toLuaFile ./nvim/plugins/auto-session.lua;
      }

      {
        plugin = nvim-ts-autotag;
        config = toLuaFile ./nvim/plugins/autotag.lua;
      }

      nvim-cmp
      {
        plugin = nvim-cmp;
        config = toLuaFile ./nvim/plugin/cmp.lua;
      }

      cmp_luasnip
      cmp-nvim-lsp

      luasnip
      friendly-snippets

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
  };
}
