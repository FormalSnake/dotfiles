return {
  {
    'Mofiqul/vscode.nvim',
    lazy = false,
    priority = 1000,
    config = function()
      vim.o.background = 'dark'

      local c = require('vscode.colors').get_colors()

      require('vscode').setup({
        -- Alternatively set style in setup
        -- style = 'light'

        -- Enable transparent background
        transparent = true,

        -- Enable italic comment
        italic_comments = true,

        -- Underline `@markup.link.*` variants
        underline_links = true,

        -- Disable nvim-tree background color
        disable_nvimtree_bg = true,

        -- Override colors (see ./lua/vscode/colors.lua)
        color_overrides = {
          vscLineNumber = '#5a5a5a',
        },

        -- Override highlight groups (see ./lua/vscode/theme.lua)
        group_overrides = {
          -- Change the color of the empty line symbols (`~`)
          EndOfBuffer     = { fg = '#5a5a5a' },
          -- this supports the same val table as vim.api.nvim_set_hl
          -- use colors from this colorscheme by requiring vscode.colors!
          Cursor          = { fg = c.vscDarkBlue, bg = c.vscLightGreen, bold = true },
          CursorLine      = { bg = '#2E2E2E' },
          -- Override LSP Diagnostic Colors
          DiagnosticError = { fg = '#D16969', bg = '#1e1e1e' }, -- light red
          DiagnosticWarn  = { fg = '#D7BA7D', bg = '#1e1e1e' }, -- light yellow
          DiagnosticInfo  = { fg = '#9CDCFE', bg = '#1e1e1e' }, -- light blue
          DiagnosticHint  = { fg = '#9CDCFE', bg = '#1e1e1e' }, -- light green
          -- Floating window customization
          NormalFloat     = { bg = '#1F1F1F' },
          FloatBorder     = { fg = '', bg = '#1F1F1F' },
          -- Vim mode theme
          ModeMsg         = { fg = '#FFFFFF', bg = '#1F1F1F', bold = true },
          -- Customize fold color
          Folded          = { fg = '#B2B2B2', bg = '#333333', italic = true },
        }
      })

      require('vscode').load()
    end
  }
}
