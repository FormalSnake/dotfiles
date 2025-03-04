{
  # Import all your configuration modules here
  imports = [ ./bufferline.nix ./options.nix ./cmp.nix ./nvim-tree.nix ./extra-plugins.nix ./snacks.nix ];

  plugins = {
    lualine.enable = true;
    treesitter.enable = true;
    luasnip.enable = true;
    tmux-navigator.enable = true;
    autoclose.enable = true;
    dropbar.enable = true;
    render-markdown.enable = true;
    todo-comments.enable = true;
  };

  plugins.lsp = {
    enable = true;
    servers = {
      ts_ls.enable = true;
      lua_ls.enable = true;
      nil_ls.enable = true;
      rust_analyzer = {
        enable = true;
        installCargo = false;
        installRustc = false;
      };
    };
  };

  colorschemes.tokyonight.enable = true;

  globals.mapleader = " ";

  keymaps = [
    {
      action = "<CMD>lua Snacks.picker.lines()<CR>";
      key = "<leader>/";
    }
    {
      action = "<CMD>NvimTreeToggle<CR>";
      # action = "<CMD>lua Snacks.explorer.open()<CR>";
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
    {
      action = "<CMD>lua Snacks.lazygit()<CR>";
      key = "<leader>gg";
    }
    {
      action = "<CMD>lua Snacks.zen()<CR>";
      key = "<leader>z";
    }
  ];
}
