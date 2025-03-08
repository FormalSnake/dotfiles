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
    plugins = with pkgs.vimPlugins; [
      {
        plugin = autoclose-nvim;
        config = toLuaFile ./nvim/plugins/autoclose.lua;
      }
    ];
  };
}
