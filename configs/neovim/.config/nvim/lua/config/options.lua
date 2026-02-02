-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Yarn monorepo-aware root detection
-- Prioritize .git over LSP since yarn workspaces only have .git at monorepo root
-- (LSP often sets root_dir to individual package directories)
vim.g.root_spec = {
  { ".git" }, -- .git only exists at monorepo root
  "lsp", -- Fallback to LSP for non-monorepo projects
  "cwd",
}
