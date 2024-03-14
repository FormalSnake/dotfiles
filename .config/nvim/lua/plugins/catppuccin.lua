return {
  "catppuccin/nvim",
  lazy = true,
  name = "catppuccin",
  enabled = true,
  opts = {
    transparent_background = true,
    no_italic = true,
    no_bold = false,
    integrations = {
      harpoon = true,
      fidget = true,
      cmp = true,
      flash = true,
      gitsigns = true,
      illuminate = true,
      indent_blankline = { enabled = true },
      lsp_trouble = true,
      mason = true,
      mini = true,
      native_lsp = {
        enabled = true,
        underlines = {
          errors = { "undercurl" },
          hints = { "undercurl" },
          warnings = { "undercurl" },
          information = { "undercurl" },
        },
      },
      navic = { enabled = true, custom_bg = "lualine" },
      neotest = true,
      noice = true,
      notify = true,
      neotree = true,
      semantic_tokens = true,
      telescope = {
        enabled = true,
        style = "nvchad",
      },
      treesitter = true,
      which_key = true,
    },
    highlight_overrides = {
      all = function(colors)
        return {
          DiagnosticVirtualTextError = { bg = colors.none },
          DiagnosticVirtualTextWarn = { bg = colors.none },
          DiagnosticVirtualTextHint = { bg = colors.none },
          DiagnosticVirtualTextInfo = { bg = colors.none },
        }
      end,
    },
    custom_highlights = function(colors)
      return {
        -- 		-- Identifier (like keyword require)
        -- 		['@function.builtin'] = { fg = colors.flamingo },
        --
        --
        --
        --
        -- 		-- Cmp Menu
        -- Pmenu = { bg = colors.mantle },
        -- PmenuSel = { fg = colors.mantle, bg = colors.maroon, style = { 'bold' } },
        -- Pmenu = { bg = colors.base },
        PmenuSel = { fg = colors.base, bg = "#B3E1A8", style = { "bold" } },
        --
        -- 		-- Cmp Item Kind
        -- CmpItemKindSnippet = { fg = colors.base, bg = colors.mauve },
        -- CmpItemKindKeyword = { fg = colors.base, bg = colors.red },
        -- CmpItemKindText = { fg = colors.base, bg = colors.teal },
        -- CmpItemKindMethod = { fg = colors.base, bg = colors.blue },
        -- CmpItemKindConstructor = { fg = colors.base, bg = colors.blue },
        -- CmpItemKindFunction = { fg = colors.base, bg = colors.blue },
        -- CmpItemKindFolder = { fg = colors.base, bg = colors.blue },
        -- CmpItemKindModule = { fg = colors.base, bg = colors.blue },
        -- CmpItemKindConstant = { fg = colors.base, bg = colors.peach },
        -- CmpItemKindField = { fg = colors.base, bg = colors.green },
        -- CmpItemKindProperty = { fg = colors.base, bg = colors.green },
        -- CmpItemKindEnum = { fg = colors.base, bg = colors.green },
        -- CmpItemKindUnit = { fg = colors.base, bg = colors.green },
        -- CmpItemKindClass = { fg = colors.base, bg = colors.yellow },
        -- CmpItemKindVariable = { fg = colors.base, bg = colors.flamingo },
        -- CmpItemKindFile = { fg = colors.base, bg = colors.blue },
        -- CmpItemKindInterface = { fg = colors.base, bg = colors.yellow },
        -- CmpItemKindColor = { fg = colors.base, bg = colors.red },
        -- CmpItemKindReference = { fg = colors.base, bg = colors.red },
        -- CmpItemKindEnumMember = { fg = colors.base, bg = colors.red },
        -- CmpItemKindStruct = { fg = colors.base, bg = colors.blue },
        -- CmpItemKindValue = { fg = colors.base, bg = colors.peach },
        -- CmpItemKindEvent = { fg = colors.base, bg = colors.blue },
        -- CmpItemKindOperator = { fg = colors.base, bg = colors.blue },
        -- CmpItemKindTypeParameter = { fg = colors.base, bg = colors.blue },
        -- CmpItemKindCopilot = { fg = colors.base, bg = colors.teal },
        CmpDocBorder = { fg = "#454759" },
        --
        --
        -- 		-- Telescope
        TelescopeBorder = { fg = colors.blue },
        TelescopeSelectionCaret = { fg = colors.flamingo },
        -- TelescopeSelection = { fg = colors.text, bg = colors.surface0, style = { 'bold' } },
        -- TelescopeMatching = { fg = colors.blue },
        -- TelescopePromptPrefix = { fg = colors.yellow, bg = colors.crust },
        -- TelescopePromptNormal = { bg = colors.crust },
        -- TelescopeResultsNormal = { bg = colors.mantle },
        -- TelescopePreviewNormal = { bg = colors.crust },
        -- TelescopePromptBorder = { bg = colors.crust, fg = colors.crust },
        -- TelescopeResultsBorder = { bg = colors.mantle, fg = colors.mantle },
        -- TelescopePreviewBorder = { bg = colors.crust, fg = colors.crust },
        -- TelescopePromptTitle = { fg = colors.crust, bg = colors.mauve },
        -- TelescopeResultsTitle = { fg = colors.crust, bg = colors.mauve },
        -- TelescopePreviewTitle = { fg = colors.crust, bg = colors.mauve },

        TelescopeMatching = { fg = colors.flamingo },
        TelescopeSelection = { fg = colors.text, bg = colors.surface0, bold = true },

        TelescopePromptPrefix = { bg = colors.surface0 },
        TelescopePromptNormal = { bg = colors.surface0 },
        TelescopeResultsNormal = { bg = colors.mantle },
        TelescopePreviewNormal = { bg = colors.mantle },
        TelescopePromptBorder = { bg = colors.surface0, fg = colors.surface0 },
        TelescopeResultsBorder = { bg = colors.mantle, fg = colors.mantle },
        TelescopePreviewBorder = { bg = colors.mantle, fg = colors.mantle },
        TelescopePromptTitle = { bg = colors.pink, fg = colors.mantle },
        TelescopeResultsTitle = { fg = colors.mantle },
        TelescopePreviewTitle = { bg = colors.green, fg = colors.mantle },
        --
        -- 		-- Bufferline
        -- 		BufferLineIndicatorSelected = { fg = colors.pink },
        -- 		BufferLineIndicator = { fg = colors.base },
        -- 		BufferLineModifiedSelected = { fg = colors.teal },
        -- 		TabLineSel = { bg = colors.pink },
        --
        -- 		-- Cursorline & Linenumbers
        --
        -- 		CursorLine = { bg = colors.mantle },
        --
        -- 		-- Folds
        -- 		-- Folded = { bg = colors.base },
        --
        -- 		-- Match Parenthesis
        -- 		-- MatchParen = { style = { 'underline' } },
        -- 		MatchParen = { bg = colors.none },
        -- 		-- MatchParen = { fg = colors.base, bg = colors.red },
        -- 		-- MatchParen = { fg = colors.base, bg = ucolors.darken(colors.red, 0.65, mocha.rosewater) },
        --
        -- 		-- Inlay hints
        -- 		-- LspInlayHint = { bg = colors.mantle },
        --
        -- 		-- Visual Mode
        -- 		Visual = { style = { 'bold' } },
      }
    end,
    -- color_overrides = {
    --   mocha = {
    --     -- I don't think these colours are pastel enough by default!
    --     peach = "#fcc6a7",
    --     green = "#d2fac5",
    --   },
    -- },
  },
}
