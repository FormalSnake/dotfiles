load("//g815.star", G815_PACKAGES = "PACKAGES", "g815")
load("//home.star", "home")
load("//system.star", "E1504G_PACKAGES", "PACKAGES", "system")

# Kyan's Linux hosts, ported from ~/.config/nix. Both run openSUSE Tumbleweed (the e1504g beside its
# NixOS root); GAPS.md lists what is not ported and why.

# agenix's secrets (the same .age files as ~/.config/nix/secrets, recipients in secrets.star),
# decrypted into /run like /run/agenix, and again at boot by fspec-secrets. They are encrypted to
# the `kyan` age key only, so the identities are agenix's identityPaths from the NixOS config.
SECRETS = ["openai", "anthropic", "gemini", "deepseek", "nucleo-license", "npm-github-token",
           "npm-registry-token", "wstunnel-path-prefix", "wstunnel-endpoint", "couchdb-admin",
           "lastfm-api-key"]

def secrets():
    return [
        secret(
            "/run/fspec/secrets/" + n,
            src = "secrets/%s.age" % n,
            owner = "kyandesutter:users",
            identities = ["/etc/ssh/ssh_host_ed25519_key", "~/.config/age/keys.txt"],
        )
        for n in SECRETS
    ] + [
        service(
            "secrets",
            exec = "/usr/local/bin/fspec secret install",
            description = "Decrypt fspec's secrets into /run/fspec/secrets",
            systemd = {"Type": "oneshot", "RemainAfterExit": True, "unit": {"Before": "systemd-user-sessions.service"}},
        ),
    ]

GROUPS = ["wheel", "video", "audio", "input", "docker", "uinput", "i2c", "nordvpn", "ancs4linux"]

# The e1504g builds what CI has not on the g815 (nix's buildMachines with max-jobs 0), over the
# tailnet, then the LAN.
e1504g = host(
    name = "e1504g",
    platform = "x86_64-linux",
    system = tumbleweed(packages = PACKAGES + E1504G_PACKAGES),
    users = [user("kyandesutter", uid = 1000, shell = "fish", groups = GROUPS)],
    builders = [builder("g815", routes = ["g815", "192.168.86.95"])],
    modules = secrets() + [system, home],
)

g815 = host(
    name = "g815",
    platform = "x86_64-linux",
    system = tumbleweed(packages = PACKAGES + G815_PACKAGES),
    users = [user("kyandesutter", uid = 1000, shell = "fish", groups = GROUPS + ["gamemode"])],
    modules = secrets() + [system, home, g815],
)

hosts = [e1504g, g815]
