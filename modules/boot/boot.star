# The FormalOS boot look: a silent Limine (any key in its second shows the menu over a centred
# logo; a host with another OS shows it for four), then formalboot's screen: the logo, the
# wordmark, a progress bar and under them the live tree of systemd's jobs, held on screen into
# the greeter. Limine has no boot counting, so its default entry chainloads systemd-boot, which
# counts tries for fspec-boot-guard behind a zero timeout. FormalShell's
# docs/superpowers/specs/2026-10-30-seams.md is the whole chain.

load("//lib/paths.star", "STORE", "TUMBLEWEED")

ASSETS = "modules/boot/"
FORMALBOOT = STORE + "/formalboot"

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
DRACUT = "/usr/lib/dracut/modules.d/90formalboot"

def boot_theme(
        name,
        branding,
        logo,
        wordmark,
        colours,
        palette,
        palette_bright,
        timeout = 1,
        menu_timeout = 4,
        wallpaper_size = "400x560",
        wallpaper_scale = 4,
        preferred = "tumbleweed-*",
        chime = None):
    return {
        "name": name,
        "branding": branding,
        "logo": logo,
        "wordmark": wordmark,
        "colours": colours,
        "palette": palette,
        "palette_bright": palette_bright,
        "timeout": timeout,
        "menu_timeout": menu_timeout,
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
    colours = {"fg": "cecdc3", "muted": "878580", "accent": "879a39", "error": "d14d41", "track": "2a2927", "backdrop": "000000"},
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
        # A host with another OS to boot shows the menu, so picking it needs no key timed into
        # the quiet second.
        "timeout: %d" % (t["menu_timeout"] if entries else t["timeout"]),
        "quiet: %s" % ("no" if entries else "yes"),
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
        ("fg", c["fg"]),
        ("muted", c["muted"]),
        ("error", c["error"]),
        ("track", c["track"]),
        ("fill", c["accent"]),
        ("backdrop", c["backdrop"]),
        ("wallpaper_size", t["wallpaper_size"]),
        ("wallpaper_scale", t["wallpaper_scale"]),
    ]])

# Plays under the boot screen, ahead of the greeter without holding it back.
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
        pkg(
            "formalboot",
            source = git(
                "https://github.com/FormalStudio/formalboot",
                rev = "8a5464cae84dd64e00c5ed4ed8b4ca57fac89041",
                image = TUMBLEWEED,
                deps = ["cargo", "gcc"],
            ),
            build = ["sh", "-c", 'cargo build --release --locked && install -Dm755 target/release/formalboot "$FSPEC_OUT/bin/formalboot"'],
        ),
        # Started in the initrd and carried into the real root: the @ in argv[0] is what keeps
        # systemd from killing it at the switch and at the end of a shutdown, and the real root's
        # copy of the unit is what the state survives into. With no initrd copy it starts here.
        file("/etc/systemd/system/formalboot.service", content = """[Unit]
Description=The boot screen
DefaultDependencies=no
ConditionKernelCommandLine=splash
ConditionVirtualization=!container
IgnoreOnIsolate=yes

[Service]
Type=exec
ExecStart=@%s @formalboot
RemainAfterExit=yes
KillMode=none
SendSIGKILL=no
""" % FORMALBOOT),
        file("/etc/systemd/system/sysinit.target.wants/formalboot.service", mode = "link", target = "/etc/systemd/system/formalboot.service"),
        # After the display manager: a stop and a start ordered either way run the stop first, so
        # the session's compositor has let the card go.
        file("/etc/systemd/system/formalboot-shutdown.service", content = """[Unit]
Description=The shutdown screen
DefaultDependencies=no
ConditionKernelCommandLine=splash
After=getty@tty1.service display-manager.service
Before=systemd-poweroff.service systemd-reboot.service systemd-halt.service systemd-kexec.service

[Service]
Type=exec
ExecStart=@%s @formalboot --shutdown
KillMode=none
SendSIGKILL=no
""" % FORMALBOOT),
    ] + [
        file("/etc/systemd/system/%s.target.wants/formalboot-shutdown.service" % end, mode = "link", target = "/etc/systemd/system/formalboot-shutdown.service")
        for end in ["poweroff", "reboot", "halt", "kexec"]
    ] + [
        file(DRACUT + "/module-setup.sh", src = ASSETS + "dracut-module-setup.sh", perms = "0755"),
        file(DRACUT + "/formalboot-switch-root.service", content = """[Unit]
Description=Take the boot screen into the real root
DefaultDependencies=no
Before=initrd-switch-root.service

[Service]
Type=oneshot
ExecStart=-%s newroot
""" % FORMALBOOT),
        # formalboot is gone before a compositor opens the card. A splash alive under Hyprland's
        # first modeset is the suspected trigger for HDMI-A-1 scanning out to a monitor in standby
        # (2026-10-31, g815, under plymouth), and one that still held the card got Hyprland's
        # TakeDevice an EBUSY (2026-11-05). Quit as greetd started, the screen went before greetd,
        # PAM, uwsm and Hyprland's launcher, ~1s of black on fstestvm, so each compositor a boot
        # can start runs this first: Hyprland from the top of its hyprland.lua, which it reads
        # before opening the card, and the greeter's sway from formalshell-session.sh. `quit`
        # fills the bar, leaves the finished frame up and returns once the process is gone,
        # killing one that never answers.
        file("/etc/systemd/system/formalos-splash-quit.service", content = """[Unit]
Description=End the boot screen before a compositor takes the display
ConditionPathExists=/run/formalboot.pid

[Service]
Type=oneshot
ExecStart=%s quit
""" % FORMALBOOT),
        # Any account: the greeter's and the user manager's processes are in no logind session,
        # and all the unit does is end a screen a compositor is about to cover.
        file("/etc/polkit-1/rules.d/50-formalos-splash-quit.rules", content = """polkit.addRule(function(action, subject) {
  if (action.id == "org.freedesktop.systemd1.manage-units" &&
      action.lookup("unit") == "formalos-splash-quit.service" &&
      action.lookup("verb") == "start") {
    return polkit.Result.YES;
  }
});
"""),
        # The session quits the screen; this only ends one no compositor came to cover. Type=exec,
        # so multi-user.target does not wait out the patience.
        file("/etc/systemd/system/formalos-splash-end.service", content = """[Unit]
Description=End a boot screen no compositor took over
After=display-manager.service
ConditionPathExists=/run/formalboot.pid

[Service]
Type=exec
ExecStart=%s quit --patience 30
""" % FORMALBOOT),
        file("/etc/systemd/system/multi-user.target.wants/formalos-splash-end.service", mode = "link", target = "/etc/systemd/system/formalos-splash-end.service"),
        # fspec-esp-sync writes this header to the ESP with a Kernels submenu under it.
        pkg("limine", source = zypper(), files = [
            file("/etc/fspec/limine.conf", content = _limine_conf(t, entries)),
        ]),
        pkg("efibootmgr", source = zypper()),
        file(ESP + "/loader/loader.conf", content = "timeout 0\nconsole-mode keep\npreferred %s\n" % t["preferred"]),
        file(SRC + "/logo.png", src = t["logo"]),
        file(SRC + "/wordmark.png", src = t["wordmark"]),
        file(SRC + "/theme.env", content = _theme_env(t)),
        # fspec switch builds the root in a container and writes hostonly="no" for that build. Kept
        # on the real machine, every initrd carries all firmware (~290 MB, NVIDIA's GSP alone is
        # 100 MB), and two kernels no longer fit the 1 GB ESP (e1504g, 2026-11-11).
        file("/etc/dracut.conf.d/60-formalos-hostonly.conf", content = 'hostonly="yes"\n'),
        file("/usr/local/libexec/formalos-boot", src = ASSETS + "formalos-boot", perms = "0755"),
        service(
            "formalos-boot",
            exec = "/usr/local/libexec/formalos-boot",
            description = "Render the boot theme and install Limine on the ESP",
            systemd = {"Type": "oneshot", "TimeoutStartSec": "10min", "unit": {"RequiresMountsFor": ESP}},
        ),
        # /opt/fspec, not the `current` link in it: a path unit watches what a link points at, and
        # a new generation is a rename over the link.
        file("/etc/systemd/system/formalos-boot.path", content = """[Unit]
Description=Re-render the boot theme when its sources, dracut's config or Limine change

[Path]
PathChanged=%s
PathChanged=%s
PathChanged=/etc/dracut.conf.d
PathChanged=/opt/fspec
PathChanged=/usr/share/limine/BOOTX64.EFI
Unit=fspec-formalos-boot.service

[Install]
WantedBy=paths.target
""" % (SRC, DRACUT)),
        service("formalos-boot.path"),
    ]

def boot(entries = []):
    return formalos_boot(FORMALOS, entries)
