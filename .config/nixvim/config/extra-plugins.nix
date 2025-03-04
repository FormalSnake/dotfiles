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
image-nvim = pkgs.vimUtils.buildVimPlugin {
    name = "image-nvim";
    src = pkgs.fetchFromGitHub {
      owner = "3rd";
      repo = "image.nvim";
      rev = "6ffafab2e98b5bda46bf227055aa84b90add8cdc";
      hash = "sha256-/8kcG5chhugrzF4LSCFpKsA4mCILXgpOtd6isBkjs4A=";
    };
    nvimSkipModule = "minimal-setup";
  };
in {
  extraPlugins = with pkgs; [
    vimPlugins.supermaven-nvim # AI code completion
    vimPlugins.cord-nvim
    vimPlugins.auto-session
    auto-dark-mode-nvim
    image-nvim
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
    require("image").setup({
            backend = "kitty",
            processor = "magick_cli", -- or "magick_cli"
            integrations = {
              markdown = {
                enabled = true,
                clear_in_insert_mode = false,
                download_remote_images = true,
                only_render_image_at_cursor = true,
                filetypes = { "markdown", "vimwiki" }, -- markdown extensions (ie. quarto) can go here
              },
              neorg = {
                enabled = true,
                filetypes = { "norg" },
              },
              typst = {
                enabled = true,
                filetypes = { "typst" },
              },
              html = {
                enabled = false,
              },
              css = {
                enabled = false,
              },
            },
            max_width = nil,
            max_height = nil,
            max_width_window_percentage = nil,
            max_height_window_percentage = 50,
            window_overlap_clear_enabled = false,                                               -- toggles images when windows are overlapped
            window_overlap_clear_ft_ignore = { "cmp_menu", "cmp_docs", "" },
            editor_only_render_when_focused = false,                                            -- auto show/hide images when the editor gains/looses focus
            tmux_show_only_in_active_window = false,                                            -- auto show/hide images in the correct Tmux window (needs visual-activity off)
            hijack_file_patterns = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.avif" }, -- render image files as images when opened
          })
  '';
}
