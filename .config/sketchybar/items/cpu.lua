local icons = require("icons")
local colors = require("colors")
local settings = require("settings")

-- Execute the event provider binary which provides the event "cpu_update" for
-- the cpu load data, which is fired every 2.0 seconds.
sbar.exec("killall cpu_load >/dev/null; $CONFIG_DIR/helpers/event_providers/cpu_load/bin/cpu_load cpu_update 2.0")




local cpu = sbar.add("graph", "widgets.cpu", 42, {


    position = "right",

    background = {
        height = 18,
        color = { alpha = 0 },
        border_color = { alpha = 0 },
        drawing = true,
    },
    icon = {
        string = icons.cpu,
        color = colors.yellow,

    },
    label = {
        color = colors.lightgray,
        string = "cpu ??%",
        font = {
            family = settings.font.numbers,
            style = settings.font.style_map["Bold"],
            size = 12.0,
        },
        align = "right",


        y_offset = 0
    },
    padding_right = settings.paddings + 6,
    padding_left = settings.paddings + 6,
})

cpu:subscribe("cpu_update", function(env)
    -- Also available: env.user_load, env.sys_load
    local load = tonumber(env.total_load)
    cpu:push({ load / 100. })

    local color = colors.blue
    if load > 30 then
        if load < 60 then
            color = colors.yellow
        elseif load < 80 then
            color = colors.bar.foreground_alt
        else
            color = colors.red
        end
    end

    cpu:set({
        graph = {
            color = color,
            drawing = false
        },
        label = "cpu " .. env.total_load .. "%",
    })
end)

cpu:subscribe("mouse.clicked", function(env)
    sbar.exec("open -a 'Activity Monitor'")
end)

-- Background around the cpu item
sbar.add("bracket", "widgets.cpu.bracket", { cpu.name }, {
    background = { color = colors.bar.bg }
})
