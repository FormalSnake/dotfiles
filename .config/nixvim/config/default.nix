{
  # Import all your configuration modules here
  imports = [ ./bufferline.nix ./options.nix ./cmp.nix ];

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

  # plugins.cmp = {
  #   enable = true;
  #   autoEnableSources = true;
  #   settings.sources = [
  #     {name = "nvim_lsp";}
  #     {name = "path";}
  #     {name = "buffer";}
  #   ];
  # };

  plugins.snacks = {
    enable = true;
  };

  colorschemes.tokyonight.enable = true;

  globals.mapleader = " ";

  keymaps = [
    {
      action = "<CMD>lua Snacks.picker.lines()<CR>";
      key = "<leader>/";
    }
    {
      action = "<CMD>lua Snacks.explorer.open()<CR>";
      key = "<leader>e";
    }
    {
      action = "<CMD> lua Snacks.picker.files()<CR>";
      key = "<leader>ff";
    }
    {
      action = "<CMD>lua Snacks.picker.grep()<CR>";
      key = "<leader>fw";
    }
  ];
}
