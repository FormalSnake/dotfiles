load("//lib/paths.star", "TUMBLEWEED")

GAMING = [
    pkg(
        "proton-ge",
        version = "GE-Proton11-7",
        source = github("GloriousEggroll/proton-ge-custom", asset = "GE-Proton*-x86_64.tar.gz"),
        share = {"steam/compatibilitytools.d/GE-Proton11-7": "GE-Proton11-7-x86_64"},
    ),
    # FormalShell's AirPlay receiver; no Linux release ships it.
    pkg(
        "uxplay",
        source = git(
            "https://github.com/FDH2/UxPlay",
            rev = "df67c212a433cf6dda3676dd40c097900d24e645",
            image = TUMBLEWEED,
            deps = [
                "cmake", "make", "gcc-c++", "pkgconf", "libopenssl-devel", "libplist-2_0-devel",
                "gstreamer-devel", "gstreamer-plugins-base-devel", "avahi-compat-mDNSResponder-devel",
            ],
        ),
        # -march=native on a CI runner emits instructions this CPU lacks.
        build_flags = ["-DNO_MARCH_NATIVE=ON"],
        bins = ["uxplay"],
    ),
    # It replaces its own AppImage to update, so /usr/local/bin/epic-games-launcher seeds a
    # writable copy in the home.
    pkg("epic-games-launcher-appimage", source = url("https://content-download-egs.distro.on.epicgames.com/Builds/EGLv2/0.95.2%2Bgfa9ad49/Linux/EpicGamesLauncher-x86_64.AppImage")),
    pkg("modrinth-app", version = "0.21.6", source = github("modrinth/code", asset = "Modrinth.App_*_amd64.AppImage")),
    pkg("sober", source = flatpak("org.vinegarhq.Sober")),
    pkg("mangohud-vulkan-layer", source = flatpak("org.freedesktop.Platform.VulkanLayer.MangoHud/x86_64/25.08")),
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
