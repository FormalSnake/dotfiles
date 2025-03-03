{pkgs, ...}: let
auto-dark-mode-nvim = pkgs.vimUtils.buildVimPlugin {
    name = "auto-dark-mode-nvim";
    src = pkgs.fetchFromGitHub {
      owner = "f-person";
      repo = "auto-dark-mode.nvim";
      rev = "02ef9553e2a1d6e861bc6955d58ce5883d28a6ad";
      hash = "sha256-FTXakglUrqifEXjzES6M4L+rthItu5rlw6QyIOLYNOc=";
    };
    nvimSkipModule = "outline.providers.norg";
  };
in {
  extraPlugins = with pkgs; [
    vimPlugins.supermaven-nvim # AI code completion
    vimPlugins.cord-nvim
    vimPlugins.auto-session
    auto-dark-mode-nvim
  ];

  extraConfigLua = ''
    require('auto-session').setup {
            suppressed_dirs = { '~/', '~/Projects', '~/Downloads', '/' },
            -- log_level = 'debug',
            session_lens = {
              load_on_setup = true,
              previewer = false,
              mappings = {
                -- Mode can be a string or a table, e.g. {"i", "n"} for both insert and normal mode
                delete_session = { "i", "<C-D>" },
                alternate_session = { "i", "<C-S>" },
                copy_session = { "i", "<C-Y>" },
              },
            },
            -- vim.keymap.set('n', '<leader>fs', require('auto-session.session-lens').search_session, {
            --   noremap = true,
            -- })
          }
    require("cord").setup()
    require("auto-dark-mode").setup({
    set_dark_mode = function()
            vim.cmd.colorscheme("tokyonight-night")
          end,
          set_light_mode = function()
            vim.cmd.colorscheme("tokyonight-day")
          end,
    })
    require("supermaven-nvim").setup({
      keymaps = {
        accept_suggestion = "<Tab>",
        clear_suggestion = "<C-]>",
        accept_word = "<C-j>",
      },
      ignore_filetypes = { cpp = true }, -- or { "cpp", }
      color = {
        suggestion_color = "#ffffff",
        cterm = 244,
      },
      log_level = "info", -- set to "off" to disable logging completely
      disable_inline_completion = true, -- disables inline completion for use with cmp
      disable_keymaps = false, -- disables built in keymaps for more manual control
      condition = function()
        return false
      end -- condition to check for stopping supermaven, `true` means to stop supermaven when the condition is true.
    })
  '';
}
