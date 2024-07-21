local colors = require("colors")
local settings = require("settings")


local front_app = sbar.add("item", "front_app", {

    position = "left",
    display = "active",
    background = {
        color = colors.bar.bg,
    },
    label = {
        padding_left = 10,
        padding_right = 10,
        color = colors.bar.foreground,
        font = {
            style = settings.font.style_map["Semibold"],
            size = 12.0,
        },
    },
    updates = true,

})

front_app:subscribe("mouse.entered", function(env)
    local selected = env.SELECTED == "true"
    sbar.animate("elastic", 10, function()
        front_app:set({
            position = "left",
            display = "active",
            background = {
                color = colors.bar.bg,
            },
            label = {
                padding_left = 10,
                padding_right = 10,
                color = colors.bar.orange,
                font = {
                    style = settings.font.style_map["Semibold"],
                    size = 14.0,
                },
            },
            updates = true,
        })
    end)
end)

front_app:subscribe("mouse.exited", function(env)
    local selected = env.SELECTED == "true"
    sbar.animate("elastic", 10, function()
        front_app:set({
            position = "left",
            display = "active",
            background = {
                color = colors.bar.bg,
            },
            label = {
                padding_left = 10,
                padding_right = 10,
                color = colors.bar.foreground,
                font = {
                    style = settings.font.style_map["Semibold"],
                    size = 12.0,
                },
            },
            updates = true,
        })
    end)
end)

front_app:subscribe("front_app_switched", function(env)
    sbar.animate("elastic", 10, function()
        front_app:set({
            label = { string = env.INFO },
        })
    end)
end)


front_app:subscribe("mouse.clicked", function(env)
    sbar.trigger("swap_menus_and_spaces")
end)
