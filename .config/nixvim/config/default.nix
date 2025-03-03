{
  # Import all your configuration modules here
  imports = [ ./bufferline.nix ./options.nix ];

  plugins = {
    lualine.enable = true;
    treesitter.enable = true;
    luasnip.enable = true;
  };

  plugins.lsp = {
    enable = true;
    servers = {
      tsserver.enable = true;
      lua-ls.enable = true;
      rust-analyzer.enable = true;
    };
  };

  plugins.cmp = {
    enable = true;
    autoEnableSources = true;
    settings.sources = [
      {name = "nvim_lsp";}
      {name = "path";}
      {name = "buffer";}
    ];
  };

  plugins.snacks = {
    enable = true;
  };
}
