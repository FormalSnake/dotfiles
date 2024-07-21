local colors = require("colors")
local icons = require("icons")
local settings = require("settings")


local apple = sbar.add("item", {
	label = {
		string = "",
		padding_right = 0,
		padding_left = 10,
	},
	icon = {
		padding_left = 10,
		font = {
			size = 14,
		},
		string = "􀆈",
		color = colors.bar.foreground,

	},

	background = {

		color = colors.bar.bg,
	},

	click_script = "$CONFIG_DIR/helpers/menus/bin/menus -s 0",
})

apple:subscribe("mouse.entered", function(env)
	local selected = env.SELECTED == "true"
	sbar.animate("elastic", 10, function()
		apple:set({



			label = {
				color = colors.bar.foreground,
				padding_right = 12,
				drawing = true,
				string = "open",
				padding_left = 10,
			},
			icon = {


				color = colors.bar.foreground_dimmed,
				string = "􀆈",
				font = {
					size = 14,
				},
			},
		})
	end)
end)

apple:subscribe("mouse.exited", function(env)
	sbar.animate("elastic", 10, function()
		apple:set({
			label = {
				string = "",
				padding_right = 0,
				padding_left = 10,
			},
			icon = {
				padding_left = 10,
				font = {
					size = 14,
				},
				string = "􀆈",
				color = colors.bar.foreground,

			},
		})
	end)
end)
