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
    ];

    # astro-ls needs a TypeScript SDK and a project without node_modules has
    # none. TypeScript 7 dropped tsserverlibrary.js, so the fallback is 5.x.
    initLua = ''
      vim.g.tsdk = "${pkgs.typescript_5}/lib/node_modules/typescript/lib"
    '' + builtins.readFile ../config/nvim/init.lua;

    # extraPackages land at the end of PATH, behind ~/.cargo/bin, whose
    # rust-analyzer is a rustup proxy with no component installed. Put the
    # nixpkgs one first, and give it std sources since the toolchain has no
    # rust-src either.
    extraWrapperArgs = [
      "--prefix"
      "PATH"
      ":"
      "${pkgs.rust-analyzer}/bin"
      "--set-default"
      "RUST_SRC_PATH"
      "${pkgs.rustPlatform.rustLibSrc}"
    ];

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
