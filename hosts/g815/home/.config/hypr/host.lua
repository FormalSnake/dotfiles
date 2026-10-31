-- The g815: HDMI-A-1 on the left, the internal 240 Hz panel (matched by desc, since its connector
-- name follows the driver) on the right, both scanned out by the RTX 5070.
local panel = "desc:BOE NE180QDM-NZC"
local workspaces = {}
for i = 1, 9 do
  workspaces[i] = { monitor = (i == 4 or i == 8) and panel or "HDMI-A-1", default = (i == 1 or i == 4) }
end
return {
  -- vrr = 1 on HDMI-A-1 comes up black at boot: the link trains, EDID and ELD read fine, the CRTC
  -- goes active at 144, and no picture ever lands. 3 holds VRR off until a fullscreen game or
  -- video asks for it.
  monitors = {
    { output = "HDMI-A-1", mode = "2560x1440@144", position = "0x0", scale = 1.0, vrr = 3 },
    { output = panel, mode = "2560x1600@240", position = "2560x0", scale = 1.25, vrr = 3 },
  },
  workspaces = workspaces,
  -- Games go fullscreen on the HDMI monitor.
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
