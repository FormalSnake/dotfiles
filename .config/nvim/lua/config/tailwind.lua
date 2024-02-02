return {
	{
		"neovim/lsp-config",
		opts = {
			servers = {
				tailwindcss = {

				},
			},
		},
	},
	require("colorizer").setup({
		user_default_options = {
			tailwind = true,
		},
	})
}
