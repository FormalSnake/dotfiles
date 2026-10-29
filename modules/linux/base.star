load("//lib/paths.star", "LIBEXEC", "STORE")
load("//lib/tree.star", "tree")
load("//lib/units.star", "oneshot")

GROUPS = ["wheel", "video", "audio", "input", "docker", "uinput", "i2c", "nordvpn", "ancs4linux"]

# Both vendors document these baseurls for openSUSE. fspec imports a key only when its
# fingerprint matches.
REPOS = [
    repo(
        "1password",
        url = "https://downloads.1password.com/linux/rpm/stable/x86_64",
        key = "https://downloads.1password.com/linux/keys/1password.asc",
        fingerprint = "3FEF9748469ADBE15DA7CA80AC2D62742012EA22",
    ),
    repo(
        "nordvpn",
        url = "https://repo.nordvpn.com/yum/nordvpn/centos/x86_64",
        key = "https://repo.nordvpn.com/gpg/nordvpn_public.asc",
        fingerprint = "BC5480EFEC5C081CE5BCFBE26B219E535C964CA1",
    ),
]

# sshd, syncthing, LocalSend, UxPlay and mDNS. The tailnet is trusted (rootfs/etc/firewalld).
FIREWALL_TCP = [22, 7000, 7001, 7100, 22000, 53317]
FIREWALL_UDP = [5353, 6000, 6001, 7011, 22000, 53317]

def firewall(tcp = [], udp = [], udp_ranges = []):
    ports = ['  <port protocol="tcp" port="%d"/>' % p for p in FIREWALL_TCP + tcp]
    ports += ['  <port protocol="udp" port="%d"/>' % p for p in FIREWALL_UDP + udp]
    ports += ['  <port protocol="udp" port="%s"/>' % r for r in udp_ranges]
    return file("/etc/firewalld/zones/public.xml", content = "\n".join([
        '<?xml version="1.0" encoding="utf-8"?>',
        "<zone>",
        "  <short>Public</short>",
    ] + ports + ["</zone>", ""]))

def rootfs(host):
    """rootfs/ and hosts/<host>/rootfs/, each a mirror of /."""
    return tree(["rootfs/", "hosts/%s/rootfs/" % host], perms = {"/etc/sudoers.d/10-fspec": "0440"})

FILES = [
    file("/etc/localtime", mode = "link", src = "/usr/share/zoneinfo/Atlantic/Canary"),
    # A migration runbook writes this passwordless grant for the first apply.
    file("/etc/sudoers.d/99-first-apply", mode = "absent"),
    # ananicy-cpp reads only /etc/ananicy.d. The target arrives with ananicy-rules, later in the apply.
    file("/etc/ananicy.d", mode = "link", target = "/usr/local/share/ananicy-rules/cachyos"),
]

SERVICES = [service(s) for s in [
    "tailscaled", "sshd", "bluetooth", "chronyd", "irqbalance", "avahi-daemon", "cups-browsed",
    "earlyoom", "firewalld", "scx", "usbflux-export.socket", "formalshell-greeter-mirror.path",
    "tuned", "tuned-ppd", "docker.socket", "syncthing@kyandesutter",
]] + [
    oneshot("hwdb", "/usr/bin/systemd-hwdb update", "Compile /etc/udev/hwdb.d"),
    # Tumbleweed boots to multi-user.target, under which greetd never starts.
    service("greetd", display_manager = True),
    service(
        "formalshell-power-poll",
        exec = LIBEXEC + "/formalshell-power-poll",
        restart = "on_failure",
        description = "FormalShell USB-C and CPU power readings for the Power panel",
        systemd = {"RuntimeDirectory": "formalshell", "RuntimeDirectoryMode": "0755"},
    ),
    service(
        "ancs4linux-observer",
        exec = STORE + "/ancs4linux-observer",
        description = "ancs4linux Observer daemon (ANCS notifications over BLE)",
        systemd = {"Type": "dbus", "BusName": "ancs4linux.Observer", "unit": {"Requires": "bluetooth.service", "After": "bluetooth.service", "ConditionPathExists": STORE + "/ancs4linux-observer"}},
    ),
    service(
        "ancs4linux-advertising",
        exec = STORE + "/ancs4linux-advertising",
        description = "ancs4linux Advertising daemon (BLE pairing)",
        systemd = {"Type": "dbus", "BusName": "ancs4linux.Advertising", "unit": {"Requires": "bluetooth.service", "After": "bluetooth.service", "ConditionPathExists": STORE + "/ancs4linux-advertising"}},
    ),
    service(
        "ananicy-cpp",
        exec = STORE + "/ananicy-cpp start",
        restart = "always",
        description = "Ananicy-Cpp - ANother Auto NICe daemon in C++",
        systemd = {
            "ExecReload": STORE + "/ananicy-cpp --reload",
            "Nice": -5,
            "SuccessExitStatus": 143,
            "OOMScoreAdjust": -999,
            "RestartSec": 10,
            "MemoryHigh": "16M",
            "MemoryMax": "64M",
            "unit": {"After": "local-fs.target", "ConditionPathExists": STORE + "/ananicy-cpp"},
        },
    ),
    oneshot(
        "nordvpn-settings",
        LIBEXEC + "/nordvpn-settings",
        "Enforce declarative NordVPN settings (allowlist, LAN discovery)",
        Group = "nordvpn",
        Environment = "HOME=/root",
        unit = {"After": "nordvpnd.service", "Requires": "nordvpnd.service"},
    ),
    oneshot(
        "tailscale-nordvpn-routing",
        LIBEXEC + "/tailscale-nordvpn-routing",
        "Route Tailscale's marked underlay through the NordVPN tunnel",
        unit = {"After": ["nordvpnd.service", "tailscaled.service"], "Wants": "tailscaled.service"},
    ),
    timer("docker-prune", exec = "/usr/bin/docker system prune -f --all --filter until=72h", schedule = "0 0 * * *"),
    timer("fspec-gc", exec = "/usr/local/bin/fspec gc --older-than 14d", schedule = "30 0 * * *"),
]

# Hourly, since a day of agent builds can eat 35 GB. `low_free_gb` is where Chromium's
# storage-pressure bubble starts on a small root.
def storage_gc(low_free_gb = None):
    env = {"LOW_FREE_GB": str(low_free_gb)} if low_free_gb else {}
    return timer("storage-gc", exec = LIBEXEC + "/storage-gc --apply --prune-worktrees", schedule = "0 * * * *", user = True, env = env)

def swapfile():
    """The 16 GB swapfile in @swap behind zram; swap.mount is per host."""
    return [service("swap.mount"), service("swap-swapfile.swap")]
