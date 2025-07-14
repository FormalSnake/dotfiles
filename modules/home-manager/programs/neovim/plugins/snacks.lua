require("snacks").setup({
  zen = {
    enabled = true,
  },
  input = {
    enabled = true,
  },
  scroll = {
    enabled = true,
  },
  image = {
    enabled = true,
  },
  picker = {
    enabled = true,
    -- your picker configuration comes here
    -- or leave it empty to use the default settings
    -- refer to the configuration section below
  },
  indent = {
    enabled = true,
  },
  explorer = {
    enabled = true,
    replace_netrw = true,
  },
  bigfile = { enabled = true },
  dim = { enabled = true },
  dashboard = {
    enabled = true,
    sections = {
      {
        section = "terminal",
        cmd = [[
    chafa (find (test -n "$XDG_CONFIG_HOME"; and echo $XDG_CONFIG_HOME; or echo $HOME/.config/nix/)"/walls/" -name "*.png" | sort -R | head -1) \
    --format symbols --symbols vhalf --size 60x17 --stretch; sleep .1
  ]],
        height = 17,
        padding = 1,
      },
      {
        pane = 2,
        { section = "keys", gap = 1, padding = 1 },
      },
    },
  },
  notifier = {
    enabled = true,
    timeout = 3000,
  },
  quickfile = { enabled = true },
  statuscolumn = { enabled = true },
  words = { enabled = true },
  styles = {
    notification = {
      wo = { wrap = true }, -- Wrap notifications
    },
  },
})


-- Initialization code (set up globals and toggle mappings)
_G.dd = function(...)
  Snacks.debug.inspect(...)
end
_G.bt = function()
  Snacks.debug.backtrace()
end
vim.print = _G.dd -- Override print to use Snacks for `:=` command

Snacks.toggle.option("spell", { name = "Spelling" }):map("<leader>us")
Snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>uw")
Snacks.toggle.option("relativenumber", { name = "Relative Number" }):map("<leader>uL")
Snacks.toggle.diagnostics():map("<leader>ud")
Snacks.toggle.line_number():map("<leader>ul")
Snacks.toggle.option("conceallevel", { off = 0, on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2 }):map(
  "<leader>uc")
Snacks.toggle.treesitter():map("<leader>uT")
Snacks.toggle.option("background", { off = "light", on = "dark", name = "Dark Background" }):map("<leader>ub")
Snacks.toggle.inlay_hints():map("<leader>uh")
