vim.opt.signcolumn = 'yes'

vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(event)
    local opts = { buffer = event.buf }

    vim.keymap.set('n', 'K', '<cmd>lua vim.lsp.buf.hover()<cr>', opts)
    vim.keymap.set('n', 'gd', '<cmd>lua vim.lsp.buf.definition()<cr>', opts)
    vim.keymap.set('n', 'gD', '<cmd>lua vim.lsp.buf.declaration()<cr>', opts)
    vim.keymap.set('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<cr>', opts)
    vim.keymap.set('n', 'go', '<cmd>lua vim.lsp.buf.type_definition()<cr>', opts)
    vim.keymap.set('n', 'gr', '<cmd>lua vim.lsp.buf.references()<cr>', opts)
    vim.keymap.set('n', 'gs', '<cmd>lua vim.lsp.buf.signature_help()<cr>', opts)
    vim.keymap.set('n', '<F2>', '<cmd>lua vim.lsp.buf.rename()<cr>', opts)
    vim.keymap.set({ 'n', 'x' }, '<F3>', '<cmd>lua vim.lsp.buf.format({async = true})<cr>', opts)
    vim.keymap.set('n', '<leader>la', '<cmd>lua vim.lsp.buf.code_action()<cr>', opts)
  end,
})

local lspconfig_defaults = require('lspconfig').util.default_config
lspconfig_defaults.capabilities = vim.tbl_deep_extend(
  'force',
  lspconfig_defaults.capabilities,
  require('cmp_nvim_lsp').default_capabilities()
)
-- Prepare capabilities, handlers, and on_attach
-- local cmp = require("cmp_nvim_lsp")
-- local capabilities
-- do
--   -- Add additional capabilities supported by nvim-cmp
--   capabilities = vim.lsp.protocol.make_client_capabilities()
--   vim.tbl_deep_extend("force", capabilities, cmp.default_capabilities())
-- end

require('mason').setup({})
require('mason-lspconfig').setup({
  handlers = {
    function(server_name)
      require('lspconfig')[server_name].setup({})
    end,
  }
})

vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(event)
    local id = vim.tbl_get(event, 'data', 'client_id')
    local client = id and vim.lsp.get_client_by_id(id)
    if client == nil then
      return
    end

    -- make sure there is at least one client with formatting capabilities
    -- if client.supports_method('textDocument/formatting') then
    --   require('lsp-zero').buffer_autoformat()
    -- end
  end
})
local lspconfig = require("lspconfig")

require('mason-lspconfig').setup_handlers {
  -- The first entry (without a key) will be the default handler
  -- and will be called for each installed server that doesn't have
  -- a dedicated handler.
  function(server) -- default handler (optional)
    lspconfig[server].setup {}
  end,
  -- Next, you can provide a dedicated handler for specific servers.
  -- For example, a handler override for the `rust_analyzer`:
  ["rust_analyzer"] = function(_)
    lspconfig.rust_analyzer.setup {
      settings = {
        ["rust-analyzer"] = {
          assist = {
            emitMustUse = true,
          },
          imports = {
            granularity = {
              group = "module",
            },
            prefix = "self",
          },
        }
      },
    }
  end,
  ["lua_ls"] = function(_)
    lspconfig.lua_ls.setup {
      settings = {
        Lua = {
          diagnostics = {
            -- Get the language server to recognize the `vim` global
            globals = { "vim" },
          },
          hint = {
            enable = true,
          },
          workspace = {
            -- Make the server aware of Neovim runtime files
            library = vim.api.nvim_get_runtime_file("", true),
            -- Whether third party libraries can be detected and applied
            checkThirdParty = false,
          },
        },
      },
    }
  end,
}
