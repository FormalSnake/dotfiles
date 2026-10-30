# The FormalOS boot look: a silent Limine (any key in its second shows the menu over a centred
# logo), then a plymouth splash with the logo, the wordmark and a progress bar, held on screen into
# the greeter. Limine has no boot counting, so its default entry chainloads systemd-boot, which
# counts tries for fspec-boot-guard behind a zero timeout. FormalShell's
# docs/superpowers/specs/2026-10-30-seams.md is the whole chain.

ASSETS = "modules/boot/"

# Every host's quiet boot. fbcon=vc:2-6 leaves VT1, greetd's, on the dummy console, so nothing a
# session or systemd writes there is ever drawn; tty2 keeps its getty.
QUIET_ARGS = [
    "quiet", "splash", "loglevel=3", "rd.udev.log_level=3", "udev.log_level=3",
    "systemd.show_status=false", "rd.systemd.show_status=false",
    "vt.global_cursor_default=0", "fbcon=vc:2-6",
]
ESP = "/boot/efi"
# Outside /etc, which SUSE's ImageMagick policy refuses to read.
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
        timeout = 1,
        wallpaper_size = "400x560",
        wallpaper_scale = 4,
        preferred = "tumbleweed-*",
        chime = None):
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
        "chime": chime,
    }

def boot_chime(pkg, share, wav):
    """A store package that ships `wav` under /usr/local/share/<share>."""
    return {"pkg": pkg, "path": "/usr/local/share/%s/%s" % (share, wav)}

# Synthesised by chime.py with the stdlib, so the repo carries no binary.
FORMALOS_CHIME = boot_chime(
    pkg(
        "formalos-chime",
        source = git("https://github.com/FormalSnake/dotfiles", rev = "98ca1b6c069b2eb1029cc9b816b735bcc3251202"),
        build = ["sh", "-c", "mkdir -p \"$FSPEC_OUT\" && python3 \"$FSPEC_SRC/modules/nixos/mixins/core/chime/chime.py\" \"$FSPEC_OUT/formalos-chime.wav\""],
        share = {"sounds/formalos-chime": "."},
    ),
    share = "sounds/formalos-chime",
    wav = "formalos-chime.wav",
)

# Flexoki on black with the olive green as the accent. Cyan is the comment line under the menu.
FORMALOS = boot_theme(
    name = "formalos",
    branding = "FormalOS",
    logo = ASSETS + "logo.png",
    wordmark = ASSETS + "wordmark.png",
    splash = ASSETS + "splash.script",
    colours = {"fg": "cecdc3", "accent": "879a39", "track": "2a2927", "backdrop": "000000"},
    palette = "000000;af3029;879a39;ad8301;205ea6;a02f6f;878580;878580",
    palette_bright = "575653;d14d41;a0af54;d0a215;4385be;ce5d97;3aa99f;cecdc3",
    chime = FORMALOS_CHIME,
)

def limine_entry(name, comment, path, protocol = "efi"):
    """A Limine menu entry after the FormalOS one, such as a Windows chainload."""
    return [
        "/" + name,
        "    comment: " + comment,
        "    protocol: " + protocol,
        "    path: " + path,
        "",
    ]

def _limine_conf(t, entries):
    c = t["colours"]
    return "\n".join([
        "timeout: %d" % t["timeout"],
        "quiet: yes",
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
        # ff: fully transparent over the wallpaper.
        "term_background: ff" + c["backdrop"],
        "term_margin: 0",
        "",
        "/" + t["branding"],
        "    comment: The newest kernel that has not failed three boots, through systemd-boot",
        "    protocol: efi",
        "    path: boot():/EFI/systemd/systemd-bootx64.efi",
        "",
    ] + [line for e in entries for line in e])

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

# Plays under the splash, ahead of the greeter without holding it back.
def _chime(c):
    return [
        c["pkg"],
        file("/usr/local/libexec/formalos-boot-chime", src = ASSETS + "formalos-boot-chime", perms = "0755"),
        service(
            "boot-chime",
            exec = "/usr/local/libexec/formalos-boot-chime " + c["path"],
            description = "Boot chime",
            systemd = {
                "Type": "exec",
                # An exited unit is inactive, and apply starts every inactive unit it wants.
                "RemainAfterExit": True,
                "unit": {
                    "DefaultDependencies": False,
                    "Wants": "sound.target",
                    "After": "sound.target",
                    "Before": "display-manager.service",
                },
            },
        ),
    ]

def formalos_boot(t, entries = []):
    return (_chime(t["chime"]) if t["chime"] else []) + [
        pkg("plymouth", source = zypper(), files = [
            file("/etc/plymouth/plymouthd.conf", content = "[Daemon]\nTheme=%s\nShowDelay=0\nDeviceTimeout=8\n" % t["name"]),
        ]),
        pkg("plymouth-plugin-script", source = zypper()),
        # The splash's finished frame stays on screen, plymouthd deactivated, until sway has drawn
        # the same picture over it (formalos-boot's greeter-<s>.png); quitting earlier drops it.
        # Tumbleweed's greetd.service waits for plymouth-quit-wait, which a drop-in cannot take
        # back, so this is the package's unit without that.
        file("/etc/systemd/system/greetd.service", content = """[Unit]
Description=Greeter daemon
After=systemd-user-sessions.service plymouth-start.service
After=getty@tty1.service
Conflicts=getty@tty1.service

[Service]
Type=simple
ExecStartPre=-/usr/bin/plymouth update --status=formalos-done
ExecStartPre=-/usr/bin/sleep 0.15
ExecStartPre=-/usr/bin/plymouth deactivate
ExecStart=greetd
IgnoreSIGPIPE=no
SendSIGHUP=yes
TimeoutStopSec=30s
KeyringMode=shared
Restart=always
RestartSec=1
StartLimitBurst=5
StartLimitInterval=30

[Install]
Alias=display-manager.service
"""),
        file("/etc/systemd/system/plymouth-quit.service.d/formalos-splash.conf", content = """[Unit]
After=display-manager.service

[Service]
ExecStartPre=-/usr/bin/sleep 3
ExecStart=
ExecStart=-/usr/bin/plymouth quit --retain-splash
"""),
        pkg("plymouth-dracut", source = zypper()),
        # fspec-esp-sync writes this header to the ESP with a Kernels submenu under it.
        pkg("limine", source = zypper(), files = [
            file("/etc/fspec/limine.conf", content = _limine_conf(t, entries)),
        ]),
        pkg("efibootmgr", source = zypper()),
        file(ESP + "/loader/loader.conf", content = "timeout 0\nconsole-mode keep\npreferred %s\n" % t["preferred"]),
        file(SRC + "/logo.png", src = t["logo"]),
        file(SRC + "/wordmark.png", src = t["wordmark"]),
        file(SRC + "/splash.script", src = t["splash"]),
        file(SRC + "/theme.env", content = _theme_env(t)),
        file("/usr/local/libexec/formalos-boot", src = ASSETS + "formalos-boot", perms = "0755"),
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

def boot(entries = []):
    return formalos_boot(FORMALOS, entries)
