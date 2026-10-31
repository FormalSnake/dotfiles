load("//lib/tree.star", "tree")
load("//lib/units.star", "oneshot")

# Steam, launchers and frame pacing for a Linux gaming host. docs/gaming.md has the commands.

# Distro packages, for the host's system list. The -32bit libraries are what 32-bit games load
# through gamemoderun and mangohud.
GAMING_PACKAGES = [
    "steam", "steam-devices", "gamescope", "gamescope-session-steam", "gamemode",
    "libgamemodeauto0-32bit", "mangohud", "mangohud-32bit", "heroic-games-launcher",
    "protontricks", "prismlauncher", "java-21-openjdk",
]

PROTON_GE = "GE-Proton11-7"

def _env(fps):
    return "\n".join([
        "__GL_SHADER_DISK_CACHE_SIZE=10737418240",
        "__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1",
        # Always on for D3D games, under the VRR ceiling so the panel never falls back to vsync.
        "DXVK_FRAME_RATE=%d" % fps,
        "VKD3D_FRAME_RATE=%d" % fps,
        "DXVK_CONFIG_FILE=/etc/dxvk.conf",
        # DLSS and Reflex on NVIDIA.
        "PROTON_ENABLE_NVAPI=1",
        "STEAM_EXTRA_COMPAT_TOOLS_PATHS=/usr/local/share/steam/compatibilitytools.d",
        "",
    ])

def _mangohud(fps):
    return "\n".join([
        # A compact strip with the active cap; Shift_R+F12 hides it.
        "horizontal",
        "hud_compact",
        "show_fps_limit",
        "toggle_hud=Shift_R+F12",
        # early holds the frametime flat at the cost of a frame of latency.
        "fps_limit=%d,120,90,72,60,0" % fps,
        "fps_limit_method=early",
        "toggle_fps_limit=Shift_L+F1",
        "gpu_temp",
        "cpu_temp",
        "frametime",
        "frame_timing",
        "position=top-left",
        "",
    ])

def gaming(fps):
    """`fps` is the cap, a few frames under the display's VRR ceiling."""
    return tree(["modules/gaming/rootfs/"]) + [
        file("/etc/environment.d/80-gaming.conf", content = _env(fps)),
        # Games run in Steam's runtime container, which has its own /etc but sees the home.
        file("~/.config/MangoHud/MangoHud.conf", content = _mangohud(fps)),
        pkg(
            "proton-ge",
            version = PROTON_GE,
            source = github("GloriousEggroll/proton-ge-custom", asset = "GE-Proton*-x86_64.tar.gz"),
            share = {"steam/compatibilitytools.d/" + PROTON_GE: PROTON_GE + "-x86_64"},
        ),
        # It replaces its own AppImage to update, so /usr/local/bin/epic-games-launcher seeds a
        # writable copy in the home.
        pkg("epic-games-launcher-appimage", source = url("https://content-download-egs.distro.on.epicgames.com/Builds/EGLv2/0.95.2%2Bgfa9ad49/Linux/EpicGamesLauncher-x86_64.AppImage")),
        pkg("modrinth-app", version = "0.21.6", source = github("modrinth/code", asset = "Modrinth.App_*_amd64.AppImage")),
        pkg("sober", source = flatpak("org.vinegarhq.Sober")),
        pkg("mangohud-vulkan-layer", source = flatpak("org.freedesktop.Platform.VulkanLayer.MangoHud/x86_64/25.08")),
        pkg("adwsteamgtk", source = flatpak("io.github.Foldex.AdwSteamGtk")),
        oneshot("adwsteam-repatch", "/usr/local/libexec/adwsteam-repatch", "Reapply Adwaita-for-Steam", user = True, remain = False),
        file("~/.config/systemd/user/adwsteam-repatch.path", content = """[Unit]
Description=Reapply Adwaita-for-Steam after a Steam update

[Path]
PathChanged=%h/.local/share/Steam/steamui/css/library.css
Unit=fspec-adwsteam-repatch.service

[Install]
WantedBy=default.target
"""),
        service("adwsteam-repatch.path", user = True),
        # NVENC capture with a replay buffer; Alt+Z opens its overlay.
        pkg("gpu-screen-recorder", source = flatpak("com.dec05eba.gpu_screen_recorder")),
        # Plasma is the gaming desktop: Steam opens with it.
        service(
            "steam",
            exec = "/usr/bin/steam",
            user = True,
            description = "Steam",
            systemd = {
                "unit": {"ConditionEnvironment": "XDG_CURRENT_DESKTOP=KDE", "PartOf": "graphical-session.target", "After": "graphical-session.target", "RefuseManualStart": True, "RefuseManualStop": True},
                "install": {"WantedBy": "graphical-session.target"},
            },
        ),
    ]
