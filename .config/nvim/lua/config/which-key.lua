local status_ok, which_key = pcall(require, "which-key")
if not status_ok then
  return
end

local discipline = require('config.custom.discipline')
discipline.cowboy()


local setup = {
  plugins = {
    marks = true,
    registers = true,
    spelling = {
      enabled = true,
      suggestions = 20,
    },
    presets = {
      operators = false,
      motions = false,
      text_objects = false,
      windows = true,
      nav = true,
      z = true,
      g = true,
    },
  },
  key_labels = {
  },
  icons = {
    breadcrumb = "»",
    separator = "➜",
    group = "+",
  },
  popup_mappings = {
    scroll_down = "<c-d>",
    scroll_up = "<c-u>",
  },
  window = {
    border = "rounded",
    position = "bottom",
    margin = { 1, 0, 1, 0 },
    padding = { 2, 2, 2, 2 },
    winblend = 0,
  },
  layout = {
    height = { min = 4, max = 25 },
    width = { min = 20, max = 50 },
    spacing = 3,
    align = "left",
  },
  ignore_missing = true,
  hidden = { "<silent>", "<cmd>", "<Cmd>", "<CR>", "call", "lua", "^:", "^ " },
  show_help = true,
  triggers = "auto",
  triggers_blacklist = {
    i = { "j", "k" },
    v = { "j", "k" },
  },
}

local mappings = {
  ["t"] = {
    name = "Tab Actions",
    t = { "<cmd>:tabe<cr>", "New tab" },
    h = { "<cmd>:tabprevious<cr>", "Previous" },
    l = { "<cmd>:tabnext<cr>", "Next" },
    c = { "<cmd>:tabc<cr>", "Close" },
  },

  ["T"] = {
    name = "TreeSitter",
    s = { "<cmd>:TSToggle hightlight<cr>", "Toggle hightlight" }
  },
  C = {
    name = "CCC AKA Color tools",
    p = { "<cmd>CccPick<cr>", "Color picker" }
  },
  ["r"] = { "<cmd>lua require'spectre'.open_file_search({select_word=true})<cr>", "Find/Replace Document" },
  ["R"] = { "<cmd>lua require'spectre'.open_visual({select_word=true})<cr>", "Find/Replace Project" },
  -- ["b"] = {
  -- 	"<cmd>lua require('telescope.builtin').buffers({ sort_mru = true, sort_lastused = true, ignore_current_buffer = true })<cr>",
  -- 	"Buffers"
  -- },
  ["B"] = {
    name = "Buffer Actions",
    a = {
      "<cmd>lua require('telescope.builtin').buffers({ sort_lastused = true, ignore_current_buffer = true })<cr>",
      "All Buffers",
    },
    b = { "<cmd>:edit #<cr>", "Alternate buffer" },
    h = { "<cmd>:bprevious<cr>", "Previous" },
    l = { "<cmd>:bnext<cr>", "Next" },
    -- h = { "<cmd>BufferLineCyclePrev<cr>", "Previous" },
    -- l = { "<cmd>BufferLineCycleNext<cr>", "Next" },
    -- H = { "<cmd>BufferLineMovePrev<cr>", "Move Previous" },
    -- L = { "<cmd>BufferLineMoveNext<cr>", "Move Next" },
    -- p = { "<cmd>BufferLinePick<cr>", "Pick" },
    -- o = { "<cmd>BufferLineSortByExtension<cr>", "Order Number" },
    -- O = { "<cmd>BufferLineSortByDirectory<cr>", "Order Directory" },
    c = { "<cmd>Bdelete!<cr>", "Close" },
    C = { "<cmd>:%bd|e#<cr>", "Close all but current" },
    t = { "<cmd>BufferLineTogglePin<cr>", "Pin" },
  },
  ["q"] = { "<cmd>Bdelete!<cr>", "Close buffer" },
  ["Q"] = { "<cmd>:tabc<cr>", "Close tab" },
  ["N"] = {
    "<cmd>lua require 'telescope'.extensions.file_browser.file_browser({ grouped=true, initial_mode='normal', hidden=true,  cwd='%:p:h', select_buffer=true })<cr>",
    "Explorer" },
  ["n"] = { "<cmd>NvimTreeFocus<cr>", "Explorer" },

  -- ["F"] = { "<cmd>Telescope live_grep<cr>", "Find Text" },
  -- ["f"] = { "<cmd>Telescope current_buffer_fuzzy_find fuzzy=false case_mode=ignore_case<cr>",
  -- 	"Find Text in current Buffer" },
  f = {
    name = "Telescope",
    w = { "<cmd>Telescope current_buffer_fuzzy_find fuzzy=false case_mode=ignore_case<cr>",
      "Find Text in current Buffer" },
    f = {
      "<cmd>:Telescope find_files<cr>", "Find files"
    },
    b = {
      "<cmd>lua require('telescope.builtin').buffers({ sort_mru = true, sort_lastused = true, ignore_current_buffer = true })<cr>",
      "Buffers"
    },
    g = {
      "<cmd>:Telescope live_grep<cr>", "Search across files"
    },

  },
  l = {
    name = "LSP",
    a = { "<cmd>lua vim.lsp.buf.code_action()<cr>", "Code Actions" },
    q = { "<cmd>lua vim.diagnostic.setloclist()<cr>", "Quickfix" },
    -- d = {
    --   "<cmd>Telescope diagnostics<cr>",
    --   "Document Diagnostics",
    -- },
    d = {
      "<cmd>TroubleToggle document_diagnostics<cr>",
      "Document Diagnostics",
    },
    w = {
      "<cmd>TroubleToggle workspace_diagnostics<cr>",
      "Workspace Diagnostics",
    },
    T = { "<cmd>lua vim.lsp.buf.definition()<cr>", "Definition" },
    t = { "<cmd>lua require 'goto-preview'.goto_preview_definition()<cr>", "Preview Definition" },
    v = { "<cmd>:vsplit<CR>:lua vim.lsp.buf.definition()<cr>", "Split Definition" },
    l = { "<cmd>lua vim.diagnostic.open_float()<cr>", "Line Diagnostics" },
    -- y = { "<cmd>lua require 'goto-preview'.goto_preview_type_definition()<cr>", "Preview Type Definition" },
    N = { "<cmd>lua vim.lsp.buf.references()<cr>", "References" },
    n = { "<cmd>:vsplit<CR>:lua vim.lsp.buf.references()<cr>", "References" },
    -- n = { "<cmd>lua require 'goto-preview'.goto_preview_references()<cr>", "Preview References" },
    h = { "<cmd>lua vim.lsp.buf.hover()<cr>", "Hover" },
    I = { "<cmd>lua vim.lsp.buf.implementation()<cr>", "Implementation" },
    i = { "<cmd>:vsplit<CR>:lua vim.lsp.buf.implementation()<cr>", "Implementation" },
    -- i = { "<cmd>lua require 'goto-preview'.goto_preview_implementation()<cr>", "Preview Implementation" },
    g = { "<cmd>lua vim.lsp.buf.signature_help()<cr>", "Signature Help" },
    f = { "<cmd>lua vim.lsp.buf.formatting()<cr>", "Format" },
    j = {
      "<cmd>lua vim.diagnostic.goto_next()<CR>",
      "Next Diagnostic",
    },
    k = {
      "<cmd>lua vim.diagnostic.goto_prev()<cr>",
      "Prev Diagnostic",
    },
    -- l = { "<cmd>lua vim.lsp.codelens.run()<cr>", "CodeLens Action" },
    r = { "<cmd>lua vim.lsp.buf.rename()<cr>", "Rename" },
    -- s = { "<cmd>Telescope lsp_document_symbols<cr>", "Document Symbols" },
    s = { "<cmd>Telescope aerial<cr>", "Document Symbols" },
    S = {
      "<cmd>Telescope lsp_dynamic_workspace_symbols<cr>",
      "Workspace Symbols",
    },
    o = { "<cmd>TSLspOrganize<cr>", "Imports Organize" },
    R = { "<cmd>TSLspRenameFile<cr>", "Rename File" },
    A = { "<cmd>TSLspImportAll<cr>", "Import All" },
  },
  e = {
    name = "Tree",
    e = {
      "<cmd>Neotree toggle<cr>",
      "Toggle tree" },
  },
  s = {
    name = "Symbols & Snippets",
    o = {
      "<cmd>SymbolsOutline<cr>",
      "Symbols Outline"
    },
    e = {
      function() require("scissors").editSnippet() end,
      "Edit Snippets"
    },
    a = {
      function() require("scissors").addNewSnippet() end,
      "Add Snippets"
    },

    -- l = {
    -- 	"<cmd>SLoad<cr>",
    -- 	"Session load"
    -- }
  }
}

local opts = {
  mode = "n",
  prefix = "<leader>",
  buffer = nil,
  silent = true,
  noremap = true,
  nowait = true,
}

which_key.setup(setup)
which_key.register(mappings, opts)
