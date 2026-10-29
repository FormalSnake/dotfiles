# FormalSpec config

## Hard rule: one shared config, gated per platform and host

DRY and gating beat repetition. That is why this is fspec and not GNU stow.

- Write a thing once, in `modules/`, and gate it. Never copy a file, a package list or a
  block of settings into a second host to vary it.
- Gate with the host facts. A module can be a function of `host` (`host.platform.is_linux`,
  `host.platform.is_darwin`, `host.name`), or take arguments like `linux(host, gaming = True)`.
  The parts that differ become data: a dict keyed by host, a file named after the host, an
  argument.
- A host only gets what it can run. Linux-only things (Stream Deck, the lightbar, FormalShell,
  KDE, systemd units) never land on the macbook, and macOS-only ones never land on Linux.
  Gate them out. Don't fork the module.
- `hosts/<host>/` holds only what truly belongs to that one machine: hardware, its own
  services, its literal files. If two hosts need it, it goes in `modules/` with a gate.
- Example: `modules/fastfetch/fastfetch.star` is one config for every host. Only the logo in
  `logos/<host>.txt` differs.

Before you add something, check whether a shared module already covers it, and extend that.
If you find a duplicate or an ungated platform leak, fold it into the shared module.

## Conventions

- Few comments, short files, data over code.
- Never commit a secret in plaintext. Secrets are age files in `secrets/`. See README.md.
- `fspec eval --host <name>` dumps what a host gets. Use it to check that a gate holds.
