require("aerial").setup({
  backends = { "treesitter", "lsp", "markdown", "asciidoc", "man" },
  layout = {
    max_width = { 40, 0.2 },
    width = nil,
    min_width = 10,
    win_opts = {},
    default_direction = "prefer_right",
    placement = "window",
    preserve_equality = false,
  },
  attach_mode = "window",
  close_automatic_events = {},
  keymaps = {
    ["?"] = "actions.show_help",
    ["g?"] = "actions.show_help",
    ["<CR>"] = "actions.jump",
    ["<2-LeftMouse>"] = "actions.jump",
    ["<C-v>"] = "actions.jump_vsplit",
    ["<C-s>"] = "actions.jump_split",
    ["p"] = "actions.scroll",
    ["<C-j>"] = "actions.down_and_scroll",
    ["<C-k>"] = "actions.up_and_scroll",
    ["{"] = "actions.prev",
    ["}"] = "actions.next",
    ["[["] = "actions.prev_up",
    ["]]"] = "actions.next_up",
    ["q"] = "actions.close",
    ["o"] = "actions.tree_toggle",
    ["za"] = "actions.tree_toggle",
    ["O"] = "actions.tree_toggle_recursive",
    ["zA"] = "actions.tree_toggle_recursive",
    ["l"] = "actions.tree_open",
    ["zo"] = "actions.tree_open",
    ["L"] = "actions.tree_open_recursive",
    ["zO"] = "actions.tree_open_recursive",
    ["h"] = "actions.tree_close",
    ["zc"] = "actions.tree_close",
    ["H"] = "actions.tree_close_recursive",
    ["zC"] = "actions.tree_close_recursive",
    ["zr"] = "actions.tree_increase_fold_level",
    ["zR"] = "actions.tree_open_all",
    ["zm"] = "actions.tree_decrease_fold_level",
    ["zM"] = "actions.tree_close_all",
    ["zx"] = "actions.tree_sync_folds",
    ["zX"] = "actions.tree_sync_folds",
  },
  lazy_load = true,
  disable_max_lines = 10000,
  disable_max_size = 2000000,
  filter_kind = {
    "Class",
    "Constructor",
    "Enum",
    "Function",
    "Interface",
    "Module",
    "Method",
    "Struct",
  },
  highlight_mode = "split_width",
  highlight_closest = true,
  highlight_on_hover = false,
  highlight_on_jump = 300,
  autojump = false,
  icons = {},
  ignore = {
    unlisted_buffers = false,
    diff_windows = true,
    filetypes = {},
    buftypes = "special",
    wintypes = "special",
  },
  manage_folds = true,
  link_folds_to_tree = false,
  link_tree_to_folds = true,
  nerd_font = "auto",
  on_attach = function(bufnr)
    vim.keymap.set("n", "{", "<cmd>AerialPrev<CR>", { buffer = bufnr })
    vim.keymap.set("n", "}", "<cmd>AerialNext<CR>", { buffer = bufnr })
  end,
  on_first_symbols = function(bufnr) end,
  open_automatic = function(bufnr)
    return vim.api.nvim_buf_line_count(bufnr) > 80
      and aerial.num_symbols(bufnr) > 4
      and not aerial.was_closed()
  end,
  post_jump_cmd = "normal! zz",
  close_on_select = false,
  update_events = "TextChanged,InsertLeave",
  show_guides = false,
  guides = {
    mid_item = "├─",
    last_item = "└─",
    nested_top = "│ ",
    whitespace = "  ",
  },
  float = {
    border = "rounded",
    relative = "cursor",
    max_height = 0.9,
    height = nil,
    min_height = { 8, 0.1 },
    override = function(conf, source_winid)
      return conf
    end,
  },
  lsp = {
    diagnostics_trigger_update = true,
    update_when_errors = true,
    update_delay = 300,
    priority = {
      pyright = 10,
    },
  },
  treesitter = {
    update_delay = 300,
  },
  markdown = {
    update_delay = 300,
  },
  asciidoc = {
    update_delay = 300,
  },
  man = {
    update_delay = 300,
  },
})

-- Keymaps
local wk = require("which-key")
wk.add({
  { "<leader>o", "<cmd>AerialToggle!<CR>", desc = "Toggle Aerial outline" },
  { "<leader>O", "<cmd>AerialOpen<CR>", desc = "Open Aerial outline" },
  { "<leader>[", "<cmd>AerialPrev<CR>", desc = "Previous symbol" },
  { "<leader>]", "<cmd>AerialNext<CR>", desc = "Next symbol" },
})