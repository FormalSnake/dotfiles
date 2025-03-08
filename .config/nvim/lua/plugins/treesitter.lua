return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      local configs = require("nvim-treesitter.configs")

      configs.setup({
        ensure_installed = { "c", "astro", "typescript", "lua", "vim", "vimdoc", "query", "elixir", "heex", "javascript", "html" },
        sync_install = false,
        auto_install = true,
        highlight = { enable = true },
        indent = { enable = true },
      })
    end
  },
  {
    "bezhermoso/tree-sitter-ghostty",
    build = "make nvim_install",
  },
  {
    "isak102/ghostty.nvim",
    config = function()
      require("ghostty").setup()
    end,
  }
}
