return {
  -- {
  --   "hrsh7th/cmp-nvim-lsp",
  -- },
  -- {
  --   "hrsh7th/cmp-buffer",
  -- },
  {
    -- "iguanacucumber/magazine.nvim",
    "hrsh7th/nvim-cmp",
    name = "nvim-cmp", -- Otherwise highlighting gets messed up
    -- load cmp on InsertEnter
    event = "InsertEnter",
    -- these dependencies will only be loaded when cmp loads
    -- dependencies are always lazy-loaded unless specified otherwise
    dependencies = {
      -- { "iguanacucumber/mag-nvim-lsp", name = "cmp-nvim-lsp", opts = {} },
      -- { "iguanacucumber/mag-buffer",   name = "cmp-buffer" },
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "onsails/lspkind.nvim",
      "hrsh7th/cmp-path",
      { 'VonHeikemen/lsp-zero.nvim', branch = 'v4.x' },
    },
    config = function()
      local cmp = require("cmp")

      require("luasnip.loaders.from_vscode").lazy_load()

      cmp.setup({
        mapping = cmp.mapping.preset.insert({
          ['<C-b>'] = cmp.mapping.scroll_docs(-4),
          ['<C-f>'] = cmp.mapping.scroll_docs(4),
          ['<C-o>'] = cmp.mapping.complete(),
          ['<C-e>'] = cmp.mapping.abort(),
          ['<CR>'] = cmp.mapping.confirm({ select = true }),
        }),
        snippet = {
          expand = function(args)
            require('luasnip').lsp_expand(args.body)
          end,
        },
        sources = cmp.config.sources({
          { name = 'nvim_lsp' },
          { name = 'luasnip' },
          -- { name = "supermaven" },
        }, {
          { name = 'buffer' },
        }),
        -- Icons and stuff
        window = {
          completion = {
            winhighlight = "Normal:Pmenu,FloatBorder:Pmenu,Search:None",
            col_offset = -3,
            side_padding = 0,
          },
        },
        formatting = {
          fields = { "kind", "abbr", "menu" },
          format = function(entry, vim_item)
            local kind = require("lspkind").cmp_format({ mode = "symbol_text", maxwidth = 50 })(entry, vim_item)
            local strings = vim.split(kind.kind, "%s", { trimempty = true })
            kind.kind = " " .. (strings[1] or "") .. " "
            kind.menu = "    (" .. (strings[2] or "") .. ")"

            return kind
          end,
        },
      })

      -- Customization for Pmenu
      -- vim.api.nvim_set_hl(0, "PmenuSel", { bg = "#282C34", fg = "NONE" })
      -- vim.api.nvim_set_hl(0, "Pmenu", { fg = "#C5CDD9", bg = "#22252A" })
      --
      -- vim.api.nvim_set_hl(0, "CmpItemAbbrDeprecated", { fg = "#7E8294", bg = "NONE", strikethrough = true })
      -- vim.api.nvim_set_hl(0, "CmpItemAbbrMatch", { fg = "#82AAFF", bg = "NONE", bold = true })
      -- vim.api.nvim_set_hl(0, "CmpItemAbbrMatchFuzzy", { fg = "#82AAFF", bg = "NONE", bold = true })
      -- vim.api.nvim_set_hl(0, "CmpItemMenu", { fg = "#C792EA", bg = "NONE", italic = true })
      --
      -- vim.api.nvim_set_hl(0, "CmpItemKindField", { fg = "#EED8DA", bg = "#B5585F" })
      -- vim.api.nvim_set_hl(0, "CmpItemKindProperty", { fg = "#EED8DA", bg = "#B5585F" })
      -- vim.api.nvim_set_hl(0, "CmpItemKindEvent", { fg = "#EED8DA", bg = "#B5585F" })
      --
      -- vim.api.nvim_set_hl(0, "CmpItemKindText", { fg = "#C3E88D", bg = "#9FBD73" })
      -- vim.api.nvim_set_hl(0, "CmpItemKindEnum", { fg = "#C3E88D", bg = "#9FBD73" })
      -- vim.api.nvim_set_hl(0, "CmpItemKindKeyword", { fg = "#C3E88D", bg = "#9FBD73" })
      --
      -- vim.api.nvim_set_hl(0, "CmpItemKindConstant", { fg = "#FFE082", bg = "#D4BB6C" })
      -- vim.api.nvim_set_hl(0, "CmpItemKindConstructor", { fg = "#FFE082", bg = "#D4BB6C" })
      -- vim.api.nvim_set_hl(0, "CmpItemKindReference", { fg = "#FFE082", bg = "#D4BB6C" })
      --
      -- vim.api.nvim_set_hl(0, "CmpItemKindFunction", { fg = "#EADFF0", bg = "#A377BF" })
      -- vim.api.nvim_set_hl(0, "CmpItemKindStruct", { fg = "#EADFF0", bg = "#A377BF" })
      -- vim.api.nvim_set_hl(0, "CmpItemKindClass", { fg = "#EADFF0", bg = "#A377BF" })
      -- vim.api.nvim_set_hl(0, "CmpItemKindModule", { fg = "#EADFF0", bg = "#A377BF" })
      -- vim.api.nvim_set_hl(0, "CmpItemKindOperator", { fg = "#EADFF0", bg = "#A377BF" })
      --
      -- vim.api.nvim_set_hl(0, "CmpItemKindVariable", { fg = "#C5CDD9", bg = "#7E8294" })
      -- vim.api.nvim_set_hl(0, "CmpItemKindFile", { fg = "#C5CDD9", bg = "#7E8294" })
      --
      -- vim.api.nvim_set_hl(0, "CmpItemKindUnit", { fg = "#F5EBD9", bg = "#D4A959" })
      -- vim.api.nvim_set_hl(0, "CmpItemKindSnippet", { fg = "#F5EBD9", bg = "#D4A959" })
      -- vim.api.nvim_set_hl(0, "CmpItemKindFolder", { fg = "#F5EBD9", bg = "#D4A959" })
      --
      -- vim.api.nvim_set_hl(0, "CmpItemKindMethod", { fg = "#DDE5F5", bg = "#6C8ED4" })
      -- vim.api.nvim_set_hl(0, "CmpItemKindValue", { fg = "#DDE5F5", bg = "#6C8ED4" })
      -- vim.api.nvim_set_hl(0, "CmpItemKindEnumMember", { fg = "#DDE5F5", bg = "#6C8ED4" })
      --
      -- vim.api.nvim_set_hl(0, "CmpItemKindInterface", { fg = "#D8EEEB", bg = "#58B5A8" })
      -- vim.api.nvim_set_hl(0, "CmpItemKindColor", { fg = "#D8EEEB", bg = "#58B5A8" })
      -- vim.api.nvim_set_hl(0, "CmpItemKindTypeParameter", { fg = "#D8EEEB", bg = "#58B5A8" })


      -- vim.cmd [[autocmd BufWritePre <buffer> lua vim.lsp.buf.format()]]
      -- vim.cmd [[autocmd BufWritePre * lua vim.lsp.buf.format()]]
    end,
  },
}
