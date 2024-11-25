return {
  {
    "nyoom-engineering/oxocarbon.nvim",
    -- Add in any other configuration;
    --   event = foo,
    --   config = bar
    --   end,
    config = function()
      vim.cmd([[colorscheme oxocarbon]])
      vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
      -- vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
      -- vim.api.nvim_set_hl(0, "NormalNC", { bg = "none" })
    end,
  }
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
