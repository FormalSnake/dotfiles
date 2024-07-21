local settings = require("settings")
local colors = require("colors")

sbar.default(
	{

		updates = "when_shown",
		icon = {

			color = colors.white,
			font = {
				family = settings.font.text,
				style = settings.font.style_map.Bold,
				size = 12.0
			},
		},
		label = {
			padding_left = settings.paddings,
			padding_right = settings.paddings,
			font = {
				family = settings.font.text,
				style = settings.font.style_map.SemiBold,
				size = 12.0
			},
			color = colors.bar.foreground
		},
		background = {
			height = 26,
			corner_radius = 8,
			border_width = 0.5,
			border_color = colors.bar.border,
			image = {
				corner_radius = 8
			},


		},
		popup = {
			icon = { drawing = false, },
			label = {

				font = {
					family = settings.font.text,
					style = settings.font.style_map.SemiBold,
					size = 14.0
				},
				color = colors.bar.foreground_alt
			},
			background = {
				border_width = 1,
				corner_radius = 8,
				border_color = colors.popup.border,
				color = colors.popup.bg,
				shadow = {
					drawing = true
				},
			},
			blur_radius = 80
		},
		padding_right = settings.group_paddings,
		padding_left = settings.group_paddings,
		scroll_texts = true
	}
)
