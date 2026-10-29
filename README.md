# dotfiles

The [FormalSpec](https://github.com/FormalStudio/formalspec) spec for my three machines:

| Host | What it is | OS |
| --- | --- | --- |
| `macbook` | Always-on dev server, reached over ssh and mosh | macOS |
| `g815` | Compiler, tester, GPU and Windows VM host | openSUSE Tumbleweed |
| `e1504g` | Light client | openSUSE Tumbleweed |

```sh
fspec plan                    # what an apply would change on this machine
fspec apply --host g815       # converge a host, over ssh when it is not this one
fspec update formalshell      # re-resolve one package into fspec.lock
fspec eval --host macbook     # the host as the spec declares it, as JSON
```

## Layout

```
spec.star              the host list
secrets.star           who each secret is encrypted to, and what fish exports
hosts/<host>/
  host.star            the host: system, users, modules
  *.star               its topics (g815: hardware, gaming, windows, rig)
  rootfs/              files for this host only, at their path under /
  home/                files for this host only, at their path under ~
modules/
  linux/               what both Tumbleweed hosts share: packages, store, services
  home/                the Linux user layer: services, apps, KDE, T3 Code, Discord
  boot/                the FormalOS boot theme and its assets
  secrets.star         decrypts secrets.star and writes fish's exports
  sync.star            app data `fspec sync` moves between the Linux pair
lib/                   helpers: paths, tree(), unit shorthands
rootfs/                files both Linux hosts share, at their path under /
home/                  the shared Linux home, at its path under ~
patches/               patches for store packages
docs/                  what the nix config had that this one does not
```

`rootfs/` and `home/` are literal mirrors: a file at `rootfs/etc/pam.d/sudo` lands at
`/etc/pam.d/sudo`, and a host's own `hosts/<host>/rootfs/` file wins over the shared one. To add a
config file, put it at its path; nothing in the `.star` files needs to change. Executables keep
their git mode, so `chmod +x` before committing a script.

## Secrets

Secrets are age files in `secrets/`, encrypted to the keys in `secrets.star`, like agenix. Each
host decrypts them into `/run/fspec/secrets` (`/var/run` on the macbook) on apply and again at
boot. Fish exports the ones listed in `secrets.star`'s `ENV`; nothing secret is committed in
plaintext.

```sh
fspec secret list             # every secret and its recipients
fspec secret edit openai      # decrypt into $EDITOR, re-encrypt on save
fspec secret show openai      # print it
fspec secret rekey            # re-encrypt everything after a recipient change
```

The decrypting identity is `~/.config/age/keys.txt`. Its private key is backed up in 1Password
(item "Agenix (NIX KEY)", field `private key`). To restore it on a new host, run this on the macbook:

```sh
op read "op://Personal/cvynwukplablhw7oc3ouzcma3u/private key" </dev/null \
  | ssh <host> 'umask 077; mkdir -p ~/.config/age; cat > ~/.config/age/keys.txt'
```

To add one: list it in `secrets.star` (under `ENV` to export it), run `fspec secret edit <name>`,
commit the `.age` file and apply.
