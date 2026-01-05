return {
  {
    "IogaMaster/neocord",
    event = "VeryLazy",
    -- call neocord setup function
    init = function()
      require("neocord").setup({})
    end,
  },
}
