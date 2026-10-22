load("//boot.star", "boot")
load("//home.star", "home")
load("//system.star", "PACKAGES", "system")

# Kyan's Linux hosts, ported from ~/.config/nix. The e1504g runs openSUSE Tumbleweed beside its
# NixOS root; GAPS.md lists what is not ported and why.

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

e1504g = host(
    name = "e1504g",
    platform = "x86_64-linux",
    system = tumbleweed(packages = PACKAGES),
    users = [user("kyandesutter", uid = 1000, shell = "fish", groups = ["wheel", "video", "audio", "input", "docker", "uinput", "i2c", "nordvpn"])],
    modules = secrets() + [system, home, boot],
)

hosts = [e1504g]
