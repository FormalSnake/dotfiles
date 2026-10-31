load("//lib/paths.star", "TUMBLEWEED")

# FormalShell's AirPlay receiver; no Linux release ships it.
AIRPLAY = [
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
]
