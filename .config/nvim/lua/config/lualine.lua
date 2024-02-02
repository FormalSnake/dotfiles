local progress = function()
  local current_line = vim.fn.line(".")
  local total_lines = vim.fn.line("$")
  local chars = { "__", "▁▁", "▂▂", "▃▃", "▄▄", "▅▅", "▆▆", "▇▇", "██" }
  local line_ratio = current_line / total_lines
  local index = math.ceil(line_ratio * #chars)
  return chars[index]
end

require('lualine').setup {
  options = {
    theme = "auto",
    icons_enabled = true,
    section_separators = "",
    component_separators = "",
    disabled_filetypes = {
      statusline = {
        "help",
        "startify",
        "dashboard",
        "neo-tree",
        "packer",
        "neogitstatus",
        "NvimTree",
        "Trouble",
        "alpha",
        "lir",
        "Outline",
        "spectre_panel",
        "toggleterm",
        "qf",
      },
      winbar = {},
    },
  },
  sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = {
      -- "filename",
      {
        "filetype",
        icon_only = true,
        separator = "",
        padding = {
          left = 1,
          right = 0,
        },
      },
      {
        "filename",
        path = 1,
        symbols = {
          modified = "  ",
          readonly = "",
          unnamed = "",
        },
      },
      { "diagnostics", sources = { "nvim_lsp" }, symbols = { error = " ", warn = " ", info = " " } },
      { "diff" },
      { "searchcount" },
    },
    lualine_x = { { "b:gitsigns_head", icon = "" } },
    lualine_y = { "progress" },
    lualine_z = {
      progress
      -- function()
      --   return " " .. os.date("%R")
      -- end,
    },
  },
  inactive_sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = { "filename" },
    lualine_x = { "location" },
    lualine_y = {},
    lualine_z = {},
  },
  tabline = {},
  extensions = { "neo-tree", "lazy" },
}
