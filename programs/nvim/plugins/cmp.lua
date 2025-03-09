-- local cmp = require('cmp')
-- local luasnip = require('luasnip')

-- require('luasnip.loaders.from_vscode').lazy_load()
-- luasnip.config.setup {}

-- cmp.setup {
--     snippet = {
--         expand = function(args)
--             luasnip.lsp_expand(args.body)
--         end,
--     },
--     mapping = cmp.mapping.preset.insert {
--         ['<C-n>'] = cmp.mapping.select_next_item(),
--         ['<C-p>'] = cmp.mapping.select_prev_item(),
--         ['<C-d>'] = cmp.mapping.scroll_docs(-4),
--         ['<C-f>'] = cmp.mapping.scroll_docs(4),
--         ['<C-Space>'] = cmp.mapping.complete {},
--         ['<CR>'] = cmp.mapping.confirm {
--             behavior = cmp.ConfirmBehavior.Replace,
--             select = true,
--         },
--         ['<Tab>'] = cmp.mapping(function(fallback)
--             if cmp.visible() then
--                 cmp.select_next_item()
--             elseif luasnip.expand_or_locally_jumpable() then
--                 luasnip.expand_or_jump()
--             else
--                 fallback()
--             end
--         end, { 'i', 's' }),
--         ['<S-Tab>'] = cmp.mapping(function(fallback)
--             if cmp.visible() then
--                 cmp.select_prev_item()
--             elseif luasnip.locally_jumpable(-1) then
--                 luasnip.jump(-1)
--             else
--                 fallback()
--             end
--         end, { 'i', 's' }),
--     },
--     sources = {
--         { name = "supermaven",     priority = 69 },
--         { name = 'nvim_lsp' },
--         { name = 'luasnip' },
--         { name = 'render-markdown' },
--         { name = 'buffer' },
--     },
-- }
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
