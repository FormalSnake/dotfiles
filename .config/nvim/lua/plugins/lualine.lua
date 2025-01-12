---@param opts? {relative: "cwd"|"root", modified_hl: string?}
local function lualine_pretty_path(opts)
  opts = vim.tbl_extend('force', {
    relative = 'cwd',
    modified_hl = 'Comment',
  }, opts or {})

  return function(self)
    local path = vim.fn.expand '%:p' --[[@as string]]

    if path == '' then
      return ''
    end
    local root = Util.root.get { normalize = true }
    local cwd = Util.root.cwd()

    if opts.relative == 'cwd' and path:find(cwd, 1, true) == 1 then
      path = path:sub(#cwd + 2)
    else
      path = path:sub(#root + 2)
    end

    local sep = package.config:sub(1, 1)
    local parts = vim.split(path, '[\\/]')
    if #parts > 6 then
      parts = { parts[1], parts[2], parts[3], parts[4], '…', parts[#parts - 1], parts[#parts] }
    end

    if opts.modified_hl and vim.bo.modified then
      parts[#parts] = Util.lualine.format(self, parts[#parts], opts.modified_hl)
    end

    return table.concat(parts, sep)
  end
end
return {
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function(_, opts)
      local function xcodebuild_device()
        if vim.g.xcodebuild_platform == 'macOS' then
          return ' macOS'
        end
        if vim.g.xcodebuild_os then
          return ' ' .. vim.g.xcodebuild_device_name .. ' (' .. vim.g.xcodebuild_os .. ')'
        end
        return ' ' .. vim.g.xcodebuild_device_name
      end

      -- filename.ext \\\ line:col
      local function inactive_statusline()
        local width = vim.fn.winwidth(0)
        local filename = vim.fn.expand '%:t'
        local position = string.format('%d:%d', vim.fn.line '.', vim.fn.col '.')
        local backslash_count = width - #filename - #position - 4
        local backslashes = string.rep('\\', backslash_count)

        return string.format('%s %s %s', filename, backslashes, position)
      end

      local function short(str)
        local modes = {
          ['NORMAL'] = 'NOR',
          ['INSERT'] = 'INS',
          ['VISUAL'] = 'VIS',
          ['V-LINE'] = 'V-L',
          ['V-BLOCK'] = 'V-B',
          ['REPLACE'] = 'REP',
          ['COMMAND'] = 'CMD',
          ['TERMINAL'] = 'TER',
          ['EX'] = 'EX',
          ['SELECT'] = 'SEL',
          ['S-LINE'] = 'S-L',
          ['S-BLOCK'] = 'S-B',
          ['OPERATOR'] = 'OPE',
          ['MORE'] = 'MOR',
          ['CONFIRM'] = 'CON',
          ['SHELL'] = 'SHL',
          ['MULTICHAR'] = 'MCH',
          ['PROMPT'] = 'PRT',
          ['BLOCK'] = 'BLK',
          ['FUNCTION'] = 'FUN',
        }
        return modes[str] or str
      end

      local git_blame = require('gitblame')

      local function getWordsV2()
        local wc = vim.fn.wordcount()
        if wc["visual_words"] then -- text is selected in visual mode
          return wc["visual_words"] .. " Words/" .. wc['visual_chars'] .. " Chars (Vis)"
        else                       -- all of the document
          return wc["words"] .. " Words"
        end
      end

      require('lualine').setup {
        options = {
          icons_enabled = true,
          theme = 'mellow',
          disabled_filetypes = { 'NvimTree' },
          always_divide_middle = true,
          globalstatus = false,
          component_separators = { left = '', right = '' },
          section_separators = { left = '', right = '' },
        },
        sections = {
          lualine_a = {
            { 'mode', separator = { left = '', right = '' }, fmt = short }
          },
          lualine_c = { { git_blame.get_current_blame_text, cond = git_blame.is_blame_text_available }, lualine_pretty_path() },
          lualine_z = { { 'location', separator = { left = '', right = '' } }, getWordsV2 },
          lualine_x = {
            { "' ' .. vim.g.xcodebuild_last_status", color = { fg = '#a6e3a1' } },
            { xcodebuild_device, color = { fg = '#f9e2af', bg = '#161622' } },
            'encoding',
            { 'g:metals_status' },
          }
        },
        inactive_sections = {
          lualine_a = {},
          lualine_b = {},
          lualine_c = { inactive_statusline },
          lualine_x = {},
          lualine_y = {},
          lualine_z = {},
        },
        extensions = { 'nvim-dap-ui', 'quickfix', 'trouble', 'neo-tree', 'lazy', 'mason' },
        tabline = {},
        winbar = {},
        inactive_winbar = {},
        ignore_focus = {},
      }
    end
  }
}
