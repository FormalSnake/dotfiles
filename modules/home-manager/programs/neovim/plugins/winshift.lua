require("winshift").setup({
  highlight_moving_win = true,
  focused_hl_group = "Visual",
  moving_win_options = {
    wrap = false,
    cursorline = false,
    cursorcolumn = false,
    colorcolumn = "",
  },
  keymaps = {
    disable_defaults = false,
    win_move_mode = {
      ["h"] = "left",
      ["j"] = "down",
      ["k"] = "up",
      ["l"] = "right",
      ["H"] = "far_left",
      ["J"] = "far_down",
      ["K"] = "far_up",
      ["L"] = "far_right",
      ["<left>"] = "left",
      ["<down>"] = "down",
      ["<up>"] = "up",
      ["<right>"] = "right",
      ["<S-left>"] = "far_left",
      ["<S-down>"] = "far_down",
      ["<S-up>"] = "far_up",
      ["<S-right>"] = "far_right",
    },
  },
  window_picker = function()
    return require("winshift.lib").pick_window({
      picker_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890",
      filter_rules = {
        cur_win = true,
        floats = true,
        filetype = {},
        buftype = {},
        bufname = {},
      },
      ---A function used to filter the list of selectable windows.
      ---@param winids integer[] # The list of selectable window IDs.
      ---@return integer[] filtered # The filtered list of window IDs.
      filter_func = nil,
    })
  end,
})

-- Keymaps
local wk = require("which-key")
wk.add({
  { "<leader>w", group = "windows" },
  { "<leader>wm", "<cmd>WinShift<CR>", desc = "Start WinShift mode" },
  { "<leader>wx", "<cmd>WinShift swap<CR>", desc = "Swap windows" },
  { "<leader>wh", "<cmd>WinShift left<CR>", desc = "Move window left" },
  { "<leader>wj", "<cmd>WinShift down<CR>", desc = "Move window down" },
  { "<leader>wk", "<cmd>WinShift up<CR>", desc = "Move window up" },
  { "<leader>wl", "<cmd>WinShift right<CR>", desc = "Move window right" },
  { "<leader>wH", "<cmd>WinShift far_left<CR>", desc = "Move window far left" },
  { "<leader>wJ", "<cmd>WinShift far_down<CR>", desc = "Move window far down" },
  { "<leader>wK", "<cmd>WinShift far_up<CR>", desc = "Move window far up" },
  { "<leader>wL", "<cmd>WinShift far_right<CR>", desc = "Move window far right" },
})