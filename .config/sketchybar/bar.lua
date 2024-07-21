local colors = require("colors")
local settings = require("settings")

-- Equivalent to the --bar domain
sbar.bar(
    {
        topmost = "window",
        height = 30,
        color = colors.transparent,
        padding_right = 0,
        padding_left = 0,
        margin = 10,
        corner_radius = 8,
        y_offset = 6,
        shadow = true,
        blur_radius = 10,
    }
)
