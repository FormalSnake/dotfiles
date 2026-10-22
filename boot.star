# The FormalOS boot look of ~/.config/nix (modules/nixos/mixins/core/boot.nix and plymouth/):
# Limine's menu over a centred logo, then the plymouth splash with the logo, the wordmark and a
# 13-step progress bar. A theme change is one edit to FORMALOS; the apply re-renders the images,
# rebuilds the initrds and copies them to the ESP.
#
# Limine has no boot counting, so its default entry chainloads systemd-boot, which keeps counting
# tries for fspec-boot-guard and falls through to the next entry after three failed boots.
# systemd-boot's own menu stays hidden behind a zero timeout; a key held at its start shows it.

ROOTFS = "e1504g/rootfs/"
ESP = "/boot/efi"
# Openly readable for magick: SUSE's ImageMagick policy denies every path under /etc.
SRC = "/usr/local/share/formalos-boot"

def boot_theme(
        name,
        branding,
        logo,
        wordmark,
        splash,
        colours,
        palette,
        palette_bright,
        timeout = 4,
        wallpaper_size = "400x560",
        wallpaper_scale = 4,
        preferred = "tumbleweed-*"):
    return {
        "name": name,
        "branding": branding,
        "logo": logo,
        "wordmark": wordmark,
        "splash": splash,
        "colours": colours,
        "palette": palette,
        "palette_bright": palette_bright,
        "timeout": timeout,
        "wallpaper_size": wallpaper_size,
        "wallpaper_scale": wallpaper_scale,
        "preferred": preferred,
    }

# Flexoki on black, with the olive progress-bar green as the accent. Limine's built-in font is
# IBM VGA 8x16, the face the blog uses for its NT stop screen.
FORMALOS = boot_theme(
    name = "formalos",
    branding = "FormalOS",
    logo = ROOTFS + "usr/share/formalos-boot/logo.png",
    wordmark = ROOTFS + "usr/share/formalos-boot/wordmark.png",
    splash = ROOTFS + "usr/share/formalos-boot/splash.script",
    colours = {"fg": "cecdc3", "accent": "879a39", "track": "2a2927", "backdrop": "000000"},
    # Cyan is the comment line under the menu.
    palette = "000000;af3029;879a39;ad8301;205ea6;a02f6f;878580;878580",
    palette_bright = "575653;d14d41;a0af54;d0a215;4385be;ce5d97;3aa99f;cecdc3",
)

def _limine_conf(t):
    c = t["colours"]
    return "\n".join([
        "timeout: %d" % t["timeout"],
        "editor_enabled: no",
        "graphics: yes",
        "wallpaper: boot():/EFI/limine/%s.png" % t["name"],
        "wallpaper_style: centered",
        "backdrop: " + c["backdrop"],
        "interface_branding: " + t["branding"],
        "interface_branding_colour: " + c["fg"],
        "interface_help_colour: " + c["accent"],
        "interface_help_colour_bright: " + c["fg"],
        "interface_help_hidden: yes",
        "term_font_scale: 2x2",
        "term_palette: " + t["palette"],
        "term_palette_bright: " + t["palette_bright"],
        "term_foreground: " + c["fg"],
        # TT=ff: fully transparent over the wallpaper.
        "term_background: ff" + c["backdrop"],
        "term_margin: 0",
        "",
        "/" + t["branding"],
        "    comment: The newest kernel that has not failed three boots, through systemd-boot",
        "    protocol: efi",
        "    path: boot():/EFI/systemd/systemd-bootx64.efi",
        "",
    ])

def _theme_env(t):
    c = t["colours"]
    return "".join(["%s=%s\n" % kv for kv in [
        ("name", t["name"]),
        ("branding", t["branding"]),
        ("track", c["track"]),
        ("fill", c["accent"]),
        ("backdrop", c["backdrop"]),
        ("wallpaper_size", t["wallpaper_size"]),
        ("wallpaper_scale", t["wallpaper_scale"]),
    ]])

def formalos_boot(t):
    return [
        pkg("plymouth", source = zypper(), files = [
            file("/etc/plymouth/plymouthd.conf", content = "[Daemon]\nTheme=%s\nShowDelay=0\nDeviceTimeout=8\n" % t["name"]),
        ]),
        pkg("plymouth-plugin-script", source = zypper()),
        pkg("plymouth-dracut", source = zypper()),
        pkg("limine", source = zypper(), files = [
            # Next to the EFI app, which Limine reads before /limine/limine.conf.
            file(ESP + "/EFI/limine/limine.conf", content = _limine_conf(t)),
        ]),
        pkg("efibootmgr", source = zypper()),
        file(ESP + "/loader/loader.conf", content = "timeout 0\nconsole-mode keep\npreferred %s\n" % t["preferred"]),
        file(SRC + "/logo.png", src = t["logo"]),
        file(SRC + "/wordmark.png", src = t["wordmark"]),
        file(SRC + "/splash.script", src = t["splash"]),
        file(SRC + "/theme.env", content = _theme_env(t)),
        file("/usr/local/libexec/formalos-boot", src = ROOTFS + "usr/libexec/formalos-boot", perms = "0755"),
        # magick comes from ImageMagick in system.star's CLI packages.
        service(
            "formalos-boot",
            exec = "/usr/local/libexec/formalos-boot",
            description = "Render the boot theme and install Limine on the ESP",
            systemd = {"Type": "oneshot", "TimeoutStartSec": "10min", "unit": {"RequiresMountsFor": ESP}},
        ),
        file("/etc/systemd/system/formalos-boot.path", content = """[Unit]
Description=Re-render the boot theme when its sources or Limine change

[Path]
PathChanged=%s
PathChanged=/etc/plymouth/plymouthd.conf
PathChanged=/usr/share/limine/BOOTX64.EFI
Unit=fspec-formalos-boot.service

[Install]
WantedBy=paths.target
""" % SRC),
        service("formalos-boot.path"),
    ]

def boot(h = None):
    return formalos_boot(FORMALOS)
