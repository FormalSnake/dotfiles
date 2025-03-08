      local configs = require("nvim-treesitter.configs")

      configs.setup({
        ensure_installed = {  },
        auto_install = false,
        highlight = { enable = true },
        indent = { enable = true },
      })
