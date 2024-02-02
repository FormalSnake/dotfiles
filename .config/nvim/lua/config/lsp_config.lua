require("mason-lspconfig").setup()

local capabilities = require('cmp_nvim_lsp').default_capabilities(vim.lsp.protocol.make_client_capabilities())

require('lspsaga').setup({
  code_action_icon = "",
  code_action_prompt = {
    enable = false,
  },
  symbol_in_winbar = {
    in_custom = false,
    enable = false,
    separator = ' ',
    show_file = true,
    file_formatter = ""
  },
  ui = {
    code_action = ''
  }
})

vim.keymap.set("n", "gd", "<cmd>Lspsaga lsp_finder<CR>", { silent = true })
vim.keymap.set('n', 'K', '<Cmd>Lspsaga hover_doc<cr>', { silent = true })
--vim.keymap.set({ "n", "v" }, "<leader>ca", "<cmd>Lspsaga code_action<CR>", { silent = true })
vim.keymap.set("n", "<leader>rn", "<cmd>Lspsaga rename<CR>", { silent = true })
vim.keymap.set('n', '<leader>dr', vim.diagnostic.goto_prev)
vim.keymap.set('n', '<leader>df', vim.diagnostic.goto_next)
vim.keymap.set('n', '<leader>gD', '<cmd>lua vim.lsp.buf.declaration()<CR>')
vim.keymap.set('n', '<leader>gd', '<cmd>lua vim.lsp.buf.definition()<CR>')
vim.keymap.set('n', '<leader>la', '<cmd>lua vim.lsp.buf.code_action()<CR>')

require("lspconfig").lua_ls.setup {
  inlay_hints = { enabled = true },
  capabilities = capabilities,
  settings = {
    Lua = {
      diagnostics = {
        globals = { "vim" },
      },
      workspace = {
        library = {
          [vim.fn.expand "$VIMRUNTIME/lua"] = true,
          [vim.fn.stdpath "config" .. "/lua"] = true,
        },
      },
    },
  },
  servers = {
    cssls = {},
    tailwindcss = {
      root_dir = function(...)
        return require("lspconfig.util").root_pattern(".git")(...)
      end,
    },
    tsserver = {
      root_dir = function(...)
        return require("lspconfig.util").root_pattern(".git")(...)
      end,
      single_file_support = false,
      settings = {
        typescript = {
          inlayHints = {
            includeInlayParameterNameHints = "literal",
            includeInlayParameterNameHintsWhenArgumentMatchesName = false,
            includeInlayFunctionParameterTypeHints = true,
            includeInlayVariableTypeHints = false,
            includeInlayPropertyDeclarationTypeHints = true,
            includeInlayFunctionLikeReturnTypeHints = true,
            includeInlayEnumMemberValueHints = true,
          },
        },
        javascript = {
          inlayHints = {
            includeInlayParameterNameHints = "all",
            includeInlayParameterNameHintsWhenArgumentMatchesName = false,
            includeInlayFunctionParameterTypeHints = true,
            includeInlayVariableTypeHints = true,
            includeInlayPropertyDeclarationTypeHints = true,
            includeInlayFunctionLikeReturnTypeHints = true,
            includeInlayEnumMemberValueHints = true,
          },
        },
      },
    },
    html = {},
    yamlls = {
      settings = {
        yaml = {
          keyOrdering = false,
        },
      },
    },
    lua_ls = {
      -- enabled = false,
      single_file_support = true,
      settings = {
        Lua = {
          workspace = {
            checkThirdParty = false,
          },
          completion = {
            workspaceWord = true,
            callSnippet = "Both",
          },
          misc = {
            parameters = {
              -- "--log-level=trace",
            },
          },
          hint = {
            enable = true,
            setType = false,
            paramType = true,
            paramName = "Disable",
            semicolon = "Disable",
            arrayIndex = "Disable",
          },
          doc = {
            privateName = { "^_" },
          },
          type = {
            castNumberToInteger = true,
          },
          diagnostics = {
            disable = { "incomplete-signature-doc", "trailing-space" },
            -- enable = false,
            groupSeverity = {
              strong = "Warning",
              strict = "Warning",
            },
            groupFileStatus = {
              ["ambiguity"] = "Opened",
              ["await"] = "Opened",
              ["codestyle"] = "None",
              ["duplicate"] = "Opened",
              ["global"] = "Opened",
              ["luadoc"] = "Opened",
              ["redefined"] = "Opened",
              ["strict"] = "Opened",
              ["strong"] = "Opened",
              ["type-check"] = "Opened",
              ["unbalanced"] = "Opened",
              ["unused"] = "Opened",
            },
            unusedLocalExclude = { "_*" },
          },
          format = {
            enable = false,
            defaultConfig = {
              indent_style = "space",
              indent_size = "2",
              continuation_indent_size = "2",
            },
          },
        },
      },
    },
  },
}

-- require("lspconfig").solargraph.setup {
-- 	capabilities = capabilities,
-- }
--
-- require("lspconfig").zsh.setup {
-- 	capabilities = capabilities,
-- }
--
--
-- require("lspconfig").csharp_ls.setup {
-- 	capabilities = capabilities,
-- }
--
--
-- -- require("lspconfig").tsserver.setup {
-- -- 	capabilities = capabilities,
-- -- }
--
-- require 'lspconfig'.astro.setup {
-- 	capabilities = capabilities,
-- }
--
-- require("lspconfig").pyright.setup {
-- 	capabilities = capabilities,
-- }
--
require("lspconfig").astro.setup {
  capabilities = capabilities,
}
