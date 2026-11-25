load("//lib/paths.star", "TUMBLEWEED")

# FormalShell's AirPlay receiver; no Linux release ships it.
AIRPLAY = [
    pkg(
        "uxplay",
        source = git(
            "https://github.com/FDH2/UxPlay",
            rev = "fbd040e70e754e01fa7e6df810fecd08b6484ada",
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
]
