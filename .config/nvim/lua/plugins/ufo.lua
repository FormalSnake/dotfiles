return {
  "kevinhwang91/nvim-ufo",
  dependencies = {
    "kevinhwang91/promise-async",
  },
  opts = function()
    provider_selector = function(bufnr, filetype, buftype)
      return { "treesitter", "indent" }
    end
  end,
}
