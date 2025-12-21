return {
	{
		"datsfilipe/vesper.nvim",
		lazy = false, -- Garante que o tema seja carregado na inicialização
		priority = 1000, -- Garante que seja o primeiro a ser carregado
		config = function()
			vim.cmd.colorscheme("vesper")
		end,
	},
}
