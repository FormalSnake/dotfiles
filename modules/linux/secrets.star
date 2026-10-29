load("//lib/paths.star", "USER")
load("//modules/secrets.star", "secrets")

def linux_secrets(host):
    """secrets.star's files in /run/fspec/secrets, decrypted again at every boot."""
    return secrets(
        host,
        dir = "/run/fspec/secrets",
        owner = USER + ":users",
        identities = ["/etc/ssh/ssh_host_ed25519_key", "~/.config/age/keys.txt"],
    ) + [service(
        "secrets",
        exec = "/usr/local/bin/fspec secret install",
        description = "Decrypt fspec's secrets into /run/fspec/secrets",
        systemd = {"Type": "oneshot", "RemainAfterExit": True, "unit": {"Before": "systemd-user-sessions.service"}},
    )]
