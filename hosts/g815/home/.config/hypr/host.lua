-- The g815: the ASUS PA278CGV on the left, the internal 240 Hz panel on the right, both scanned
-- out by the RTX 5070. Both are matched by desc: the panel's connector name follows the driver,
-- and the ASUS has been on HDMI-A-1 and on USB-C DisplayPort (DP-3).
local panel = "desc:BOE NE180QDM-NZC"
local desk = "desc:ASUSTek COMPUTER INC PA278CGV T1LMQS063802"
local workspaces = {}
for i = 1, 9 do
  workspaces[i] = { monitor = (i == 4 or i == 8) and panel or desk, default = (i == 1 or i == 4) }
end
return {
  -- vrr = 1 on the ASUS over HDMI-A-1 came up black at boot: the link trains, EDID and ELD read fine, the CRTC
  -- goes active at 144, and no picture ever lands. 3 holds VRR off until a fullscreen game or
  -- video asks for it.
  -- Hyprland lays XWayland's outputs out in connection order, so the panel (always first) is at
  -- x 0 there. Starting the ASUS at 2560 puts it at the same coordinates in both layouts, which is
  -- what keeps fullscreen Wine games on it from sizing themselves to the panel.
  monitors = {
    { output = desk, mode = "2560x1440@144", position = "2560x0", scale = 1.0, vrr = 3 },
    { output = panel, mode = "2560x1600@240", position = "5120x0", scale = 1.25, vrr = 3 },
  },
  workspaces = workspaces,
  -- Off with the lid shut, its workspaces moving to the ASUS.
  lid_output = panel,
  -- Games go fullscreen on the ASUS. xrandr takes a connector name, not a desc: the USB-C
  -- DisplayPort it is on now.
  xwayland_primary = "DP-3",
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
