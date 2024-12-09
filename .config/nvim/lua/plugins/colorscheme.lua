return {
  { -- Color scheme
    -- 'Mofiqul/vscode.nvim',
    'Mofiqul/vscode.nvim',
    lazy = false,
    config = function()
      local bg1, bg2 = 'NONE', '#141414'
      local vscode = require 'vscode'
      local c = require('vscode.colors').get_colors()

      local color_overrides = {
        lualineBg = bg1,
        lualineBg2 = bg1,
        vscLeftMid = bg1,
        vscDiffRedDark = '#2B0D0D',
        vscDiffRedLight = '#400B0B',
        vscDiffRedLightLight = '#910101',
        vscDiffGreenDark = '#202317',
        vscDiffGreenLight = '#2B311C',
      }

      local modes = { 'normal', 'visual', 'inactive', 'replace', 'insert', 'terminal', 'command' }
      local lualine_overrides = {}
      for _, mode in ipairs(modes) do
        lualine_overrides[mode] = {
          b = { fg = c.vscPink, bg = bg1 },
          c = { bg = bg1 },
        }
      end

      local group_overrides = {
        -- Basic UI elements
        DevIcon = { fg = 'NONE', bg = 'NONE' },
        VertSplit = { fg = c.vscSplitDark, bg = bg1 },
        WinBar = { bg = bg1, fg = bg1 },
        WinBarNC = { bg = bg1, fg = bg1 },
        Normal = { fg = c.vscFront, bg = bg1 },
        NormalNC = { fg = c.vscFront, bg = bg1 },
        NormalFloat = { bg = bg1 },
        -- SignColumn = { bg = bg1 },
        Delimiter = { fg = '#444444', bg = bg1 },

        -- Noice cmdline
        NoiceCmdlinePrompt = { fg = c.vscFront, bg = c.vscPink },
        NoiceCmdlineNormal = { fg = 'NONE', bg = bg2 },
        NoiceCmdlinePopupBorder = { fg = bg2, bg = bg2 },
        NoiceCmdlinePopupTitle = { fg = c.vscFront, bg = c.vscPink },

        -- Telescope
        TelescopeNormal = { fg = 'NONE', bg = bg2 },
        TelescopeBorder = { fg = bg2, bg = bg2 },
        TelescopePromptBorder = { fg = c.vscLeftMid, bg = c.vscLeftMid },
        TelescopePromptNormal = { fg = c.vscFront, bg = c.vscLeftMid },
        TelescopePromptCounter = { fg = c.vscPopupFront, bg = c.vscLeftMid },
        TelescopePromptPrefix = { fg = c.vscPink, bg = c.vscLeftMid },
        TelescopePromptTitle = { fg = c.vscBack, bg = c.vscMediumBlue, bold = true },
        TelescopeResultsBorder = { fg = bg2, bg = bg2 },
        TelescopePreviewBorder = { fg = bg2, bg = bg2 },
        TelescopeResultsTitle = { fg = bg2, bg = bg2, bold = true },
        TelescopePreviewTitle = { fg = c.vscBack, bg = c.vscBlueGreen, bold = true },
        TelescopeSelectionCaret = { fg = c.vscPopupFront, bg = 'NONE' },

        -- quicker.nvim (quickfix)
        QuickFixHeaderHard = { fg = '#444444', bg = bg1 },
        QuickFixHeaderSoft = { fg = '#444444', bg = bg1 },
        QuickFixFilename = { bg = bg1, fg = c.vscBlue },

        -- Line numbers and whitespace
        LineNr = { fg = '#444444', bg = bg1 },
        CursorLineNr = { fg = '#AFAFAF', bg = c.vscCursorDarkDark },
        SignColumn = { fg = 'NONE', bg = 'NONE' },
        Whitespace = { fg = '#404040', bg = 'NONE' },

        -- Syntax
        MiniIndentscopeSymbol = { fg = '#707070', bg = 'NONE' },
        Keyword = { fg = c.vscPink, bg = 'NONE' },
        Directory = { fg = c.vscBlue, bg = c.vscBack },
        Special = { fg = c.vscYellowOrange, bg = 'NONE' },
        Comment = { fg = '#666666', bg = 'NONE' },
        SpecialComment = { fg = '#666666', bg = 'NONE' },
        ['@comment'] = { fg = '#666666', bg = 'NONE' },

        -- Scrollbar
        ScrollbarHandle = { bg = '#262626', fg = 'NONE' },
        ScrollbarCursorHandle = { bg = '#262626', fg = 'NONE' },
        ScrollbarWarn = { bg = 'NONE', fg = '#FFDF88' },
        ScrollbarError = { bg = 'NONE', fg = '#FFBDB7' },
        ScrollbarHint = { bg = 'NONE', fg = '#97DDFF' },
        ScrollbarWarnHandle = { bg = '#262626', fg = '#FFDF88' },
        ScrollbarErrorHandle = { bg = '#262626', fg = '#FFBDB7' },
        ScrollbarHintHandle = { bg = '#262626', fg = '#97DDFF' },
        ScrollbarGitAdd = { bg = 'NONE', fg = bg1 },
        ScrollbarGitChange = { bg = 'NONE', fg = bg1 },
        ScrollbarGitDelete = { bg = 'NONE', fg = bg1 },
        ScrollbarGitAddHandle = { bg = '#262626', fg = '#262626' },
        ScrollbarGitChangeHandle = { bg = '#262626', fg = '#262626' },
        ScrollbarGitDeleteHandle = { bg = '#262626', fg = '#262626' },

        -- Lazygit
        LazyGitFloat = { bg = 'NONE', fg = '#808080' },
        LazyGitBorder = { bg = 'NONE', fg = '#808080' },

        -- Git signs
        GitSignsAdd = { bg = 'NONE', fg = '#2DA042' },
        GitSignsChange = { bg = 'NONE', fg = c.vscBlue },
        GitSignsDelete = { bg = 'NONE', fg = c.vscRed },

        -- NvimTree
        NvimTreeRootFolder = { fg = c.vscFront, bg = 'NONE', bold = true },
        NvimTreeImageFile = { fg = c.vscViolet, bg = 'NONE' },
        NvimTreeEmptyFolderName = { fg = c.vscGray, bg = 'NONE' },
        NvimTreeFolderName = { fg = c.vscFront, bg = 'NONE' },
        NvimTreeSpecialFile = { fg = c.vscPink, bg = 'NONE', underline = true },
        NvimTreeNormal = { fg = c.vscFront, bg = bg1 },
        NvimTreeCursorLine = { fg = 'NONE', bg = '#262626' },
        NvimTreeVertSplit = { fg = c.vscSplitDark, bg = bg1 },
        NvimTreeEndOfBuffer = { fg = bg1 },
        NvimTreeOpenedFolderName = { fg = 'NONE', bg = bg1 },
        NvimTreeGitRenamed = { fg = c.vscGitRenamed, bg = 'NONE' },
        NvimTreeGitIgnored = { fg = c.vscGitIgnored, bg = 'NONE' },
        NvimTreeGitDeleted = { fg = c.vscGitDeleted, bg = 'NONE' },
        NvimTreeGitStaged = { fg = c.vscGitStageModified, bg = 'NONE' },
        NvimTreeGitMerge = { fg = c.vscGitUntracked, bg = 'NONE' },
        NvimTreeGitDirty = { fg = c.vscGitModified, bg = 'NONE' },
        NvimTreeGitNew = { fg = c.vscGitAdded, bg = 'NONE' },

        -- BufferLine
        BufferLineFill = { bg = '#121212' },
        BufferLineIndicatorSelected = { fg = '#606060', bg = 'NONE' },

        -- Diffview
        DiffviewNormal = { fg = c.vscFront, bg = bg1 },
        DiffviewCursorLine = { bg = c.vscCursorDarkDark },
        DiffviewVertSplit = { fg = c.vscSplitDark, bg = bg1 },
        DiffviewStatusLine = { fg = c.vscFront, bg = c.vscLeftDark },
        DiffviewStatusLineNC = { fg = c.vscFrontDark, bg = c.vscLeftDark },
        DiffviewFilePanelTitle = { fg = c.vscLightBlue, bg = 'NONE', bold = true },
        DiffviewFilePanelCounter = { fg = c.vscBlue, bg = 'NONE', bold = true },
        DiffviewFilePanelFileName = { fg = c.vscFront, bg = 'NONE' },
        DiffviewFilePanelPath = { fg = c.vscFrontDark, bg = 'NONE' },
        DiffviewFilePanelInsertions = { fg = c.vscGitAdded, bg = 'NONE' },
        DiffviewFilePanelDeletions = { fg = c.vscGitDeleted, bg = 'NONE' },
        DiffviewStatusAdded = { fg = c.vscGitAdded, bg = bg1 },
        DiffviewStatusUntracked = { fg = c.vscGitAdded, bg = bg1 },
        DiffviewStatusModified = { fg = c.vscGitModified, bg = bg1 },
        DiffviewStatusRenamed = { fg = c.vscGitRenamed, bg = bg1 },
        DiffviewStatusDeleted = { fg = c.vscGitDeleted, bg = bg1 },

        -- oil.nvim
        OilDir = { fg = c.vscBlue, bg = 'NONE' },
        OilDirIcon = { fg = c.vscYellowOrange, bg = 'NONE' },
        OilSocket = { fg = c.vscPink, bg = 'NONE' },
        OilLink = { fg = c.vscPink, bg = 'NONE' },
        OilLinkTarget = { fg = '#666666', bg = 'NONE' },
        OilFile = { fg = c.vscFront, bg = 'NONE' },
        OilCreate = { fg = c.vscGreen, bg = 'NONE' },
        OilDelete = { fg = c.vscRed, bg = 'NONE' },
        OilMove = { fg = c.vscYellow, bg = 'NONE' },
        OilCopy = { fg = c.vscGreen, bg = 'NONE' },
        OilChange = { fg = c.vscYellow, bg = 'NONE' },
        OilRestore = { fg = c.vscYellowOrange, bg = 'NONE' },
        OilPurge = { fg = c.vscRed, bg = 'NONE' },
        OilTrash = { fg = c.vscRed, bg = 'NONE' },
        OilTrashSourcePath = { fg = '#666666', bg = 'NONE' },

        -- OilGitStatus highlights
        OilGitStatusIndexUnmodified = { fg = c.vscFront, bg = 'NONE' },
        OilGitStatusWorkingTreeUnmodified = { fg = c.vscFront, bg = 'NONE' },
        OilGitStatusIndexIgnored = { fg = c.vscGitIgnored, bg = 'NONE' },
        OilGitStatusWorkingTreeIgnored = { fg = c.vscGitIgnored, bg = 'NONE' },
        OilGitStatusIndexUntracked = { fg = c.vscGitUntracked, bg = 'NONE' },
        OilGitStatusWorkingTreeUntracked = { fg = c.vscGitUntracked, bg = 'NONE' },
        OilGitStatusIndexAdded = { fg = '#2DA042', bg = 'NONE' },
        OilGitStatusWorkingTreeAdded = { fg = '#2DA042', bg = 'NONE' },
        OilGitStatusIndexCopied = { fg = '#2DA042', bg = 'NONE' },
        OilGitStatusWorkingTreeCopied = { fg = '#2DA042', bg = 'NONE' },
        OilGitStatusIndexDeleted = { fg = c.vscRed, bg = 'NONE' },
        OilGitStatusWorkingTreeDeleted = { fg = c.vscRed, bg = 'NONE' },
        OilGitStatusIndexModified = { fg = c.vscBlue, bg = 'NONE' },
        OilGitStatusWorkingTreeModified = { fg = c.vscBlue, bg = 'NONE' },
        OilGitStatusIndexRenamed = { fg = c.vscGitRenamed, bg = 'NONE' },
        OilGitStatusWorkingTreeRenamed = { fg = c.vscGitRenamed, bg = 'NONE' },
        OilGitStatusIndexTypeChanged = { fg = c.vscBlue, bg = 'NONE' },
        OilGitStatusWorkingTreeTypeChanged = { fg = c.vscBlue, bg = 'NONE' },
        OilGitStatusIndexUnmerged = { fg = c.vscGitConflicting, bg = 'NONE' },
        OilGitStatusWorkingTreeUnmerged = { fg = c.vscGitConflicting, bg = 'NONE' },

        -- Notify
        NotifyERRORBorder = { fg = c.vscSplitDark },
        NotifyWARNBorder = { fg = c.vscSplitDark },
        NotifyINFOBorder = { fg = c.vscSplitDark },
        NotifyDEBUGBorder = { fg = c.vscSplitDark },
        NotifyTRACEBorder = { fg = c.vscSplitDark },
        NotifyERRORIcon = { fg = c.vscRed },
        NotifyWARNIcon = { fg = c.vscDarkYellow },
        NotifyINFOIcon = { fg = c.vscLightGreen },
        NotifyDEBUGIcon = { fg = c.vscGray },
        NotifyTRACEIcon = { fg = c.vscPink },
        NotifyERRORTitle = { fg = c.vscRed },
        NotifyWARNTitle = { fg = c.vscDarkYellow },
        NotifyINFOTitle = { fg = c.vscLightGreen },
        NotifyDEBUGTitle = { fg = c.vscGray },
        NotifyTRACETitle = { fg = c.vscPink },

        -- nvim-ufo fold virtual text
        UfoSuffixHighlight = { fg = c.vscFront, bg = c.vscFoldBackground },
      }

      vscode.setup {
        disable_nvimtree_bg = true,
        color_overrides = color_overrides,
        group_overrides = group_overrides,
        lualine_overrides = lualine_overrides,
      }
      vim.cmd("colorscheme vscode")
    end,
  },

  -- {
  --   "nyoom-engineering/oxocarbon.nvim",
  --   -- Add in any other configuration;
  --   --   event = foo,
  --   --   config = bar
  --   --   end,
  --   config = function()
  --     vim.opt.background = "dark" -- set this to dark or light
  --     vim.cmd("colorscheme oxocarbon")
  --     vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
  --     -- vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
  --     -- vim.api.nvim_set_hl(0, "NormalNC", { bg = "none" })
  --     -- vim.api.nvim_set_hl(0, "PmenuSel", { fg = "#CB775D", bg = "#CB775D" })
  --     vim.api.nvim_set_hl(0, "Pmenu", { bg = "#181818" })
  --   end,
  -- }
  -- {
  --   "Shatur/neovim-ayu",
  --   lazy = false,
  --   priority = 1000,
  --   config = function()
  --     require('ayu').setup({
  --       mirage = false,  -- Set to `true` to use `mirage` variant instead of `dark` for dark background.
  --       terminal = true, -- Set to `false` to let terminal manage its own colors.
  --       overrides = {
  --         Normal = { bg = "None" },
  --         ColorColumn = { bg = "None" },
  --         SignColumn = { bg = "None" },
  --         Folded = { bg = "None" },
  --         FoldColumn = { bg = "None" },
  --         -- CursorLine = { bg = "None" },
  --         CursorColumn = { bg = "None" },
  --         WhichKeyFloat = { bg = "None" },
  --         VertSplit = { bg = "None" },
  --       },
  --     })
  --     vim.cmd([[colorscheme ayu]])
  --   end,
  -- }
  --   {
  --     "ayu-theme/ayu-vim",
  --     lazy = false, -- load this during startup as your main colorscheme
  --     priority = 1000, -- load this before other plugins
  --     config = function()
  --         vim.opt.termguicolors = true -- enable true colors support
  --         vim.g.ayucolor = "dark" -- set theme variant ("light", "mirage", "dark")
  --         vim.cmd([[colorscheme ayu]]) -- apply the colorscheme
  --     end,
  -- }
}
