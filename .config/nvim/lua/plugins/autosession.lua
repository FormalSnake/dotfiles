return {
  {
  'rmagatti/auto-session',
  config = function()
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
      vim.keymap.set('n', '<leader>fs', require('auto-session.session-lens').search_session, {
        noremap = true,
      })
  }
    end,
  },
}
