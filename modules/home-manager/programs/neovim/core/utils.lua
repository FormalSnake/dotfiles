local M = {}

-- Check if a plugin is available
function M.has_plugin(plugin_name)
  local ok, _ = pcall(require, plugin_name)
  return ok
end

-- Safe require function that doesn't throw errors
function M.safe_require(module_name)
  local ok, module = pcall(require, module_name)
  if not ok then
    vim.notify("Failed to load module: " .. module_name, vim.log.levels.ERROR)
    return nil
  end
  return module
end

-- Get LSP clients attached to buffer
function M.get_lsp_clients(bufnr)
  bufnr = bufnr or 0
  return vim.lsp.get_clients({ bufnr = bufnr })
end

-- Check if LSP is attached to current buffer
function M.has_lsp_client(bufnr)
  bufnr = bufnr or 0
  local clients = M.get_lsp_clients(bufnr)
  return #clients > 0
end

-- Get active LSP client names
function M.get_active_lsp_clients(bufnr)
  bufnr = bufnr or 0
  local clients = M.get_lsp_clients(bufnr)
  local names = {}
  for _, client in ipairs(clients) do
    table.insert(names, client.name)
  end
  return names
end

-- Create autocommand group
function M.create_augroup(name, opts)
  opts = opts or { clear = true }
  return vim.api.nvim_create_augroup(name, opts)
end

-- Set buffer-local keymap
function M.buf_keymap(bufnr, mode, lhs, rhs, opts)
  opts = opts or {}
  opts.buffer = bufnr
  vim.keymap.set(mode, lhs, rhs, opts)
end

-- Toggle option
function M.toggle_option(option)
  vim.opt[option] = not vim.opt[option]:get()
  vim.notify(option .. " = " .. tostring(vim.opt[option]:get()))
end

-- Toggle global variable
function M.toggle_var(var)
  vim.g[var] = not vim.g[var]
  vim.notify(var .. " = " .. tostring(vim.g[var]))
end

-- Get git root directory
function M.get_git_root()
  local git_root = vim.fn.system("git rev-parse --show-toplevel"):gsub('\n', '')
  if vim.v.shell_error == 0 then
    return git_root
  end
  return nil
end

-- Get project root (prioritizes git root, falls back to cwd)
function M.get_project_root()
  local git_root = M.get_git_root()
  if git_root then
    return git_root
  end
  return vim.fn.getcwd()
end

-- Check if we're in a git repository
function M.is_git_repo()
  return M.get_git_root() ~= nil
end

-- Pretty print lua table
function M.dump(o)
  if type(o) == 'table' then
    local s = '{ '
    for k, v in pairs(o) do
      if type(k) ~= 'number' then
        k = '"' .. k .. '"'
      end
      s = s .. '[' .. k .. '] = ' .. M.dump(v) .. ','
    end
    return s .. '} '
  else
    return tostring(o)
  end
end

-- Check if buffer is empty
function M.is_empty_buffer(bufnr)
  bufnr = bufnr or 0
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  return #lines == 1 and lines[1] == ""
end

-- Get buffer word count
function M.get_word_count(bufnr)
  bufnr = bufnr or 0
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local text = table.concat(lines, " ")
  local word_count = 0
  for _ in text:gmatch("%S+") do
    word_count = word_count + 1
  end
  return word_count
end

-- Format file size
function M.format_file_size(bytes)
  local units = { "B", "KB", "MB", "GB" }
  local unit_index = 1
  
  while bytes >= 1024 and unit_index < #units do
    bytes = bytes / 1024
    unit_index = unit_index + 1
  end
  
  return string.format("%.1f%s", bytes, units[unit_index])
end

return M