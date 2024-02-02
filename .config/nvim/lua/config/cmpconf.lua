local has_words_before = function()
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
end
vim.api.nvim_set_hl(0, "CmpGhostText", { link = "Comment", default = true })
local cmp = require "cmp"
local defaults = require("cmp.config.default")()
local lspkind = require("lspkind")



require("luasnip.loaders.from_vscode").lazy_load()


-- local formatting_style = {
--   -- default fields order i.e completion word + item.kind + item.kind icons
--   fields = { "abbr", "kind", "menu" },
--   format = require('tailwindcss-colorizer-cmp').formatter,
-- }


-- local function border(hl_name)
--   return {
--     { "╭", hl_name },
--     { "─", hl_name },
--     { "╮", hl_name },
--     { "│", hl_name },
--     { "╯", hl_name },
--     { "─", hl_name },
--     { "╰", hl_name },
--     { "│", hl_name },
--   }
-- end
lspkind.init({
  preset = "codicons",
  symbol_map = {
    Text = "",
    Method = "",
    Function = "",
    Constructor = "",
    Field = "",
    Variable = "",
    Class = "",
    Interface = "",
    Module = "",
    Property = "",
    Unit = "",
    Value = "",
    Enum = "",
    Keyword = "",
    Snippet = "",
    Color = "",
    File = "",
    Reference = "",
    Folder = "",
    EnumMember = "",
    Constant = "",
    Struct = "",
    Event = "",
    Operator = "",
    TypeParameter = "",
    cmp_tabnine = "",
  },
})

local source_mapping = {
  buffer = "(Buffer)",
  nvim_lsp = "(LSP)",
  nvim_lua = "(Lua)",
  cmp_tabnine = "(TN)",
  path = "(Path)",
  luasnip = "(SN)",
}

local options = {
  preselect = cmp.PreselectMode.None,
  completion = {
    completeopt = "menu,menuone,noinsert",
  },

  window = {
    completion = {
      --border = { "┌", "─", "┐", "│", "┘", "─", "└", "│" },
      border = { "╭", " ", "╮", "│", "╯", " ", "╰", "│" },
      --border = { "┌", " ", "┐", "│", "┘", " ", "└", "│" },
      winhighlight = "Normal:CmpPmenu,CursorLine:PmenuSel,Search:PmenuSel,FloatBorder:FloatBorder",
    },
    documentation = {
      max_width = 50,
      --border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
      border = { "┌", " ", "┐", "│", "┘", " ", "└", "│" },
      winhighlight = "Normal:CmpPmenu,FloatBorder:FloatBorder,CursorLine:PmenuSel,Search:None",
    },
  },
  -- window = {
  --   completion = {
  --     side_padding = 0,
  --     winhighlight = "Normal:CmpPmenu,CursorLine:PmenuSel,Search:PmenuSel",
  --     scrollbar = true,
  --     border = border "CmpDocBorder",
  --   },
  --   documentation = {
  --     border = border "CmpDocBorder",
  --     winhighlight = "Normal:CmpDoc",
  --   },
  -- },
  snippet = {
    expand = function(args)
      require("luasnip").lsp_expand(args.body)
    end,
  },


  -- formatting = formatting_style,
  formatting = {
    fields = { "kind", "abbr", "menu" },
    -- format = kind.cmp_format {
    --  with_text = false,
    --  maxwidth = 80,
    -- },
    format = function(entry, vim_item)
      vim_item.kind = lspkind.symbolic(vim_item.kind, { mode = "symbol" })
      vim_item.menu = source_mapping[entry.source.name]
      if entry.source.name == "cmp_tabnine" then
        vim_item.kind = ""
        -- show  score
        -- local detail = (entry.completion_item.data or {}).detail
        -- if detail and detail:find('.*%%.*') then
        --  vim_item.kind = vim_item.kind .. ' ' .. detail
        -- end

        if (entry.completion_item.data or {}).multiline then
          vim_item.kind = vim_item.kind .. " " .. "[ML]"
        end
      end
      local maxwidth = 40
      vim_item.abbr = string.sub(vim_item.abbr, 1, maxwidth)
      return vim_item
    end,
  },
  mapping = {
    ["<C-p>"] = cmp.mapping.select_prev_item(),
    ["<C-n>"] = cmp.mapping.select_next_item(),
    ["<C-d>"] = cmp.mapping.scroll_docs(-4),
    ["<C-f>"] = cmp.mapping.scroll_docs(4),
    ["<C-Space>"] = cmp.mapping.complete(),
    ["<C-e>"] = cmp.mapping.close(),
    ["<CR>"] = cmp.mapping.confirm {
      behavior = cmp.ConfirmBehavior.Insert,
      select = true,
    },
    ["<Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      elseif require("luasnip").expand_or_jumpable() then
        vim.fn.feedkeys(
          vim.api.nvim_replace_termcodes("<Plug>luasnip-expand-or-jump", true, true, true),
          "")
      else
        fallback()
      end
    end, {
      "i",
      "s",
    }),
    ["<S-Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      elseif require("luasnip").jumpable(-1) then
        vim.fn.feedkeys(
          vim.api.nvim_replace_termcodes("<Plug>luasnip-jump-prev", true, true, true), "")
      else
        fallback()
      end
    end, {
      "i",
      "s",
    }),
  },

  sources = cmp.config.sources({
    { name = "nvim_lsp", priority = 8 },
    { name = "crates" },
    -- { name = "neorg", priority = 10 },
    -- {name = "nvim_lsp_signature_help"},
    { name = "luasnip",  priority = 8 },
    { name = "nvim_lua" },
    { name = "buffer",   priority = 7 },
    { name = "path",     priority = 4 },
    { name = "calc" },
    --{ name = "cmp_tabnine", priority = 8 },
    -- {name = "digraphs"},
    { name = "spell" },
  }, {
    { name = "buffer" },
  }),
  experimental = {
    ghost_text = {
      hl_group = "CmpGhostText",
    },
  },
  sorting = {
    comparators = {
      cmp.config.compare.score,
      cmp.config.compare.exact,
      cmp.config.compare.locality,
      cmp.config.compare.recently_used,
      cmp.config.compare.order,
      cmp.config.compare.offset,
      cmp.config.compare.kind,
      cmp.config.compare.sort_text,
      --cmp.config.compare.length,
    },
  },
}
require("cmp").setup(options)

--- HACK: Override `vim.lsp.util.stylize_markdown` to use Treesitter.
---@param bufnr integer
---@param contents string[]
---@param opts table
---@return string[]
---@diagnostic disable-next-line: duplicate-set-field
vim.lsp.util.stylize_markdown = function(bufnr, contents, opts)
  contents = vim.lsp.util._normalize_markdown(contents, {
    width = vim.lsp.util._make_floating_popup_size(contents, opts),
  })
  vim.bo[bufnr].filetype = 'markdown'
  vim.treesitter.start(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, contents)

  return contents
end
