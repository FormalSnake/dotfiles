local cp = require("catppuccin")

cp.setup({
	flavour = "mocha", -- latte, frappe, macchiato, mocha
	background = { -- :h background
		light = "latte",
		dark = "mocha",
	},
	transparent_background = false, -- disables setting the background color.
	show_end_of_buffer = false, -- shows the '~' characters after the end of buffers
	term_colors = true,      -- sets terminal colors (e.g. `g:terminal_color_0`)
	dim_inactive = {
		enabled = false, -- dims the background color of inactive window
		shade = "dark",
		percentage = 0.15, -- percentage of the shade to apply to the inactive window
	},
	no_italic = false,       -- Force no italic
	no_bold = false,         -- Force no bold
	no_underline = false,    -- Force no underline
	styles = {               -- Handles the styles of general hi groups (see `:h highlight-args`):
		comments = { "italic" }, -- Change the style of comments
		conditionals = { "italic" },
		loops = {},
		functions = {},
		keywords = {},
		strings = {},
		variables = {},
		numbers = {},
		booleans = {},
		properties = {},
		types = {},
		operators = {},
	},

	color_overrides = {},
	custom_highlights = function(colors)
		return {
			-- 		-- Identifier (like keyword require)
			-- 		['@function.builtin'] = { fg = colors.flamingo },
			--
			--
			--
			--
			-- 		-- Cmp Menu
			-- 		-- Pmenu = { bg = colors.mantle },
			-- 		-- PmenuSel = { fg = colors.mantle, bg = colors.maroon, style = { 'bold' } },
			-- 		-- Pmenu = { bg = colors.base },
			PmenuSel = { fg = colors.base, bg = "#B3E1A8", style = { 'bold' } },
			--
			-- 		-- Cmp Item Kind
			-- 		-- CmpItemKindSnippet = { fg = colors.base, bg = colors.mauve },
			-- 		-- CmpItemKindKeyword = { fg = colors.base, bg = colors.red },
			-- 		-- CmpItemKindText = { fg = colors.base, bg = colors.teal },
			-- 		-- CmpItemKindMethod = { fg = colors.base, bg = colors.blue },
			-- 		-- CmpItemKindConstructor = { fg = colors.base, bg = colors.blue },
			-- 		-- CmpItemKindFunction = { fg = colors.base, bg = colors.blue },
			-- 		-- CmpItemKindFolder = { fg = colors.base, bg = colors.blue },
			-- 		-- CmpItemKindModule = { fg = colors.base, bg = colors.blue },
			-- 		-- CmpItemKindConstant = { fg = colors.base, bg = colors.peach },
			-- 		-- CmpItemKindField = { fg = colors.base, bg = colors.green },
			-- 		-- CmpItemKindProperty = { fg = colors.base, bg = colors.green },
			-- 		-- CmpItemKindEnum = { fg = colors.base, bg = colors.green },
			-- 		-- CmpItemKindUnit = { fg = colors.base, bg = colors.green },
			-- 		-- CmpItemKindClass = { fg = colors.base, bg = colors.yellow },
			-- 		-- CmpItemKindVariable = { fg = colors.base, bg = colors.flamingo },
			-- 		-- CmpItemKindFile = { fg = colors.base, bg = colors.blue },
			-- 		-- CmpItemKindInterface = { fg = colors.base, bg = colors.yellow },
			-- 		-- CmpItemKindColor = { fg = colors.base, bg = colors.red },
			-- 		-- CmpItemKindReference = { fg = colors.base, bg = colors.red },
			-- 		-- CmpItemKindEnumMember = { fg = colors.base, bg = colors.red },
			-- 		-- CmpItemKindStruct = { fg = colors.base, bg = colors.blue },
			-- 		-- CmpItemKindValue = { fg = colors.base, bg = colors.peach },
			-- 		-- CmpItemKindEvent = { fg = colors.base, bg = colors.blue },
			-- 		-- CmpItemKindOperator = { fg = colors.base, bg = colors.blue },
			-- 		-- CmpItemKindTypeParameter = { fg = colors.base, bg = colors.blue },
			-- 		-- CmpItemKindCopilot = { fg = colors.base, bg = colors.teal },
			CmpDocBorder = { fg = "#454759" },
			--
			--
			-- 		-- Telescope
			-- 		TelescopeBorder = { fg = colors.blue },
			-- 		TelescopeSelectionCaret = { fg = colors.flamingo },
			-- 		-- TelescopeSelection = { fg = colors.text, bg = colors.surface0, style = { 'bold' } },
			-- 		-- TelescopeMatching = { fg = colors.blue },
			-- 		-- TelescopePromptPrefix = { fg = colors.yellow, bg = colors.crust },
			-- 		-- TelescopePromptNormal = { bg = colors.crust },
			-- 		-- TelescopeResultsNormal = { bg = colors.mantle },
			-- 		-- TelescopePreviewNormal = { bg = colors.crust },
			-- 		-- TelescopePromptBorder = { bg = colors.crust, fg = colors.crust },
			-- 		-- TelescopeResultsBorder = { bg = colors.mantle, fg = colors.mantle },
			-- 		-- TelescopePreviewBorder = { bg = colors.crust, fg = colors.crust },
			-- 		-- TelescopePromptTitle = { fg = colors.crust, bg = colors.mauve },
			-- 		-- TelescopeResultsTitle = { fg = colors.crust, bg = colors.mauve },
			-- 		-- TelescopePreviewTitle = { fg = colors.crust, bg = colors.mauve },
			--
			-- 		TelescopeMatching = { fg = colors.flamingo },
			-- 		TelescopeSelection = { fg = colors.text, bg = colors.surface0, bold = true },
			--
			-- 		TelescopePromptPrefix = { bg = colors.surface0 },
			-- 		TelescopePromptNormal = { bg = colors.surface0 },
			-- 		TelescopeResultsNormal = { bg = colors.mantle },
			-- 		TelescopePreviewNormal = { bg = colors.mantle },
			-- 		TelescopePromptBorder = { bg = colors.surface0, fg = colors.surface0 },
			-- 		TelescopeResultsBorder = { bg = colors.mantle, fg = colors.mantle },
			-- 		TelescopePreviewBorder = { bg = colors.mantle, fg = colors.mantle },
			-- 		TelescopePromptTitle = { bg = colors.pink, fg = colors.mantle },
			-- 		TelescopeResultsTitle = { fg = colors.mantle },
			-- 		TelescopePreviewTitle = { bg = colors.green, fg = colors.mantle },
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
	integrations = {
		cmp = true,
		gitsigns = true,
		nvimtree = true,
		treesitter = true,
		notify = true,
		mini = true,
		telescope = {
			enabled = true,
			style = "nvchad"
		},
		native_lsp = {
			enabled = true,
			virtual_text = {
				errors = { "italic" },
				hints = { "italic" },
				warnings = { "italic" },
				information = { "italic" },
			},
			underlines = {
				errors = { "underline" },
				hints = { "underline" },
				warnings = { "underline" },
				information = { "underline" },
			},
			inlay_hints = {
				background = true,
			},
		},
		indent_blankline = {
			enabled = true,
			colored_indent_levels = true,
		},

		-- For more plugins integrations please scroll down (https://github.com/catppuccin/nvim#integrations)
	},
})


-- setup must be called before loading
vim.cmd.colorscheme "catppuccin"
