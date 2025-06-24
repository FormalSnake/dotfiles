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
      return lspkindFormat(entry, item)
    end,
  },
})
