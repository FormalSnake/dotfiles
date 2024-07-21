local colors = require("colors")
local icons = require("icons")
local settings = require("settings")

local whitelist = {
	["Spotify"] = true,
	["YT Music"] = true,
	["Safari"] = true,
}

local function setup_media_items()
	local media_cover = sbar.add("item", {
		background = {
			color = colors.bar.bg,
		},
		position = "right",
		align = "left",
		label = {
			padding_left = 10,
			padding_right = 5,
			drawing = false,
		},
		icon = {
			padding_left = 10,
			padding_right = 10,
			drawing = true,
			string = "󰎆",
			color = colors.green,
		},
		drawing = true,
		updates = true,
		popup = {
			align = "lefz",
			horizontal = true,
			height = 45,
		},
	})

	local media_artist = sbar.add("item", {
		position = "popup." .. media_cover.name,
		drawing = true,
		width = 0,
		icon = {
			drawing = false,
		},
		label = {
			align = "right",
			padding_right = 10,
			padding_left = 10,
			width = "dynamic",
			font = {
				size = 12,
			},
			color = colors.bar.foreground,
			max_chars = 25,
			y_offset = 7,
		},
	})

	local media_title = sbar.add("item", {
		position = "popup." .. media_cover.name,
		drawing = true,
		icon = {
			drawing = false,
		},
		label = {
			align = "right",
			padding_right = 10,

			width = "dynamic",

			color = colors.lightgray,
			max_chars = 25,
			font = {
				size = 12,
			},
			y_offset = -6,
		},
	})

	return media_cover, media_artist, media_title
end

local media_cover, media_artist, media_title = setup_media_items()

local media_bracket = sbar.add("bracket", "media.bracket", { media_title.name, media_artist.name }, {
	label = {
		position = "left",
		align = "left",
		padding_left = 10,
		padding_right = 10,
	},

	background = {
		height = 45,
		color = colors.bar.bg,
	},
	popup = {
		padding_left = 20,
		padding_right = 20,
		align = "right",
	},
})

local media_container = sbar.add("bracket", "media_bracket", { media_title.name }, {
	background = {
		position = "popup." .. media_bracket.name,
	},
})

sbar.add("item", {
	position = "popup." .. media_cover.name,
	padding_left = 20,

	icon = {
		color = colors.bar.foreground_alt_blue,
		string = icons.media.back,
		font = {
			size = 12,
		},
	},
	label = {

		drawing = true,
	},
	click_script = "nowplaying-cli previous",
})
sbar.add("item", {
	position = "popup." .. media_cover.name,
	icon = {
		color = colors.popup.icons,
		string = icons.media.play_pause,
		font = {
			size = 30,
		},
	},

	label = {
		drawing = true,
	},
	click_script = "nowplaying-cli togglePlayPause",
})
sbar.add("item", {
	position = "popup." .. media_cover.name,
	icon = {
		color = colors.bar.foreground_alt_blue,
		string = icons.media.forward,
		font = {
			size = 12,
		},
	},
	label = {
		drawing = true,
	},
	click_script = "nowplaying-cli next",
})

local interrupt = 0
local function animate_detail(detail)
	if not detail then
		interrupt = interrupt - 1
	end
	if interrupt > 0 and not detail then
		return
	end

	sbar.animate("tanh", 30, function()
		media_artist:set({
			label = {
				width = "dynamic",
			},
		})
		media_title:set({
			label = {
				width = "dynamic",
			},
		})
	end)
end

media_cover:subscribe("media_change", function(env)
	if whitelist[env.INFO.app] then
		local drawing = (env.INFO.state == "playing")
		media_artist:set({
			drawing = drawing,
			label = env.INFO.artist,
		})
		media_title:set({
			drawing = drawing,
			label = env.INFO.title,
		})
		media_cover:set({
			drawing = drawing,
		})

		if drawing then
			animate_detail(true)
			interrupt = interrupt + 1
			sbar.delay(5, animate_detail)

			-- Show popup for 10 seconds
			media_cover:set({
				popup = {
					drawing = true,
				},
			})
			sbar.delay(10, function()
				media_cover:set({
					popup = {
						drawing = false,
					},
				})
			end)
		else
			media_cover:set({
				popup = {
					drawing = false,
				},
			})
		end
	end
end)

media_cover:subscribe("mouse.entered", function(env)
	interrupt = interrupt + 1
	animate_detail(true)
end)

media_cover:subscribe("mouse.exited", function(env)
	animate_detail(false)
end)

media_cover:subscribe("mouse.clicked", function(env)
	media_cover:set({
		popup = {
			drawing = "toggle",
		},
	})
end)

media_title:subscribe("mouse.exited.global", function(env)
	media_cover:set({
		popup = {
			drawing = false,
		},
	})
end)

return media_container
