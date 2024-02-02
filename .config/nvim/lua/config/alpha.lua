local alpha = require("alpha")
local dashboard = require("alpha.themes.dashboard")

-- Set header
dashboard.section.header.val = {
  "           ▄ ▄                   ",
  "       ▄   ▄▄▄     ▄ ▄▄▄ ▄ ▄     ",
  "       █ ▄ █▄█ ▄▄▄ █ █▄█ █ █     ",
  "    ▄▄ █▄█▄▄▄█ █▄█▄█▄▄█▄▄█ █     ",
  "  ▄ █▄▄█ ▄ ▄▄ ▄█ ▄▄▄▄▄▄▄▄▄▄▄▄▄▄  ",
  "  █▄▄▄▄ ▄▄▄ █ ▄ ▄▄▄ ▄ ▄▄▄ ▄ ▄ █ ▄",
  "▄ █ █▄█ █▄█ █ █ █▄█ █ █▄█ ▄▄▄ █ █",
  "█▄█ ▄ █▄▄█▄▄█ █ ▄▄█ █ ▄ █ █▄█▄█ █",
  "    █▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄█ █▄█▄▄▄█    ",
}

-- Set menu
dashboard.section.buttons.val = {
  dashboard.button("enter", "󰈚  Restore Session", ":SessionRestore<cr>"),
  dashboard.button("e", "  New file", ":ene <BAR> startinsert <CR>"),
  dashboard.button("f", "  Find File", ":Telescope find_files<CR>"),
  dashboard.button("r", "󰈚  Recent Files", ":Telescope oldfiles<CR>"),
  dashboard.button("s", "  Settings", ":e $MYVIMRC | :cd %:p:h | split . | wincmd k | pwd<CR>"),
  dashboard.button("q", "󰗼  Quit NVIM", ":qa<CR>"),
}

local fortune = require("alpha.fortune")
dashboard.section.footer.val = fortune()
dashboard.section.footer.opts.hl = '@alpha.footer'
table.insert(dashboard.config.layout, 5, {
  type = 'padding',
  val = 1,
})
-- Send config to alpha
alpha.setup(dashboard.opts)

-- Disable folding on alpha buffer
vim.cmd([[
    autocmd FileType alpha setlocal nofoldenable
]])
-- require("alpha").setup(dashboard.opts)
-- vim.api.nvim_create_autocmd("User", {
--   callback = function()
--     local stats = require("lazy").stats()
--     local ms = math.floor(stats.startuptime * 100) / 100
--     dashboard.section.footer.val = "󱐌 Lazy-loaded "
--         .. stats.loaded
--         .. "/"
--         .. stats.count
--         .. " plugins in "
--         .. ms
--         .. "ms"
--     pcall(vim.cmd.AlphaRedraw)
--   end,
-- })
