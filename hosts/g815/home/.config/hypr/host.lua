-- The g815: the ASUS PA278CGV as the main display, the ASUS MB16QHG portable below its right edge,
-- the internal 240 Hz panel right of that, all scanned out by the RTX 5070. All are matched by
-- desc: connector names follow the driver and the port, and the ASUS has been on HDMI-A-1 and on
-- USB-C DisplayPort.
local panel = "desc:BOE NE180QDM-NZC"
local desk = "desc:ASUSTek COMPUTER INC PA278CGV T1LMQS063802"
local portable = "desc:ASUSTek COMPUTER INC MB16QHG RCLMTF037964"
local workspaces = {}
for i = 1, 9 do
  workspaces[i] = { monitor = (i == 4 or i == 8) and portable or desk, default = (i == 1 or i == 4) }
end
return {
  -- vrr = 1 on the ASUS over HDMI-A-1 came up black at boot: the link trains, EDID and ELD read fine, the CRTC
  -- goes active at 144, and no picture ever lands. 2 holds VRR off until a window goes fullscreen:
  -- 3 waits for a game or video content type, which Proton games and Sober never send.
  -- Hyprland lays XWayland's outputs out in connection order, so the panel (always first) is at
  -- x 0 there. Starting the ASUS at 2560 puts it at the same coordinates in both layouts, which is
  -- what keeps fullscreen Wine games on it from sizing themselves to the panel.
  monitors = {
    { output = desk, mode = "2560x1440@144", position = "2560x0", scale = 1.0, vrr = 2 },
    -- 1.6 makes it 1600x1000 logical, so 5120x440 lines its bottom up with the ASUS's.
    { output = portable, mode = "2560x1600@120", position = "5120x440", scale = 1.6 },
    { output = panel, mode = "2560x1600@240", position = "6720x0", scale = 1.25, vrr = 3 },
  },
  workspaces = workspaces,
  -- Off with the lid shut.
  lid_output = panel,
  -- Games go fullscreen on the ASUS. xrandr takes a connector name, not a desc: the HDMI port
  -- it is on now.
  xwayland_primary = "HDMI-A-1",
  -- Slight transparency so the backdrop blur has something to show through (dGPU only).
  opacity = 0.96,
  -- Direct scanout on the NVIDIA driver marks a fullscreen Vulkan swapchain out of date about once
  -- a second (Sober recreated it 235 times in 15 minutes), which shows as black flashes and stutter.
  direct_scanout = 0,
  -- The VA-API and GLX vendor picks are also in uwsm/env-hyprland, so user services get them.
  env = {
    __GL_GSYNC_ALLOWED = "1",
    LIBVA_DRIVER_NAME = "nvidia",
    NVD_BACKEND = "direct",
    __GLX_VENDOR_LIBRARY_NAME = "nvidia",
  },
}
