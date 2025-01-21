return {
  -- {
  --   'uZer/pywal16.nvim',
  --   -- for local dev replace with:
  --   -- dir = '~/your/path/pywal16.nvim',
  --   config = function()
  --     vim.cmd.colorscheme("pywal16")
  --   end,
  -- }
  -- {
  --   "mellow-theme/mellow.nvim",
  --   lazy = false,
  --   priority = 1000,
  --   config = function()
  --     vim.g.mellow_transparent = true
  --     vim.cmd([[colorscheme mellow]])
  --   end,
  -- },
  {
    "wtfox/jellybeans.nvim",
    priority = 1000,
    config = function()
      require("jellybeans").setup({
        transparent = true,
        on_highlights = function(hl, c)
          -- flat ui for snacks picker
          local prompt = c.mine_shaft
          hl.SnacksPickerBorder = {
            fg = c.background,
            bg = c.background,
          }
          hl.SnacksPickerInput = {
            fg = c.foreground,
            bg = prompt,
          }
          hl.SnacksPickerInputBorder = {
            fg = prompt,
            bg = prompt,
          }
          hl.SnacksPickerBoxBorder = {
            fg = prompt,
            bg = prompt,
          }
          hl.SnacksPickerBoxTitle = {
            fg = prompt,
            bg = c.koromiko,
          }
          hl.SnacksPickerTitle = {
            fg = c.foreground,
            bg = prompt,
          }
          hl.SnacksPickerList = {
            bg = prompt,
          }
          hl.SnacksPickerPrompt = {
            fg = c.koromiko,
            bg = prompt,
          }
          hl.SnacksPickerPreviewTitle = {
            fg = c.background,
            bg = c.biloba_flower,
          }
          hl.SnacksPickerFlag = {
            bg = c.koromiko,
            fg = c.ripe_plum,
          }
        end,
      })
      vim.cmd.colorscheme("jellybeans")
    end,
  }
}
