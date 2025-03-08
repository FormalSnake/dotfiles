return {
  {
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
      local twc = require("cmp-tailwind-colors")
      twc.setup({
        format = function(itemColor)
          return { fg = itemColor, bg = nil, text = nil }
        end,
      })

      local lspkindFormat = require("lspkind").cmp_format({
        mode = "symbol_text",
        maxwidth = 50,
        symbol_map = { Supermaven = "" },
      })

      local cmp = require("cmp")

      require("luasnip.loaders.from_vscode").lazy_load()

      cmp.setup({
        mapping = cmp.mapping.preset.insert({
          ['<C-b>'] = cmp.mapping.scroll_docs(-4),
          ['<C-f>'] = cmp.mapping.scroll_docs(4),
          ['<C-o>'] = cmp.mapping.complete(),
          ['<C-e>'] = cmp.mapping.abort(),
          ['<tab>'] = cmp.mapping.confirm({ select = true }),
        }),
        snippet = {
          expand = function(args)
            require('luasnip').lsp_expand(args.body)
          end,
        },
        sources = cmp.config.sources({
          { name = "supermaven",     priority = 69 },
          { name = 'nvim_lsp' },
          { name = 'luasnip' },
          { name = 'render-markdown' },
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
          format = function(entry, item)
            item = twc.format(entry, item)
            return lspkindFormat(entry, item)
          end,
          -- format = function(entry, vim_item)
          --   local kind = require("lspkind").cmp_format({ mode = "symbol_text", maxwidth = 50, symbol_map = { Supermaven = "" } })(
          --     entry, vim_item)
          --   local strings = vim.split(kind.kind, "%s", { trimempty = true })
          --   kind.kind = " " .. (strings[1] or "") .. " "
          --   kind.menu = "    (" .. (strings[2] or "") .. ")"
          --
          --   return kind
          -- end,
        },
      })
    end,
  },
}
