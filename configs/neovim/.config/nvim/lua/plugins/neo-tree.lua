-- Override LazyVim's neo-tree extra for yarn monorepo support
return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = {
    filesystem = {
      bind_to_cwd = false, -- Use LazyVim root detection, not cwd
      follow_current_file = { enabled = true, leave_dirs_open = true },
      filtered_items = {
        hide_by_name = { "node_modules" },
        never_show = { ".DS_Store" },
      },
    },
  },
}
