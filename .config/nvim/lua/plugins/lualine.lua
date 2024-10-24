return {
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      local git_blame = require('gitblame')

      local function getWordsV2()
        local wc = vim.fn.wordcount()
        if wc["visual_words"] then -- text is selected in visual mode
          return wc["visual_words"] .. " Words/" .. wc['visual_chars'] .. " Chars (Vis)"
        else                 -- all of the document
          return wc["words"] .. " Words"
        end
      end

      require('lualine').setup {
        extensions = { 'neo-tree' },
        options = {
          icons_enabled = true,
          theme = 'auto',
        },
        sections = {
          lualine_a = {
            {
              "filename",
              path = 1
            }
          },
          lualine_c = { { git_blame.get_current_blame_text, cond = git_blame.is_blame_text_available } },
          lualine_z = { 'location', getWordsV2 }
        },
      }
    end
  }
}
