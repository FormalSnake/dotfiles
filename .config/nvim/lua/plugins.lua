local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)
require("lazy").setup({
  -- The best theme ever
  -- {
  -- 	"catppuccin/nvim",
  -- 	name = "catppuccin",
  -- 	priority = 1000,
  -- 	config = function()
  -- 		require('themes.catppuccin')
  -- 	end
  -- },

  "nvim-treesitter/nvim-treesitter-context",
  { 'rasulomaroff/reactive.nvim' },
  "wuelnerdotexe/vim-astro",
  {
    "chrisgrieser/nvim-scissors",
    -- dependencies = "nvim-telescope/telescope.nvim",
  },
  {
    "karb94/neoscroll.nvim",
    config = function()
      require('neoscroll').setup {}
    end
  },
  {
    "gambhirsharma/vesper.nvim",
    lazy = false,
    priority = 1000,
    name = "vesper",
    -- config = function()
    --   vim.cmd([[colorscheme vesper]])
    -- end
  },
  {
    "dstein64/vim-startuptime",
    cmd = "StartupTime",
    config = function()
      vim.g.startuptime_tries = 10
    end,
  },
  {
    "tinted-theming/base16-vim",
    priority = 1000,
    config = function()
      local cmd = vim.cmd
      local g = vim.g
      local current_theme_name = os.getenv('BASE16_THEME')
      -- if current_theme_name == 'black-metal-bathory' then
      --   cmd('colorscheme vesper')
      --[[ else ]]
      if current_theme_name and g.colors_name ~= 'base16-' .. current_theme_name then
        cmd('let base16colorspace=256')
        cmd('colorscheme base16-' .. current_theme_name)
      end
    end
  },
  -- {
  --   "RRethy/nvim-base16",
  --   enable = true,
  --   config = function()
  --     require("base16-colorscheme").with_config({
  --       telescope = false,
  --       indentblankline = true,
  --       notify = true,
  --       ts_rainbow = true,
  --       cmp = true,
  --       illuminate = true,
  --     })
  --   end
  -- },
  {
    "alexghergh/nvim-tmux-navigation",
    config = function()
      local nvim_tmux_nav = require('nvim-tmux-navigation')

      nvim_tmux_nav.setup {
        disable_when_zoomed = true -- defaults to false
      }

      vim.keymap.set('n', "<C-h>", nvim_tmux_nav.NvimTmuxNavigateLeft)
      vim.keymap.set('n', "<C-j>", nvim_tmux_nav.NvimTmuxNavigateDown)
      vim.keymap.set('n', "<C-k>", nvim_tmux_nav.NvimTmuxNavigateUp)
      vim.keymap.set('n', "<C-l>", nvim_tmux_nav.NvimTmuxNavigateRight)
      vim.keymap.set('n', "<C-\\>", nvim_tmux_nav.NvimTmuxNavigateLastActive)
      vim.keymap.set('n', "<C-Space>", nvim_tmux_nav.NvimTmuxNavigateNext)
    end
  },
  {
    "nvim-treesitter/nvim-treesitter",
    dependencies = {
      "windwp/nvim-ts-autotag"
    }

  },

  {
    'goolord/alpha-nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
  },
  'wbthomason/packer.nvim',
  -- {
  --   'goolord/alpha-nvim',
  --   branch = 'feature/startify-fortune',
  --   dependencies = { 'BlakeJC94/alpha-nvim-fortune' },
  -- },
  -- Better increase/descrease
  {
    "monaqa/dial.nvim",
    -- stylua: ignore
    keys = {
      {
        "<C-a>",
        function() return require("dial.map").inc_normal() end,
        expr = true,
        desc =
        "Increment"
      },
      {
        "<C-x>",
        function() return require("dial.map").dec_normal() end,
        expr = true,
        desc =
        "Decrement"
      },
    },
    config = function()
      local augend = require("dial.augend")
      require("dial.config").augends:register_group({
        default = {
          augend.integer.alias.decimal,
          augend.integer.alias.hex,
          augend.date.alias["%Y/%m/%d"],
          augend.constant.alias.bool,
          augend.semver.alias.semver,
          augend.constant.new({ elements = { "let", "const" } }),
        },
      })
    end,
  },
  { 'rmagatti/auto-session', },
  { 'kosayoda/nvim-lightbulb' },
  {
    'mrcjkb/rustaceanvim',
    version = '^3', -- Recommended
    ft = { 'rust' },
  },
  {
    "utilyre/barbecue.nvim",
    name = "barbecue",
    version = "*",
    dependencies = {
      "SmiteshP/nvim-navic",
      "nvim-tree/nvim-web-devicons", -- optional dependency
    },
    opts = {
      -- configurations go here
    },
  },
  "RRethy/vim-illuminate",
  -- {
  --   "FormalSnake/base46-colors",
  --
  --   priority = 1000,
  -- },
  "b0o/incline.nvim",
  -- Makes the UI pretty :)
  {
    'stevearc/dressing.nvim',
    lazy = true,
    init = function()
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.ui.select = function(...)
        require("lazy").load({ plugins = { "dressing.nvim" } })
        return vim.ui.select(...)
      end
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.ui.input = function(...)
        require("lazy").load({ plugins = { "dressing.nvim" } })
        return vim.ui.input(...)
      end
    end,
  },
  -- Inline git blame to see who made the line
  {
    "FabijanZulj/blame.nvim",
    config = function()
      vim.keymap.set("n", "<leader>b", "<cmd>ToggleBlame virtual<CR>", {})
    end,
  },
  -- Allows you to comment current lines using a shortcut
  {
    'numToStr/Comment.nvim',
    opts = {
      -- add any options here
    },
    lazy = false,
  },
  -- Shows you all of the functions, etc. in your file
  'simrat39/symbols-outline.nvim',
  -- Adds the notifications and stuff
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = {
      -- if you lazy-load any plugin below, make sure to add proper `module="..."` entries
      "MunifTanjim/nui.nvim",
      -- OPTIONAL:
      --   `nvim-notify` is only needed, if you want to use the notification view.
      --   If not available, we use `mini` as the fallback
      "rcarriga/nvim-notify",
    },
  },
  {
    "rcarriga/nvim-notify",
    keys = {
      {
        "<leader>h",
        function()
          require("notify").dismiss({ silent = true, pending = true })
        end,
        desc = "Dismiss all Notifications",
      },
    },
    opts = {
      render = "minimal",
      animation_style = "fade",
      background_colour = "#1E2021",
      timeout = 2000,
      max_height = function()
        return math.floor(vim.o.lines * 0.75)
      end,
      max_width = function()
        return math.floor(vim.o.columns * 0.75)
      end,
    },
    init = function()
      vim.notify = require("notify")
    end,
  },
  {
    'gen740/SmoothCursor.nvim',
    config = function()
      require('smoothcursor').setup({
        autostart = true,
        cursor = "", -- cursor shape (need nerd font)
        texthl = "SmoothCursor", -- highlight group, default is { bg = nil, fg = "#FFD400" }
        linehl = nil, -- highlight sub-cursor line like 'cursorline', "CursorLine" recommended
        type = "default", -- define cursor movement calculate function, "default" or "exp" (exponential).
        fancy = {
          enable = true, -- enable fancy mode
          head = { cursor = "ᐉ", texthl = "SmoothCursor", linehl = nil },
          body = {
            { cursor = "", texthl = "SmoothCursor" },
            { cursor = "", texthl = "SmoothCursor" },
            { cursor = "●", texthl = "SmoothCursor" },
            { cursor = "●", texthl = "SmoothCursor" },
            { cursor = "•", texthl = "SmoothCursor" },
            { cursor = ".", texthl = "SmoothCursor" },
            { cursor = ".", texthl = "SmoothCursor" },
          },
          tail = { cursor = nil, texthl = "SmoothCursor" },
        },
        flyin_effect = nil,                          -- "bottom" or "top"
        speed = 25,                                  -- max is 100 to stick to your current position
        intervals = 35,                              -- tick interval
        priority = 10,                               -- set marker priority
        timeout = 3000,                              -- timout for animation
        threshold = 3,                               -- animate if threshold lines jump
        disable_float_win = true,                    -- disable on float window
        enabled_filetypes = nil,                     -- example: { "lua", "vim" }
        disabled_filetypes = { "lazy", "NvimTree" }, -- this option will be skipped if enabled_filetypes is set. example: { "TelescopePrompt", "NvimTree" }
      })
    end
  },
  {
    'wfxr/minimap.vim',
    build = "cargo install --locked code-minimap",
    init = function()
      vim.g.minimap_width = 10
      vim.g.minimap_auto_start = 1
      vim.g.minimap_auto_start_win_enter = 1
    end
  },
  {
    "petertriho/nvim-scrollbar",
    config = function()
      local scrollbar = require("scrollbar")
      scrollbar.setup({
        show = true,
        handle = {
          color = "#2e303e",
        },
        marks = {},
        handlers = {
          cursor = false,
        },
        excluded_filetypes = {
          "prompt",
          "TelescopePrompt",
          "noice",
          "NvimTree",
          "alpha",
        },
      })

      local group = vim.api.nvim_create_augroup("_scrollbar", { clear = true })
    end
  },
  -- { 'echasnovski/mini.nvim',    version = '*', },
  -- {
  --   "echasnovski/mini.animate",
  --   event = "VeryLazy",
  --   opts = function(_, opts)
  --     opts.scroll = {
  --       enable = true,
  --     }
  --   end,
  -- },
  -- Allows you to make the background translucent
  -- 'xiyaowong/transparent.nvim',
  -- This adds a scrollbar (doesn't work)
  -- 'petertriho/nvim-scrollbar',
  -- This adds LSP progress indicators
  {
    "j-hui/fidget.nvim",
    tag = "legacy",
    event = "LspAttach",
    opts = {
      -- options
    },
  },
  -- NOTE: There is highlighting O.O
  {
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },

  },
  -- {
  -- 	"startup-nvim/startup.nvim",
  -- 	dependencies = { "nvim-telescope/telescope.nvim", "nvim-lua/plenary.nvim" }
  -- },
  -- Color picker
  'uga-rosa/ccc.nvim',
  -- This generates gitignores
  'wintermute-cell/gitignore.nvim',
  -- This makes the errors in your code point to the characters using lines, but it does get messy sometimes
  -- "https://git.sr.ht/~whynothugo/lsp_lines.nvim",
  {
    "pmizio/typescript-tools.nvim",
    dependencies = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
    opts = {},
  },
  -- Inline colors, like red
  "nvChad/nvim-colorizer.lua",
  -- Same thing as before, but can display hsl(296, 25, 50%)
  'brenoprata10/nvim-highlight-colors',
  {
    'stevearc/conform.nvim',
    config = function()
      require("conform").setup({
        formatters_by_ft = {
          lua = { "lua_ls" },
          -- Conform will run multiple formatters sequentially
          python = { "isort", "black" },
          -- Use a sub-list to run only the first available formatter
          javascript = { { "prettier" } },
        },
        format_on_save = {
          -- These options will be passed to conform.format()
          timeout_ms = 500,
          lsp_fallback = true,
        },
      })
    end
  },
  -- Formats on save
  -- "elentok/format-on-save.nvim",
  -- Adds indicators to see what function you're in
  {
    "lukas-reineke/indent-blankline.nvim",
    opts = {
      indent = {
        char = "│",
        tab_char = "│",
      },
      scope = { enabled = false },
      exclude = {
        filetypes = {
          "help",
          "alpha",
          "dashboard",
          "neo-tree",
          "Trouble",
          "trouble",
          "lazy",
          "mason",
          "notify",
          "toggleterm",
          "lazyterm",
        },
      },
    },
    main = "ibl",
  },
  -- This allows for us to show images in neovim using any terminal emulator!!
  "MaximilianLloyd/ascii.nvim",
  -- UI library required for the fancy UI ones
  { "MunifTanjim/nui.nvim",            lazy = true },
  -- This adds colors to tailwind syntax highlighting
  "roobert/tailwindcss-colorizer-cmp.nvim",
  -- Highlights words under your cursor, and also the same words accross the file
  -- "yamatsum/nvim-cursorline",
  -- IDK, plugins require it
  'm00qek/baleia.nvim',
  "onsails/lspkind.nvim",
  -- Sidebar file explorer, mostly for aesthetics
  -- 'nvim-tree/nvim-tree.lua',
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons", -- not strictly required, but recommended
      "MunifTanjim/nui.nvim",
      -- "3rd/image.nvim", -- Optional image support in preview window: See `# Preview Mode` for more information
    },
    config = function()
      -- local opts = { noremap = true, silent = true }
      -- local map = vim.api.nvim_set_keymap
      -- map("n", "<leader>e", ":Neotree toggle<CR>", opts)
      require("neo-tree").setup({
        popup_border_style = "rounded",
        window = {
          position = "float",
        },
        filesystem = {
          filtered_items = {
            hide_dotfiles = false,
          },
        },
      })
    end,
  },
  {
    "danielfalk/smart-open.nvim",
    branch = "0.2.x",
    config = function()
      require("telescope").load_extension("smart_open")
    end,
    dependencies = {
      "kkharji/sqlite.lua",
      -- Only required if using match_algorithm fzf
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
      -- Optional.  If installed, native fzy will be used when match_algorithm is fzy
      { "nvim-telescope/telescope-fzy-native.nvim" },
    },
  },
  -- This provides icons for the file managers, etc.
  {
    "nvim-tree/nvim-web-devicons",
    config = function()
      require("nvim-web-devicons").set_icon({
        astro = {
          icon = "",
          color = "#d18770",
          name = "Astro",
        },
        sol = {
          icon = "",
          color = "#638EF6",
          name = "Solidity",
        },
      })
    end,
  },
  -- The frontend for the ascii.nvim
  'samodostal/image.nvim',
  -- Lua function wrapper
  'nvim-lua/plenary.nvim',
  'nvim-pack/nvim-spectre',
  -- Shows the git diff in another buffer
  'sindrets/diffview.nvim',
  -- Shows you all warning and errors in your file
  {
    "folke/trouble.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
    }

  },
  -- 'Xuyuanp/scrollbar.nvim',
  -- Shows which keybinds there are and to what they correspond
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    init = function()
      vim.o.timeout = true
      vim.o.timeoutlen = 300
    end,
  },
  -- Lets you configure the lsp
  'neovim/nvim-lspconfig',
  -- Sessions like in vscode
  -- 'rmagatti/auto-session',
  -- prettier
  'MunifTanjim/prettier.nvim',
  -- Allows you to fuzzyfind files and buffers, etc.
  'nvim-telescope/telescope.nvim',
  -- Makes the theme work with the custom telescope layout
  -- "notken12/base46-colors",
  -- Built in terminal if you are too lazy to use tmux panes
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    opts = {
      open_mapping = [[<leader>v]],
      direction = "horizontal",
      close_on_exit = true,
      float_opts = {
        border = "curved",
      },
    },
  },
  -- Git features
  {
    "lewis6991/gitsigns.nvim",
    opts = {
      signs = {
        add = { text = "▎" },
        change = { text = "▎" },
        delete = { text = "" },
        topdelete = { text = "" },
        changedelete = { text = "▎" },
        untracked = { text = "▎" },
      },
      on_attach = function(buffer)
        local gs = package.loaded.gitsigns

        local function map(mode, l, r, desc)
          vim.keymap.set(mode, l, r, { buffer = buffer, desc = desc })
        end

        -- stylua: ignore start
        map("n", "]h", gs.next_hunk, "Next Hunk")
        map("n", "[h", gs.prev_hunk, "Prev Hunk")
        map({ "n", "v" }, "<leader>ghs", ":Gitsigns stage_hunk<CR>", "Stage Hunk")
        map({ "n", "v" }, "<leader>ghr", ":Gitsigns reset_hunk<CR>", "Reset Hunk")
        map("n", "<leader>ghS", gs.stage_buffer, "Stage Buffer")
        map("n", "<leader>ghu", gs.undo_stage_hunk, "Undo Stage Hunk")
        map("n", "<leader>ghR", gs.reset_buffer, "Reset Buffer")
        map("n", "<leader>ghp", gs.preview_hunk, "Preview Hunk")
        map("n", "<leader>ghb", function() gs.blame_line({ full = true }) end, "Blame Line")
        map("n", "<leader>ghd", gs.diffthis, "Diff This")
        map("n", "<leader>ghD", function() gs.diffthis("~") end, "Diff This ~")
        map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", "GitSigns Select Hunk")
      end,
    },
  },
  -- LSP installer
  "williamboman/mason.nvim",
  "williamboman/mason-lspconfig.nvim",
  -- Improves lsp idk
  "glepnir/lspsaga.nvim",
  -- Shows the fancy autocomplete window O.O
  {
    "hrsh7th/nvim-cmp",
    version = false, -- last release is way too old
    event = "InsertEnter",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "saadparwaiz1/cmp_luasnip",
    },
  },
  -- your code gets colors O.O
  { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate" },
  -- CMP with LSP integration
  "hrsh7th/cmp-nvim-lsp",
  -- The bar at the bottom of your neovim, mostly for aesthetics
  'nvim-lualine/lualine.nvim',
  -- This autocompletes things like () and {}
  {
    'windwp/nvim-autopairs',
    event = "InsertEnter",
    opts = {} -- this is equalent to setup({}) function
  },

  -- Lua snippets
  {
    "L3MON4D3/LuaSnip",
    dependencies = {
      "rafamadriz/friendly-snippets",
      config = function()
        require("luasnip.loaders.from_vscode").lazy_load()
      end,
    },
    opts = {
      history = true,
      delete_check_events = "TextChanged",
    },
    -- stylua: ignore
    keys = {
      {
        "<tab>",
        function()
          return require("luasnip").jumpable(1) and "<Plug>luasnip-jump-next" or "<tab>"
        end,
        expr = true,
        silent = true,
        mode = "i",
      },
      { "<tab>",   function() require("luasnip").jump(1) end,  mode = "s" },
      { "<s-tab>", function() require("luasnip").jump(-1) end, mode = { "i", "s" } },
    },
  },
  -- Basically tabs
  -- 'akinsho/bufferline.nvim',

})

vim.keymap.set('n', '<leader>l', '<cmd>Lazy<cr>', { desc = 'Lazy: Manage plugins' })
-- vim.cmd.colorscheme "catppuccin"
