local colors = require("colors")
local icons = require("icons")
local settings = require("settings")
local app_icons = require("helpers.app_icons")

local space_colors = {
	colors.green,     -- Color for space 1
	colors.yellow,    -- Color for space 2
	colors.orange,    -- Color for space 3
	colors.red,       -- Color for space 4
	colors.magenta,   -- Color for space 5
	colors.blue,      -- Color for space 6
	colors.grey,      -- Color for space 7
	colors.lightgray, -- Color for space 8
	colors.metalsaurus, -- Color for space 9
	colors.metalsaurus2, -- Color for space 10
}

local function getSpaceColor(spaceNumber)
	return space_colors[spaceNumber]
end

local sf_icons_active = {
	"+", -- Add icons for active spaces if needed
}

local sf_icons_inactive = {
	"", -- Add icons for inactive spaces if needed
}

local function getSpaceIcon(space, active, app_name)
	if active then
		return app_icons[app_name]
	else
		return sf_icons_inactive[space]
	end
end

local spaces = {}

local function log(message)
	os.execute('echo "' .. message .. '" >> /tmp/sketchybar.log')
end

local function switchToSpace(spaceNumber)
	local scriptPath = string.format('"$CONFIG_DIR/items/scripts/switchSpace/switchToSpace%d.scpt"', spaceNumber)
	log("Switching to space: " .. spaceNumber .. " with script: " .. scriptPath)
	local command = "osascript " .. scriptPath
	log("Executing command: " .. command)
	local result = os.execute(command)
	log("Result: " .. tostring(result))
end

-- Add padding before the first space
local padding_left = sbar.add("item", "padding.left", {
	position = "left",
	width = 10,
})

for i = 1, 10 do
	local space = sbar.add("space", "space." .. i, {
		space = i,
		position = "center",
	})
	spaces[i] = space

	space:subscribe("front_app_switched", function(env)
		local selected = env.SELECTED == "true"
		sbar.animate("elastic", 10, function()
			space:set({
				label = {
					drawing = false,
				},
				icon = {
					padding_left = selected and 15 or 4,
					padding_right = selected and 15 or 4,
					font = {
						font = "sketchybar-app-font:Regular:16.0",
						size = selected and 16 or 14,
					},
					color = colors.transparent,
				},
				background = {
					height = selected and 10 or 8,
					corner_radius = selected and 8 or 50,
					color = selected and colors.bar.foreground or colors.lightgray,
					padding_left = selected and 10 or 10,
					padding_right = selected and 10 or 10,
				},
			})
		end)
	end)

	space:subscribe("mouse.entered", function(env)
		local selected = env.SELECTED == "true"
		sbar.animate("elastic", 10, function()
			space:set({
				label = {
					drawing = false,
				},
				icon = {
					string = selected and getSpaceIcon(i, true) or getSpaceIcon(i, false),
					padding_left = selected and 20 or 10,
					padding_right = selected and 20 or 10,
				},
				background = {
					color = getSpaceColor(i),
					height = selected and 12 or 10,
					width = selected and 10 or 4,
					corner_radius = selected and 8 or 25,
					padding_left = selected and 5 or 10,
					padding_right = selected and 5 or 10,
				},
			})
		end)
	end)

	space:subscribe("mouse.exited", function(env)
		local selected = env.SELECTED == "true"
		sbar.animate("elastic", 10, function()
			space:set({
				label = {
					drawing = false,
				},
				icon = {
					drawing = true,
					padding_left = selected and 15 or 6,
					padding_right = selected and 15 or 6,
					string = selected and getSpaceIcon(i, true) or getSpaceIcon(i, false),
					font = {
						font = "sketchybar-app-font:Regular:16.0",
						size = selected and 16 or 14,
					},
					color = colors.transparent,
				},
				background = {
					border_width = 0,
					border_color = getSpaceColor(i),
					height = selected and 12 or 12,
					corner_radius = selected and 8 or 50,
					color = selected and colors.bar.foreground or colors.lightgray,
					padding_left = selected and 10 or 10,
					padding_right = selected and 10 or 10,
				},
			})
		end)
	end)

	space:subscribe("mouse.clicked", function(env)
		local selected = env.SELECTED == "true"
		log("Clicked space: " .. i)
		switchToSpace(i)
		icon = {
			click_script = selected and sbar.exec('osascript "$CONFIG_DIR/items/scripts/newSpace.scpt"'),
		}
	end)
end

-- Add padding after the last space
local padding_right = sbar.add("item", "padding.right", {
	position = "right",
	width = 10,
})

local space_names = {}
for i = 1, 10 do
	table.insert(space_names, spaces[i].name)
end

sbar.add("bracket", space_names, {
	background = {
		margin = 0,
		color = colors.bar.bg,
		corner_radius = 8,
	},
})

-- Insert padding items into the bracket
table.insert(space_names, 1, padding_left.name)
table.insert(space_names, padding_right.name)
