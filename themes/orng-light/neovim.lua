return {
	{
		"bachiitter/orng.nvim",
		lazy = false,
		priority = 1000,
		config = function()
			require("orng").setup()
		end,
	},
}
