      local configs = require("nvim-treesitter.configs")

      configs.setup({
        ensure_installed = { "c", "astro", "typescript", "lua", "vim", "vimdoc", "query", "elixir", "heex", "javascript", "html" },
        auto_install = false,
        highlight = { enable = true },
        indent = { enable = true },
      })
