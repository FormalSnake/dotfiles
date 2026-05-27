{ inputs, ... }:
{
  imports = [ inputs.lazyvim.homeManagerModules.default ];

  programs.lazyvim = {
    enable = true;

    extras = {
      ai.supermaven.enable = true;
      editor.neo-tree.enable = true;
      util.mini-hipatterns.enable = true;

      lang.astro = {
        enable = true;
        installDependencies = true;
        installRuntimeDependencies = true;
      };
      lang.tailwind = {
        enable = true;
        # tailwindcss has no nixpkgs mapping in lazyvim-nix; project's own
        # node_modules / package manager provides the LSP and CLI.
        installDependencies = false;
        installRuntimeDependencies = true;
      };
      lang.typescript = {
        enable = true;
        installDependencies = true;
        installRuntimeDependencies = true;
      };
    };

    plugins.tmux-navigator = ''
      return {
        "christoomey/vim-tmux-navigator",
        cmd = {
          "TmuxNavigateLeft",
          "TmuxNavigateDown",
          "TmuxNavigateUp",
          "TmuxNavigateRight",
          "TmuxNavigatePrevious",
          "TmuxNavigatorProcessList",
        },
        keys = {
          { "<c-h>", "<cmd><C-U>TmuxNavigateLeft<cr>" },
          { "<c-j>", "<cmd><C-U>TmuxNavigateDown<cr>" },
          { "<c-k>", "<cmd><C-U>TmuxNavigateUp<cr>" },
          { "<c-l>", "<cmd><C-U>TmuxNavigateRight<cr>" },
          { [[<c-\>]], "<cmd><C-U>TmuxNavigatePrevious<cr>" },
        },
      }
    '';
  };
}
