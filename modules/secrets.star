load("//secrets.star", "ENV", "FILES")

# Hosts a secret is limited to; the rest go everywhere.
ONLY = {"livesync-passphrase": ["macbook"]}

def secrets(host, dir, owner, identities):
    """Every secret in secrets.star decrypted into `dir`, and a fish conf.d file exporting ENV."""
    names = [n for n in list(ENV) + FILES if host in ONLY.get(n, [host])]
    out = [
        secret(dir + "/" + n, src = "secrets/%s.age" % n, owner = owner, identities = identities)
        for n in names
    ]
    exports = ["test -r %s/%s; and set -gx %s (cat %s/%s)" % (dir, n, var, dir, n) for n, var in ENV.items() if n in names]
    out.append(file("~/.config/fish/conf.d/fspec-secrets.fish", content = "\n".join(exports) + "\n"))
    return out
