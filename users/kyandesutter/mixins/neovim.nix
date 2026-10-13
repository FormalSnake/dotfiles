{ pkgs, ... }:
{
  # The config itself lives in ../config/nvim. Plugins load eagerly from the
  # store (no plugin manager), and language servers sit on the wrapper's PATH,
  # not the login shell's.
  programs.neovim = {
    enable = true;
    withRuby = false;
    withPython3 = false;
    withNodeJs = false;

    plugins = with pkgs.vimPlugins; [
      snacks-nvim
      which-key-nvim
      flash-nvim
      persistence-nvim
      lazydev-nvim
      mini-icons
      gitsigns-nvim
      blink-cmp
      render-markdown-nvim
      nvim-lspconfig
      nvim-treesitter.withAllGrammars
      vim-tmux-navigator
    ];

    initLua = builtins.readFile ../config/nvim/init.lua;

    extraPackages = with pkgs; [
      # snacks: picker, image conversion, lazygit integration
      ripgrep
      fd
      imagemagick
      ghostscript

      lua-language-server
      nil
      nixfmt
      vtsls
      tailwindcss-language-server
      astro-language-server
      vscode-langservers-extracted # html, cssls, jsonls, eslint
      yaml-language-server
      taplo
      marksman
      dockerfile-language-server
      docker-compose-language-service
      gopls
    ];
  };

  xdg.configFile."nvim/colors/terminal.lua".source = ../config/nvim/colors/terminal.lua;
}
