function setup_ghostty_lsp()
  -- Only activate ghostty-lsp when editing the ghostty config
  if vim.fn.expand("%:p") == vim.fs.normalize("~/.config/ghostty/config") then
    vim.lsp.start({
      name = "ghostty-lsp",
      cmd = { "ghostty-lsp" },
      root_dir = vim.fs.normalize("~/.config/ghostty")
    })
  end
end

vim.api.nvim_create_autocmd("BufRead", { pattern = "*", callback = setup_ghostty_lsp })
