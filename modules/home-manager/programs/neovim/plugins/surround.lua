require("nvim-surround").setup({
  keymaps = {
    insert = "<C-g>s",
    insert_line = "<C-g>S",
    normal = "ys",
    normal_cur = "yss",
    normal_line = "yS",
    normal_cur_line = "ySS",
    visual = "S",
    visual_line = "gS",
    delete = "ds",
    change = "cs",
    change_line = "cS",
  },
  surrounds = {
    ["("] = {
      add = { "(", ")" },
      find = function()
        return require("nvim-surround.config").get_selection({ motion = "a(" })
      end,
      delete = "^(.)().-(.)()$",
    },
    [")"] = {
      add = { "( ", " )" },
      find = function()
        return require("nvim-surround.config").get_selection({ motion = "a)" })
      end,
      delete = "^(. ?)().-( ?.)()$",
    },
    ["{"] = {
      add = { "{", "}" },
      find = function()
        return require("nvim-surround.config").get_selection({ motion = "a{" })
      end,
      delete = "^(.)().-(.)()$",
    },
    ["}"] = {
      add = { "{ ", " }" },
      find = function()
        return require("nvim-surround.config").get_selection({ motion = "a}" })
      end,
      delete = "^(. ?)().-( ?.)()$",
    },
    ["<"] = {
      add = { "<", ">" },
      find = function()
        return require("nvim-surround.config").get_selection({ motion = "a<" })
      end,
      delete = "^(.)().-(.)()$",
    },
    [">"] = {
      add = { "< ", " >" },
      find = function()
        return require("nvim-surround.config").get_selection({ motion = "a>" })
      end,
      delete = "^(. ?)().-( ?.)()$",
    },
    ["["] = {
      add = { "[", "]" },
      find = function()
        return require("nvim-surround.config").get_selection({ motion = "a[" })
      end,
      delete = "^(.)().-(.)()$",
    },
    ["]"] = {
      add = { "[ ", " ]" },
      find = function()
        return require("nvim-surround.config").get_selection({ motion = "a]" })
      end,
      delete = "^(. ?)().-( ?.)()$",
    },
    ["'"] = {
      add = { "'", "'" },
      find = function()
        return require("nvim-surround.config").get_selection({ motion = "a'" })
      end,
      delete = "^(.)().-(.)()$",
    },
    ['"'] = {
      add = { '"', '"' },
      find = function()
        return require("nvim-surround.config").get_selection({ motion = 'a"' })
      end,
      delete = "^(.)().-(.)()$",
    },
    ["`"] = {
      add = { "`", "`" },
      find = function()
        return require("nvim-surround.config").get_selection({ motion = "a`" })
      end,
      delete = "^(.)().-(.)()$",
    },
    ["i"] = {
      add = function()
        local left_delimiter = require("nvim-surround.config").get_input("Left delimiter: ")
        local right_delimiter = left_delimiter and require("nvim-surround.config").get_input("Right delimiter: ")
        if right_delimiter then
          return { { left_delimiter }, { right_delimiter } }
        end
      end,
      find = function()
        return require("nvim-surround.config").get_selection({ motion = "ai" })
      end,
      delete = function()
        local left_delimiter = require("nvim-surround.config").get_input("Left delimiter: ")
        if left_delimiter then
          local right_delimiter = require("nvim-surround.config").get_input("Right delimiter: ")
          if right_delimiter then
            return require("nvim-surround.config").get_selections({
              char = left_delimiter,
              pattern = vim.pesc(left_delimiter) .. "(.-)" .. vim.pesc(right_delimiter),
            })
          end
        end
      end,
    },
    ["t"] = {
      add = function()
        local input = require("nvim-surround.config").get_input("Tag: ")
        if input then
          local element = input:match("^<?([%w-]+)")
          local attributes = input:match("^<?[%w-]+%s+(.*)")
          local open = attributes and string.format("<%s %s>", element, attributes) or string.format("<%s>", element)
          local close = string.format("</%s>", element)
          return { { open }, { close } }
        end
      end,
      find = function()
        return require("nvim-surround.config").get_selection({ motion = "at" })
      end,
      delete = "^(<.->)().-(</.->)()$",
      change = {
        target = "^<([%w-]+).->(.-)</[%w-]+>()$",
        replacement = function()
          local input = require("nvim-surround.config").get_input("Tag: ")
          if input then
            local element = input:match("^<?([%w-]+)")
            local attributes = input:match("^<?[%w-]+%s+(.*)")
            local open = attributes and string.format("<%s %s>", element, attributes) or string.format("<%s>", element)
            local close = string.format("</%s>", element)
            return { { open }, { close } }
          end
        end,
      },
    },
    ["f"] = {
      add = function()
        local func_name = require("nvim-surround.config").get_input("Function name: ")
        if func_name then
          return { { func_name .. "(" }, { ")" } }
        end
      end,
      find = function()
        if vim.g.loaded_nvim_treesitter then
          local selection = require("nvim-surround.config").get_selection({
            query = {
              capture = "@call.outer",
              type = "textobjects",
            },
          })
          if selection then
            return selection
          end
        end
        return require("nvim-surround.config").get_selection({ pattern = "[%w_]+%b()" })
      end,
      delete = "^([%w_]+%()().-(%))()$",
    },
  },
  aliases = {
    ["a"] = ">",
    ["b"] = ")",
    ["B"] = "}",
    ["r"] = "]",
    ["q"] = { '"', "'", "`" },
    ["s"] = { "}", "]", ")", ">", '"', "'", "`" },
  },
  highlight = {
    duration = 0,
  },
  move_cursor = "begin",
  indent_lines = function(start, stop)
    local b = vim.bo
    if b.formatexpr ~= "" or b.indentexpr ~= "" then
      vim.cmd(string.format("silent normal! %dG=%dG", start, stop))
    end
  end,
})

-- Additional keymaps for which-key integration
local wk = require("which-key")
wk.add({
  { "ys", desc = "Add surrounding" },
  { "yss", desc = "Add surrounding to line" },
  { "yS", desc = "Add surrounding to line (newlines)" },
  { "ySS", desc = "Add surrounding to line (newlines)" },
  { "ds", desc = "Delete surrounding" },
  { "cs", desc = "Change surrounding" },
  { "cS", desc = "Change surrounding (newlines)" },
  { "S", mode = "v", desc = "Add surrounding" },
  { "gS", mode = "v", desc = "Add surrounding (newlines)" },
})