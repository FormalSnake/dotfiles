require("scissors").setup {
  snippetDir = vim.fn.stdpath("config") .. "/snippets",
  editSnippetPopup = {
    height = 0.4, -- relative to the window, number between 0 and 1
    width = 0.6,
    border = "rounded",
    keymaps = {
      cancel = "q",
      saveChanges = "<CR>",
      goBackToSearch = "<BS>",
      delete = "<C-BS>",
      openInFile = "<C-o>",
      insertNextToken = "<C-t>", -- works in insert & normal mode
    },
  },
  -- `none` writes as a minified json file using `:h vim.encode.json`.
  -- `yq`/`jq` ensure formatted & sorted json files, which is relevant when
  -- you version control your snippets.
  jsonFormatter = "none", -- "yq"|"jq"|"none"
}
