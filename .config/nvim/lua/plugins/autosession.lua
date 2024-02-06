return {
  {
    "rmagatti/auto-session",
    opts = {
      log_level = "error",
      auto_session_suppress_dirs = { "~/", "~/Projects", "~/Downloads", "/" },
      cwd_change_handling = {
        restore_upcoming_session = false, -- already the default, no need to specify like this, only here as an example
      },
      pre_save_cmds = { "Neotree close" },
      auto_restore_enabled = false,
    },
  },
}
