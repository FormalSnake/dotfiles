local colors = require("colors")
local icons = require("icons")
local settings = require("settings")

local popup_width = 140

local volume_percent =
    sbar.add(
        "item",
        "widgets.volume1",
        {
            position = "right",
            icon = {
                drawing = false
            },
            label = {
                padding_right = 5,
                align = "right",
                string = "??%",
                color = colors.bar.foreground_light,
                font = {
                    size = 12,
                    style = settings.font.style_map["SemiBold"],
                    family = settings.font.text,
                    color = colors.bg1
                }
            }
        }
    )

local volume_icon =
    sbar.add(
        "item",
        "widgets.volume2",
        {
            position = "right",
            padding_right = 0,
            padding_left = 5,
            icon = {
                color = colors.bar.foreground_alt_blue,

            },
            label = {
                align = "right",
                color = colors.bar.foreground_alt,
            }
            -- click_script = "osascript $CONFIG_DIR/items/scripts/openSoundMenu.scpt"
        }
    )

local volume_bracket =
    sbar.add(
        "bracket",
        "widgets.volume.bracket",
        { volume_icon.name, volume_percent.name },
        {
            padding_left = 10,
            padding_right = 10,

            background = {
                color = colors.bar.bg
            },
            popup = {
                align = "left"
            }
        }
    )

sbar.add(
    "item",
    {
        position = "right",
        width = settings.group_paddings
    }
)
local volume_slider =
    sbar.add(
        "slider",
        popup_width,
        {
            position = "popup." .. volume_bracket.name,
            slider = {
                highlight_color = colors.grey,
                y_offset = 5,
                background = {

                    height = 15,
                    corner_radius = 6,
                    color = colors.grey5,
                },
                knob = {

                    color = colors.white,
                    border = {
                        size = 2,
                        color = colors.white
                    },
                    string = "􀀁",
                    drawing = true
                }
            },
            background = {

                color = colors.transparent,
                height = 25
            },
            click_script = 'osascript -e "set volume output volume $PERCENTAGE"'
        }
    )

volume_percent:subscribe(
    "volume_change",
    function(env)
        local volume = tonumber(env.INFO)
        local icon = icons.volume._0
        if volume > 60 then
            icon = icons.volume._100
        elseif volume > 30 then
            icon = icons.volume._66
        elseif volume > 10 then
            icon = icons.volume._33
        elseif volume > 0 then
            icon = icons.volume._10
        end

        local lead = ""
        if volume < 10 then
            lead = "0"
        end

        volume_icon:set(
            {
                color = colors.bar.foreground_alt_blue,
                label = icon
            }
        )
        volume_percent:set(
            {
                label = lead .. volume .. "%"
            }
        )
        volume_slider:set(
            {
                slider = {
                    percentage = volume
                }
            }
        )
    end
)

local function volume_collapse_details()
    local drawing = volume_bracket:query().popup.drawing == "on"
    if not drawing then
        return
    end
    volume_bracket:set(
        {
            popup = {
                drawing = false
            }
        }
    )
    sbar.remove("/volume.device\\.*/")
end

local current_audio_device = "None"
local function volume_toggle_details(env)
    if env.BUTTON == "right" then
        sbar.exec("open /System/Library/PreferencePanes/Sound.prefpane")
        return
    end

    local should_draw = volume_bracket:query().popup.drawing == "off"
    if should_draw then
        volume_bracket:set(
            {
                popup = {
                    drawing = true
                }
            }
        )
        sbar.exec(
            "SwitchAudioSource -t output -c",
            function(result)
                current_audio_device = result:sub(1, -2)
                sbar.exec(
                    "SwitchAudioSource -a -t output",
                    function(available)
                        local current = current_audio_device
                        local color = colors.bg1
                        local counter = 0

                        for device in string.gmatch(available, "[^\r\n]+") do
                            local color = colors.bg1
                            if current == device then
                                color = colors.slategray.one
                            end
                            sbar.add(
                                "item",
                                "volume.device." .. counter,
                                {
                                    position = "popup." .. volume_bracket.name,
                                    width = popup_width,
                                    align = "left",
                                    label = {
                                        font = {
                                            size = 12
                                        },
                                        string = device,
                                        color = colors.bar.foreground_alt_blue,
                                    },
                                    click_script = 'SwitchAudioSource -s "' ..
                                        device ..
                                        '" && sketchybar --set /volume.device\\.*/ label.color=' ..
                                        colors.slategray.two .. " --set $NAME label.color=" .. colors.slategray.two
                                }
                            )
                            counter = counter + 1
                        end
                    end
                )
            end
        )
    else
        volume_collapse_details()
    end
end

local function volume_scroll(env)
    local delta = env.SCROLL_DELTA
    sbar.exec('osascript -e "set volume output volume (output volume of (get volume settings) + ' .. delta .. ')"')
end

volume_icon:subscribe("mouse.clicked", volume_toggle_details)
volume_icon:subscribe("mouse.scrolled", volume_scroll)
volume_percent:subscribe("mouse.clicked", volume_toggle_details)
volume_percent:subscribe("mouse.exited.global", volume_collapse_details)
volume_percent:subscribe("mouse.scrolled", volume_scroll)
