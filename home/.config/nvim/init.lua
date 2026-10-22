
vim.g.loaded_node_provider=0;vim.g.loaded_perl_provider=0;vim.g.loaded_ruby_provider=0;vim.g.loaded_python3_provider=0
-- Plugins come from vim.pack at the revisions in nvim-pack-lock.json, parsers from
-- nvim-treesitter's own installer; language servers come from the system.

-- astro-ls needs a TypeScript SDK and a project without node_modules has none: take the one
-- from the typescript pkg, whose tsc links to <pkg>/package/bin/tsc.
local tsc = vim.fn.exepath("tsc")
if tsc ~= "" then
  vim.g.tsdk = vim.fs.dirname(vim.fs.dirname(vim.fn.resolve(tsc))) .. "/lib"
end
-- rust-analyzer's std sources, from the distro's rust-src, unless the toolchain points elsewhere.
local rust_src = "/usr/lib/rustlib/src/rust/library"
if not vim.env.RUST_SRC_PATH and vim.uv.fs_stat(rust_src) then
  vim.env.RUST_SRC_PATH = rust_src
end

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

vim.filetype.add({
  pattern = {
    [".*/docker%-compose[^/]*%.ya?ml"] = "yaml.docker-compose",
    [".*/compose[^/]*%.ya?ml"] = "yaml.docker-compose",
  },
})
vim.treesitter.language.register("yaml", "yaml.docker-compose")

-- Options ---------------------------------------------------------------------

local o = vim.opt

-- colors/terminal.lua is built on ANSI indices and relies on this being off.
o.termguicolors = false
vim.cmd.colorscheme("terminal")

o.number = true
o.relativenumber = true
o.signcolumn = "yes"
o.cursorline = true
o.cursorlineopt = "number"
o.laststatus = 3
o.cmdheight = 0
o.showmode = false
o.ruler = false
o.winborder = "rounded"
o.pumborder = "rounded"
o.pumheight = 12
o.scrolloff = 6
o.sidescrolloff = 8
o.smoothscroll = true
o.splitright = true
o.splitbelow = true
o.splitkeep = "screen"
o.wrap = false
o.linebreak = true
o.breakindent = true
o.list = true
o.listchars = { tab = "  ", trail = "·", nbsp = "␣" }
o.fillchars = { eob = " ", fold = " ", foldopen = "\u{f078}", foldclose = "\u{f054}", foldsep = " ", diff = "╱" }
o.foldlevel = 99
o.foldmethod = "expr"
o.foldexpr = "v:lua.vim.treesitter.foldexpr()"
o.foldtext = ""
o.expandtab = true
o.shiftwidth = 2
o.tabstop = 2
o.shiftround = true
o.ignorecase = true
o.smartcase = true
o.inccommand = "split"
o.undofile = true
o.swapfile = false
o.confirm = true
o.mouse = "a"
o.updatetime = 200
o.timeoutlen = 400
o.shortmess:append({ I = true, c = true, W = true })
o.completeopt = { "menu", "menuone", "noselect", "popup" }
o.diffopt:append({ "algorithm:histogram", "indent-heuristic", "linematch:60", "inline:char" })
o.sessionoptions = { "buffers", "curdir", "tabpages", "winsize", "help", "globals", "skiprtp", "folds" }

vim.schedule(function()
  o.clipboard = "unnamedplus"
end)

-- Message and cmdline UI from 0.12 (experimental), the reason cmdheight=0
-- above is usable.
require("vim._core.ui2").enable({})

-- Statusline ------------------------------------------------------------------

function _G.statusline()
  local parts = { " %<%f %m%r" }
  local head = vim.b.gitsigns_head
  if head and head ~= "" then
    parts[#parts + 1] = "%#StatusMuted# " .. head .. "%*"
  end
  parts[#parts + 1] = "%="
  local diag = vim.diagnostic.status()
  if diag ~= "" then
    parts[#parts + 1] = diag .. "  "
  end
  parts[#parts + 1] = "%#StatusMuted#%{&filetype}  %l:%c%* "
  return table.concat(parts, " ")
end
o.statusline = "%!v:lua.statusline()"

-- Diagnostics -----------------------------------------------------------------

local icons = { "\u{f057}", "\u{f071}", "\u{f05a}", "\u{f0eb}" }
vim.diagnostic.config({
  severity_sort = true,
  underline = true,
  update_in_insert = false,
  virtual_text = { spacing = 2, source = "if_many", prefix = "●" },
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = icons[1],
      [vim.diagnostic.severity.WARN] = icons[2],
      [vim.diagnostic.severity.INFO] = icons[3],
      [vim.diagnostic.severity.HINT] = icons[4],
    },
  },
  float = { source = "if_many" },
  jump = {
    on_jump = function(_, bufnr)
      vim.diagnostic.open_float({ bufnr = bufnr, scope = "cursor", focus = false })
    end,
  },
})

-- Plugins ---------------------------------------------------------------------

local gh = function(repo) return "https://github.com/" .. repo end
vim.pack.add({
  gh("folke/snacks.nvim"),
  gh("folke/which-key.nvim"),
  gh("folke/flash.nvim"),
  gh("folke/persistence.nvim"),
  gh("folke/lazydev.nvim"),
  gh("nvim-mini/mini.icons"),
  gh("lewis6991/gitsigns.nvim"),
  -- A release tag, so blink downloads its prebuilt fuzzy matcher instead of building it.
  { src = gh("Saghen/blink.cmp"), version = vim.version.range("1.*") },
  gh("MeanderingProgrammer/render-markdown.nvim"),
  gh("neovim/nvim-lspconfig"),
  { src = gh("nvim-treesitter/nvim-treesitter"), version = "main" },
}, { confirm = false })

require("mini.icons").setup()
MiniIcons.mock_nvim_web_devicons()

require("snacks").setup({
  bigfile = { enabled = true },
  quickfile = { enabled = true },
  input = { enabled = true },
  notifier = { enabled = true, style = "minimal" },
  words = { enabled = true },
  statuscolumn = { enabled = true },
  indent = { indent = { enabled = false }, scope = { enabled = true, char = "│" }, animate = { enabled = false } },
  explorer = { enabled = true, replace_netrw = true },
  picker = {
    enabled = true,
    layout = { preset = "telescope" },
    sources = {
      explorer = { layout = { preset = "sidebar", preview = false, layout = { width = 32 } } },
    },
  },
  image = { enabled = true, doc = { inline = false, float = true } },
})

-- Snacks draws inline images with unicode placeholders whose image id rides in
-- a truecolor foreground, which termguicolors=false cannot express. Direct
-- placement works without it.
for _, env in ipairs(Snacks.image.terminal.envs()) do
  env.placeholders = false
end

require("which-key").setup({
  preset = "helix",
  icons = { mappings = false },
  spec = {
    { "<leader>b", group = "buffer" },
    { "<leader>c", group = "code" },
    { "<leader>f", group = "find" },
    { "<leader>g", group = "git" },
    { "<leader>q", group = "session" },
    { "<leader>s", group = "search" },
    { "<leader>u", group = "toggle" },
  },
})

require("flash").setup({ modes = { search = { enabled = false } } })

require("persistence").setup()

require("lazydev").setup({
  library = {
    { path = "${3rd}/luv/library", words = { "vim%.uv" } },
    { path = "snacks.nvim", words = { "Snacks" } },
  },
})

require("gitsigns").setup({
  signs = {
    add = { text = "▎" },
    change = { text = "▎" },
    delete = { text = "▁" },
    topdelete = { text = "▔" },
    changedelete = { text = "▎" },
    untracked = { text = "▎" },
  },
  signs_staged = {
    add = { text = "▎" },
    change = { text = "▎" },
    delete = { text = "▁" },
    topdelete = { text = "▔" },
    changedelete = { text = "▎" },
  },
})

require("render-markdown").setup({
  file_types = { "markdown" },
  completions = { blink = { enabled = true } },
  heading = { sign = false, position = "inline", icons = { "󰉫 ", "󰉬 ", "󰉭 ", "󰉮 ", "󰉯 ", "󰉰 " } },
  code = { sign = false, border = "thin", width = "block", left_pad = 1, right_pad = 1 },
  bullet = { icons = { "•", "◦", "▪", "▫" } },
  pipe_table = { style = "normal" },
})

require("blink.cmp").setup({
  keymap = { preset = "enter" },
  appearance = { nerd_font_variant = "mono" },
  completion = {
    accept = { auto_brackets = { enabled = true } },
    documentation = { auto_show = true, auto_show_delay_ms = 200 },
    ghost_text = { enabled = true },
    menu = {
      draw = {
        treesitter = { "lsp" },
        columns = { { "kind_icon" }, { "label", "label_description", gap = 1 } },
      },
    },
  },
  signature = { enabled = true },
  sources = {
    default = { "lazydev", "lsp", "path", "snippets", "buffer" },
    providers = {
      lazydev = { name = "LazyDev", module = "lazydev.integrations.blink", score_offset = 100 },
    },
  },
  cmdline = { enabled = true, completion = { menu = { auto_show = true } } },
  fuzzy = { implementation = "prefer_rust" },
})

-- Treesitter ------------------------------------------------------------------

-- install() skips parsers already present, so after the first run this costs a
-- directory listing. It compiles with tree-sitter and a C compiler.
vim.schedule(function() require("nvim-treesitter").install("all") end)

-- nvim-treesitter's main branch only ships parsers and queries; starting the
-- highlighter and indent is left to the user.
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("kyan.treesitter", {}),
  callback = function(ev)
    if pcall(vim.treesitter.start, ev.buf) then
      vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end
  end,
})

-- LSP -------------------------------------------------------------------------

-- Server definitions come from nvim-lspconfig's lsp/ directory; only overrides
-- live here.
vim.lsp.config("lua_ls", {
  settings = { Lua = { workspace = { checkThirdParty = false }, hint = { enable = true } } },
})

-- nil asks "Some flake inputs are not available. Fetch them now?" on every
-- cold open of a flake whose inputs are not all in the store. Never fetch,
-- never ask.
vim.lsp.config("nil_ls", {
  settings = {
    ["nil"] = {
      formatting = { command = { "nixfmt" } },
      nix = { flake = { autoArchive = false, autoEvalInputs = false } },
    },
  },
})

vim.lsp.config("vtsls", {
  settings = {
    vtsls = { autoUseWorkspaceTsdk = true, experimental = { completion = { enableServerSideFuzzyMatch = true } } },
    typescript = {
      updateImportsOnFileMove = { enabled = "always" },
      inlayHints = { parameterNames = { enabled = "literals" }, variableTypes = { enabled = false } },
    },
  },
})

-- lspconfig's default list includes markdown, which attaches it to every
-- README in a repo with a package.json.
vim.lsp.config("tailwindcss", {
  filetypes = vim.tbl_filter(function(ft)
    return not ft:find("markdown") and ft ~= "mdx"
  end, vim.lsp.config.tailwindcss.filetypes),
})

vim.lsp.config("astro", {
  before_init = function(_, config)
    local tsdk = require("lspconfig.util").get_typescript_server_path(config.root_dir)
    config.init_options.typescript.tsdk = tsdk ~= "" and tsdk or vim.g.tsdk
  end,
})

vim.lsp.config("sourcekit", { filetypes = { "swift", "objc", "objcpp" } })

-- sourcekit-lsp comes from Xcode, so it is only enabled where that exists.
local servers = {
  "lua_ls",
  "nil_ls",
  "vtsls",
  "eslint",
  "tailwindcss",
  "astro",
  "html",
  "cssls",
  "jsonls",
  "yamlls",
  "taplo",
  "marksman",
  "dockerls",
  "docker_compose_language_service",
  "gopls",
  "rust_analyzer",
}
if vim.fn.executable("xcrun") == 1 then
  servers[#servers + 1] = "sourcekit"
end
vim.lsp.enable(servers)

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("kyan.lsp", {}),
  callback = function(ev)
    local client = assert(vim.lsp.get_client_by_id(ev.data.client_id))
    if client:supports_method("textDocument/foldingRange") then
      vim.wo[0][0].foldexpr = "v:lua.vim.lsp.foldexpr()"
    end
  end,
})

-- Keymaps ---------------------------------------------------------------------

local map = vim.keymap.set
local P = Snacks.picker

-- Built-in since 0.11 and left as is: K hover, grn rename, gra code action,
-- grr references, gri implementation, grt type definition, gO symbols,
-- [d ]d diagnostics, <C-w>d diagnostic float, an/in selection ranges.
map("n", "<leader><space>", function() P.smart() end, { desc = "Find files" })
map("n", "<leader>/", function() P.grep() end, { desc = "Grep" })
map("n", "<leader>,", function() P.buffers() end, { desc = "Buffers" })
map("n", "<leader>e", function() Snacks.explorer() end, { desc = "File tree" })
map("n", "<leader>ff", function() P.files() end, { desc = "Files" })
map("n", "<leader>fr", function() P.recent() end, { desc = "Recent" })
map("n", "<leader>fc", function() P.files({ cwd = vim.fn.stdpath("config") }) end, { desc = "Config files" })
map({ "n", "x" }, "<leader>sw", function() P.grep_word() end, { desc = "Word under cursor" })
map("n", "<leader>sd", function() P.diagnostics() end, { desc = "Diagnostics" })
map("n", "<leader>ss", function() P.lsp_symbols() end, { desc = "Symbols" })
map("n", "<leader>sS", function() P.lsp_workspace_symbols() end, { desc = "Workspace symbols" })
map("n", "<leader>sh", function() P.help() end, { desc = "Help" })
map("n", "<leader>sk", function() P.keymaps() end, { desc = "Keymaps" })
map("n", "<leader>sr", function() P.resume() end, { desc = "Resume" })
map("n", "<leader>n", function() Snacks.notifier.show_history() end, { desc = "Notifications" })

map("n", "gd", function() P.lsp_definitions() end, { desc = "Definition" })
map("n", "gD", function() P.lsp_declarations() end, { desc = "Declaration" })
map("n", "gy", function() P.lsp_type_definitions() end, { desc = "Type definition" })
map({ "n", "x" }, "<leader>cf", function() vim.lsp.buf.format() end, { desc = "Format" })
map("n", "]]", function() Snacks.words.jump(vim.v.count1) end, { desc = "Next reference" })
map("n", "[[", function() Snacks.words.jump(-vim.v.count1) end, { desc = "Previous reference" })

map("n", "<leader>gg", function() Snacks.lazygit() end, { desc = "Lazygit" })
map("n", "<leader>gs", function() P.git_status() end, { desc = "Status" })
map("n", "<leader>gd", function() P.git_diff() end, { desc = "Diff hunks" })
map("n", "<leader>gl", function() P.git_log() end, { desc = "Log" })
map("n", "<leader>gf", function() P.git_log_file() end, { desc = "File history" })
map("n", "<leader>gb", function() require("gitsigns").blame_line({ full = true }) end, { desc = "Blame line" })
map("n", "<leader>gp", function() require("gitsigns").preview_hunk_inline() end, { desc = "Preview hunk" })
map("n", "<leader>gr", function() require("gitsigns").reset_hunk() end, { desc = "Reset hunk" })
map("n", "<leader>gS", function() require("gitsigns").stage_hunk() end, { desc = "Stage hunk" })
map({ "n", "x" }, "<leader>go", function() Snacks.gitbrowse() end, { desc = "Open on remote" })
map("n", "]h", function() require("gitsigns").nav_hunk("next") end, { desc = "Next hunk" })
map("n", "[h", function() require("gitsigns").nav_hunk("prev") end, { desc = "Previous hunk" })

map({ "n", "x", "o" }, "s", function() require("flash").jump() end, { desc = "Flash" })
map({ "n", "x", "o" }, "S", function() require("flash").treesitter() end, { desc = "Flash treesitter" })

map("n", "<leader>bd", function() Snacks.bufdelete() end, { desc = "Delete buffer" })
map("n", "<leader>bo", function() Snacks.bufdelete.other() end, { desc = "Delete other buffers" })
map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
map("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next buffer" })
-- Ctrl-h/j/k/l walk nvim splits and continue into the neighbouring tmux or
-- herdr pane at the edge. tmux.conf sends the keys back to nvim when it is
-- the foreground process; herdr has no such hook, so its own pane focus stays
-- on its prefix bindings.
local function navigate(wincmd, tmux, herdr)
  return function()
    local win = vim.api.nvim_get_current_win()
    vim.cmd.wincmd(wincmd)
    if vim.api.nvim_get_current_win() ~= win then
      return
    end
    if vim.env.TMUX then
      vim.system({ "tmux", "select-pane", "-" .. tmux })
    elseif vim.env.HERDR_ENV == "1" then
      vim.system({ "herdr", "pane", "focus", "--direction", herdr, "--current" })
    end
  end
end
map("n", "<C-h>", navigate("h", "L", "left"), { desc = "Window left" })
map("n", "<C-j>", navigate("j", "D", "down"), { desc = "Window down" })
map("n", "<C-k>", navigate("k", "U", "up"), { desc = "Window up" })
map("n", "<C-l>", navigate("l", "R", "right"), { desc = "Window right" })

map("n", "<esc>", "<cmd>nohlsearch<cr><esc>")

map("n", "<leader>qs", function() require("persistence").load() end, { desc = "Restore session" })
map("n", "<leader>qq", "<cmd>qa<cr>", { desc = "Quit all" })

Snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>uw")
Snacks.toggle.option("relativenumber", { name = "Relative number" }):map("<leader>ur")
Snacks.toggle.diagnostics():map("<leader>ud")
Snacks.toggle.inlay_hints():map("<leader>uh")
Snacks.toggle({
  name = "Markdown render",
  get = function() return require("render-markdown").get() end,
  set = function(on) require("render-markdown").set(on) end,
}):map("<leader>um")

-- Autocmds --------------------------------------------------------------------

local group = vim.api.nvim_create_augroup("kyan", {})

vim.api.nvim_create_autocmd("TextYankPost", {
  group = group,
  callback = function() vim.hl.on_yank() end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = { "markdown", "text", "gitcommit" },
  callback = function()
    vim.wo[0][0].wrap = true
    vim.wo[0][0].spell = false
  end,
})

-- Bare `nvim` in a project picks up where the last session there left off.
vim.api.nvim_create_autocmd("VimEnter", {
  group = group,
  nested = true,
  callback = function()
    if vim.fn.argc(-1) == 0 and not vim.g.started_with_stdin then
      require("persistence").load()
    end
  end,
})
vim.api.nvim_create_autocmd("StdinReadPre", {
  group = group,
  callback = function() vim.g.started_with_stdin = true end,
})
