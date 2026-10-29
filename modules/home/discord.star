load("//lib/paths.star", "BIN")
load("//lib/units.star", "oneshot")

# nixpkgs' Discord with moonlight: Discord's own distro tarball, one more per module, and
# moonlight's release dist. The patch moves app.asar aside for moonlight's injector.
VERSION = "1.0.160"
DISTRO = "https://stable.dl2.discordapp.net/distro/app/stable/linux/x64/" + VERSION
MODULES = {
    "discord_cloudsync": 1, "discord_desktop_core": 2, "discord_dispatch": 1, "discord_erlpack": 1,
    "discord_game_utils": 1, "discord_krisp": 1, "discord_modules": 1, "discord_rpc": 1,
    "discord_spellcheck": 1, "discord_sysimg": 1, "discord_utils": 1, "discord_voice": 1, "discord_zstd": 1,
}
PKG = "/opt/fspec/current/pkgs/discord"

# Discord loads its modules from the config dir and would update itself into the read-only store,
# so the modules are links there and the host update is skipped.
LAUNCHER = """#!/bin/sh
conf="${XDG_CONFIG_HOME:-$HOME/.config}/discord"
mods="$conf/%s/modules"
rm -rf "$mods"
mkdir -p "$mods"
for m in %s/modules/*; do
	ln -sn "$m/files" "$mods/${m##*/}"
done
printf '%%s' '%s' >"$mods/installed.json"

# moonlight runs from a writable copy, so moonbase can update it in place and this keeps it on
# the latest release. The packaged dist seeds it and covers a start without network.
dist="${XDG_DATA_HOME:-$HOME/.local/share}/moonlight-mod/dist"
if [ ! -e "$dist/injector.js" ]; then
	mkdir -p "$dist"
	cp -r %s/moonlight/. "$dist"
fi
tag=$(curl -fsSm 3 https://api.github.com/repos/moonlight-mod/moonlight/releases/latest |
	python3 -c 'import json, sys; print(json.load(sys.stdin)["tag_name"])' 2>/dev/null)
if [ -n "$tag" ] && [ "$tag" != "$(cat "$dist/.tag" 2>/dev/null)" ]; then
	rm -rf "$dist.new"
	mkdir -p "$dist.new"
	if curl -fsSLm 30 "https://github.com/moonlight-mod/moonlight/releases/download/$tag/dist.tar.gz" |
		tar -xz -C "$dist.new"; then
		printf '%%s' "$tag" >"$dist.new/.tag"
		rm -rf "$dist.old"
		mv "$dist" "$dist.old"
		mv "$dist.new" "$dist"
		rm -rf "$dist.old"
	fi
	rm -rf "$dist.new"
fi

python3 - "$conf/settings.json" <<'PY'
import json, sys
path = sys.argv[1]
try:
    with open(path) as f:
        settings = json.load(f)
except (OSError, ValueError):
    settings = {}
settings["SKIP_HOST_UPDATE"] = True
with open(path, "w") as f:
    json.dump(settings, f, indent=2)
PY
exec %s/files/Discord ${WAYLAND_DISPLAY:+--ozone-platform=wayland --enable-features=WaylandWindowDecorations --enable-wayland-ime=true} "$@"
""" % (
    VERSION,
    PKG,
    "{" + ",".join(['"%s":{"installedVersion":%d}' % (m, v) for m, v in MODULES.items()]) + "}",
    PKG,
    PKG,
)

DISCORD = [
    pkg(
        "discord",
        source = url(DISTRO + "/full.distro"),
        parts = dict(
            {"modules/%s" % m: url("%s/%s/%d/full.distro" % (DISTRO, m, v)) for m, v in MODULES.items()},
            moonlight = url("https://github.com/moonlight-mod/moonlight/releases/download/v2026.10.0/dist.tar.gz"),
        ),
        patches = ["patches/discord-moonlight.patch"],
        links = {"discord-app": "Discord"},
    ),
    file("~/.local/bin/discord", perms = "0755", content = LAUNCHER),
    # matugen rewrites it on every re-theme; moonlight-css drops a path it cannot stat.
    file("~/.config/moonlight-mod/matugen.css", mode = "seed", content = ""),
    # stable.json carries the Last.fm key, so it renders at login instead of shipping.
    oneshot("moonlight-config", BIN + "/moonlight-config", "Render moonlight's stable.json with the Last.fm key", user = True),
]
