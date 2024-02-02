vim.api.nvim_set_hl(0, "RainbowRed", { fg = "#E06C75" })
vim.api.nvim_set_hl(0, "RainbowBlue", { fg = "#61AFEF" })
require("ibl").setup { scope = { highlight = { "RainbowRed", "RainbowBlue" } } }
local hooks = require "ibl.hooks"
hooks.register(hooks.type.SCOPE_HIGHLIGHT, function(_, _, scope, _)
	if scope:type() == "if_statement" then
		return 2
	end
	return 1
end)
