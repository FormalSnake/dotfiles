vim.o.foldcolumn = '1'
vim.o.foldlevel = 99
vim.o.foldlevelstart = 99
vim.o.foldenable = true

-- Custom fold text function
local function customFoldText()
    local line = vim.fn.getline(vim.v.foldstart)
    local line_count = vim.v.foldend - vim.v.foldstart + 1
    return " ⚡ " .. line .. " ... " .. line_count .. " lines "
end

vim.opt.foldtext = 'v:lua.customFoldText()'
_G.customFoldText = customFoldText

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.textDocument.foldingRange = {
    dynamicRegistration = false,
    lineFoldingOnly = true
}

local language_servers = require("lspconfig").util.available_servers()
for _, ls in ipairs(language_servers) do
    require('lspconfig')[ls].setup({
        capabilities = capabilities
    })
end

require('ufo').setup({
    provider_selector = function(bufnr, filetype, buftype)
        return {'treesitter', 'indent'}
    end,
    open_fold_hl_timeout = 150,
    close_fold_kinds_for_ft = {
        default = {'imports', 'comment'},
        json = {'array'},
        c = {'comment', 'region'}
    },
    preview = {
        win_config = {
            border = {'', '─', '', '', '', '─', '', ''},
            winhighlight = 'Normal:Folded',
            winblend = 0
        },
        mappings = {
            scrollU = '<C-u>',
            scrollD = '<C-d>',
            jumpTop = '[',
            jumpBot = ']'
        }
    },
    fold_virt_text_handler = function(virtText, lnum, endLnum, width, truncate)
        local newVirtText = {}
        local suffix = (' 󰁂 %d '):format(endLnum - lnum)
        local sufWidth = vim.fn.strdisplaywidth(suffix)
        local targetWidth = width - sufWidth
        local curWidth = 0
        for _, chunk in ipairs(virtText) do
            local chunkText = chunk[1]
            local chunkWidth = vim.fn.strdisplaywidth(chunkText)
            if targetWidth > curWidth + chunkWidth then
                table.insert(newVirtText, chunk)
            else
                chunkText = truncate(chunkText, targetWidth - curWidth)
                local hlGroup = chunk[2]
                table.insert(newVirtText, {chunkText, hlGroup})
                chunkWidth = vim.fn.strdisplaywidth(chunkText)
                if curWidth + chunkWidth < targetWidth then
                    suffix = suffix .. (' '):rep(targetWidth - curWidth - chunkWidth)
                end
                break
            end
            curWidth = curWidth + chunkWidth
        end
        table.insert(newVirtText, {suffix, 'MoreMsg'})
        return newVirtText
    end
})

-- Keymaps
local wk = require("which-key")
wk.add({
  { "zR", function() require('ufo').openAllFolds() end, desc = "Open all folds" },
  { "zM", function() require('ufo').closeAllFolds() end, desc = "Close all folds" },
  { "zr", function() require('ufo').openFoldsExceptKinds() end, desc = "Fold less" },
  { "zm", function() require('ufo').closeFoldsWith() end, desc = "Fold more" },
  { "zp", function() require('ufo').peekFoldedLinesUnderCursor() end, desc = "Peek fold" },
})

-- Option to use pretty foldtext when ufo is not used
vim.keymap.set('n', 'zK', function()
    local winid = require('ufo').peekFoldedLinesUnderCursor()
    if not winid then
        vim.lsp.buf.hover()
    end
end, { desc = "Peek Fold" })