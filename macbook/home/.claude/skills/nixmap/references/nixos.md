# NixOS

## NixOS

NixOS is a Linux distribution you configure declaratively. Programs, users, services,
the desktop and even the bootloader are all set in one file,
`/etc/nixos/configuration.nix`, and NixOS builds the whole system from it.

On most distributions you set up a machine one command at a time. On Ubuntu,
that could look like this:

- `sudo hostnamectl set-hostname nixos`

- `sudo timedatectl set-timezone Europe/Kyiv`

- `sudo apt install cups`

- `sudo apt install firefox`

A year later nobody remembers which commands ran. On NixOS the same machine is
a few lines in one file, and the installer writes it for you:

`configuration.nix`:

```nix
{
  networking.hostName = "nixos"; # Define your hostname.

  # Set your time zone.
  time.timeZone = "Europe/Kyiv";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Install firefox.
  programs.firefox.enable = true;
}
```

Unlike those commands, this file is the record. Copy it to a new machine and
you get the same system.

Each line sets an option. In
`time.timeZone = "Europe/Kyiv";`, `time.timeZone` is the setting and
`"Europe/Kyiv"` is its value. The semicolon ends the line.

Hover a name to read its documentation. To find more options, search
search.nixos.org.

To change the machine, you change a value and run
`sudo nixos-rebuild switch`. The output is cut down to `…` here:

```console
$ sudo nixos-rebuild switch
[sudo] password for yurii:
building the system configuration...
…
activating the configuration...
…
Done. The new configuration is /nix/store/…-nixos-system-nixos-26.05.11045.774debe7a0d1
```

NixOS builds the new system next to the old one and switches to it. The old
one stays in the boot menu. Meaning a bad change is always one reboot away
from being undone.

NixOS knows every option it offers and what kind of value each one
takes. So a misspelled name or a wrong value stops the rebuild with an error
instead of being quietly ignored. Write `programs.firefox.enabel`, and the
rebuild stops with “The option `programs.firefox.enabel’ does not exist”.

### Try it

This machine has no time zone yet. Add `time.timeZone = "Europe/Kyiv";` under the `networking.hostName` line, then change `Europe/Kyiv` to your own city, like `America/New_York`.

- Set `time.timeZone`configuration.nixNixOS moduleA NixOS module.

```nix
{
  networking.hostName = "nixos";
}
```

This configuration doesn't build. Read the error in the editor, then change `enabel` to `enable`.

- Set `programs.firefox.enable` to `true`configuration.nixNixOS moduleA NixOS module.

```nix
{
  programs.firefox.enabel = true;
}
```

## configuration.nix

On NixOS, your whole system is described in one file,
`/etc/nixos/configuration.nix`. When you install NixOS, the installer writes
this file for you from the choices you make there, like the language, time
zone, user and desktop. It belongs to root, so you edit it with
`sudoedit /etc/nixos/configuration.nix`.

It’s about 120 lines long, but half of them are comments starting with `#`.
Here is its top and a few of the options:

`configuration.nix`:

```nix
# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  networking.hostName = "nixos"; # Define your hostname.

  # Set your time zone.
  time.timeZone = "Europe/Kyiv";

  # Install firefox.
  programs.firefox.enable = true;
}
```

The `{ config, pkgs, ... }:` line is there because `configuration.nix` is
just a function with a set argument. During a
rebuild, NixOS calls it with a set of arguments, `config`, `pkgs`, `lib` and a
few more, and the attribute set it returns holds your options. This also
explains the names at the top: asking for `pkgs` there is how the file gets
access to packages.

The `imports` list pulls in `hardware-configuration.nix`, the second file the
installer wrote.

The `...` at the end of the header is there because NixOS passes more
arguments than the file asks for. Without it, the rebuild stops with an
unexpected argument error.

### Try it

This header has no `...`, so NixOS cannot call it with its extra arguments. Change `{ config, pkgs }:` to `{ config, pkgs, ... }:`.

- NixOS can call the fileconfiguration.nixNixOS moduleA NixOS module.

```nix
{ config, pkgs }:

{
  networking.hostName = "nixos";
}
```

## nixos-rebuild

Saving `configuration.nix` doesn’t change anything on the running machine. The
file is only a description, and `nixos-rebuild` is the command that turns it
into a system. It reads your configuration and builds what it describes,
downloading ready-made packages where it can. Then it switches to the new
system.

Most of the time you run `sudo nixos-rebuild switch`. It builds the new system
and switches to it right away, restarting whatever services changed. It also
makes it the default entry in the boot menu. The previous system stays in the
boot menu too. Meaning a bad change is one reboot away from undone.

Here it ran with nothing changed since the last build, so there was nothing to
download or build:

```console
$ sudo nixos-rebuild switch
[sudo] password for yurii:
building the system configuration...
Checking switch inhibitors... done
activating the configuration...
setting up /etc...
reloading user units for yurii...
restarting the following user units: nixos-activation.service
restarting sysinit-reactivation.target
the following new units were started: NetworkManager-dispatcher.service, sysinit-reactivation.target, systemd-tmpfiles-resetup.service
Done. The new configuration is /nix/store/…-nixos-system-nixos-26.05.11045.774debe7a0d1
```

Now add `vim` and `git` to the configuration:

`configuration.nix`:

```nix
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [ vim git ];
}
```

This time the output first lists what it will build and what it will fetch
from `https://cache.nixos.org`. Then it copies and builds them. Long lists are
cut down to `…` here:

```console
$ sudo nixos-rebuild switch
[sudo] password for yurii:
building the system configuration...
these 16 derivations will be built:
  /nix/store/…-system-path.drv
  …
  /nix/store/…-nixos-system-nixos-26.05.11045.774debe7a0d1.drv
these 19 paths will be fetched (38.9 MiB download, 116.4 MiB unpacked):
  /nix/store/…-git-2.54.0
  …
  /nix/store/…-vim-9.2.0541
  …
copying path '/nix/store/…-vim-9.2.0541' from 'https://cache.nixos.org'...
…
copying path '/nix/store/…-git-2.54.0' from 'https://cache.nixos.org'...
building '/nix/store/…-system-path.drv'...
…
building '/nix/store/…-nixos-system-nixos-26.05.11045.774debe7a0d1.drv'...
…
Done. The new configuration is /nix/store/…-nixos-system-nixos-26.05.11045.774debe7a0d1
```

Two packages turn into 19 downloads, because Git brings along the Perl
libraries it needs. The 16 builds are the new system itself, like the list of
installed programs and the files in `/etc`.

Now make a typo, `programs.gti.enable = true;`, and run it again:

```console
$ sudo nixos-rebuild switch
[sudo] password for yurii:
error:
       …
       error: The option `programs.gti' does not exist. Definition values:
       - In `/etc/nixos/configuration.nix':
           {
             enable = true;
           }
       Did you mean `programs.git' or `programs.mtr'?
Command 'nix-build '<nixpkgs/nixos>' --attr config.system.build.nixos-rebuild --no-out-link' returned non-zero exit status 1.
```

The failed rebuild changed nothing. Your running system stays exactly as it was,
because `switch` only activates a system once it’s fully built.

And a plain rebuild doesn’t update anything. It uses the same
nixpkgs as last time, so your package versions stay
exactly where they were until you update nixpkgs itself. To update, run
`sudo nixos-rebuild switch --upgrade`. If your system is a flake, run
`nix flake update` first instead.

`switch` has three common siblings:

- `boot` makes the new system the boot default, but keeps the current one running until you reboot. That’s handy for a new kernel, which needs a reboot anyway.

- `test` switches to it right now, but adds no boot entry. Meaning a reboot brings back the previous system.

- `build` only builds it, and leaves a `result` link in the current directory. It doesn’t even need `sudo`.

If your system lives in a flake, add `--flake` and the directory, like
`sudo nixos-rebuild switch --flake ~/nixos-config`.

## Generations

Say an update broke your Wi-Fi. On NixOS you just go back to the system you
had yesterday, because every system you build is kept as a generation.

Every time `nixos-rebuild switch` or `boot` builds a system that differs from
the last one, NixOS keeps it as a new generation, numbered one after another.
A generation is just a link in `/nix/var/nix/profiles` named `system-1-link`,
`system-2-link` and so on, pointing at that system in the Nix store. One more
link there, `system`, points at the current generation.

Here is a machine that has been rebuilt a few hundred times:

```console
$ ls /nix/var/nix/profiles | tail -3
system-573-link
system-574-link
system-575-link
$ readlink /nix/var/nix/profiles/system
system-575-link
```

`nixos-rebuild list-generations` shows the same generations, newest first,
with the date each one was built:

```console
$ nixos-rebuild list-generations | head -3
Generation  Build-date           NixOS version           Kernel  Configuration Revision                    Specialisation  Current
575         2026-10-10 14:49:13  26.11.20260923.4975466  7.2.7   16611a3a803e19cae24bdf7f5e93440656c33dfa  []              True
574         2026-10-08 21:43:03  26.11.20260923.4975466  7.2.7   46b9262674ecc5f0a151bd5385dec51a3c9e6cfc  []              False
```

Each generation also shows up in the boot menu, so you can pick an older one
when you start the computer.

To go back without rebooting, run `sudo nixos-rebuild switch --rollback`. It
points `system` back at the link before it and switches to that system. The
activation output is cut down to `…` here:

```console
$ sudo nixos-rebuild switch --rollback
building the system configuration...
switching profile from version 575 to 574
Checking switch inhibitors... done
activating the configuration...
…
$ readlink /nix/var/nix/profiles/system
system-574-link
```

Meaning generation 574 also boots by default from now on.

Rolling back doesn’t delete the newer generation. So the next rebuild after a
rollback gets a number above it, not the one after the generation you went
back to.

Old generations stay until you delete them.
`sudo nix-collect-garbage --delete-older-than 30d` deletes the ones older than
30 days, except the one that was current back then, and frees the
store paths only they were using.

Generations only cover the system, not your data. The files in your home
directory stay as they are, whichever generation you boot.

## environment.systemPackages

The first thing you usually do on a fresh system is install some programs. On
NixOS, that’s the `environment.systemPackages` option: a
list of packages that every user on the machine gets.
The file the installer writes already has it, commented out. Remove the `#`
from those lines and it looks like this:

`configuration.nix`:

```nix
{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
  ];
}
```

The `with pkgs;` in front lets you skip the `pkgs.` prefix. Here’s the plain
list next to the short one:

```nix
[ pkgs.vim pkgs.wget ] == (with pkgs; [ vim wget ])
```

They’re the same list.

On most distros you run `apt install vim`, and the system remembers it
somewhere. Here the list is the whole story. Run `sudo nixos-rebuild switch`,
and `vim` and `wget` are in everyone’s terminal. Take a name out, rebuild, and
it’s gone again.

To find a package’s name, search
search.nixos.org.

Some programs also have an enable option, like
`programs.git.enable`. These two both install Git:

`configuration.nix`:

```nix
{ config, pkgs, ... }:

{
  environment.systemPackages = [ pkgs.git ];
}
```

`configuration.nix`:

```nix
{ config, pkgs, ... }:

{
  programs.git.enable = true;
  programs.git.config.init.defaultBranch = "main";
}
```

The second one also lets NixOS set Git up for you, like the default branch
name here. So if a program has an enable option, it’s usually the better
choice.

### Try it

Add `git` after `wget` in the list.

- Add `git` to `environment.systemPackages`configuration.nixNixOS moduleA NixOS module.

```nix
{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    vim
    wget
  ];
}
```

`htop` shows what's running on the machine. Add `pkgs.htop` after `pkgs.git`. Without `with pkgs;`, every name needs the `pkgs.` prefix.

- Add `htop` to `environment.systemPackages`configuration.nixNixOS moduleA NixOS module.

```nix
{ config, pkgs, ... }:

{
  environment.systemPackages = [
    pkgs.git
  ];
}
```

## Users

On most Linux systems, you add an account with `useradd`, and it lives in
`/etc/passwd`. On NixOS, you write it in your configuration, and a rebuild
creates it. Here’s the account the installer writes for the user you create:

`configuration.nix`:

```nix
{
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."yurii" = {
    isNormalUser = true;
    description = "Yurii";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
    #  thunderbird
    ];
  };
}
```

Here’s what each line does:

- `isNormalUser = true;` marks an account for a person. It gets a home directory
in `/home`.

- `description` is the full name the login screen shows.

- `extraGroups` adds the account to groups. `wheel` lets it run commands with
`sudo`, and `networkmanager` lets it change network settings.

- `packages` installs programs for this one account alone.

Your username sits inside the option name. The option is
`users.users`, and every account is an attribute
set under it, named after its login. So a second account is just a
second name:

`configuration.nix`:

```nix
{
  users.users.yurii = {
    isNormalUser = true;
  };
  users.users.guest = {
    isNormalUser = true;
  };
}
```

The installer wrote `"yurii"` in quotes and this one doesn’t. Both mean the
same thing.

Quotes matter when a name has a dot in it. Without them, the dot starts a new
level. These two lines are not the same:

`configuration.nix`:

```nix
{
  users.users."anna.k" = { isNormalUser = true; };
  users.users.anna.k = { isNormalUser = true; };
}
```

The first is an account called `anna.k`. The second is an account called
`anna` with a `k` inside it. Accounts have no option called `k`, so the
rebuild fails:

```console
$ sudo nixos-rebuild switch
[sudo] password for yurii:
building the system configuration...
error:
       …
       error: The option `users.users.anna.k' does not exist. Definition values:
       - In `/etc/nixos/configuration.nix':
           {
             isNormalUser = true;
           }
       Did you mean `users.users.anna.uid', `users.users.anna.home' or `users.users.anna.name'?
…
```

The password isn’t in the file. The installer set yours. An account you add
later has no password until you give it one with `passwd`:

```console
$ sudo passwd guest
[sudo] password for yurii:
New password:
Retype new password:
passwd: password updated successfully
```

Each account also has a login shell. It’s Bash unless you pick another one.
`shell` takes a package, so you can pick the shell itself instead of a path to it:

`configuration.nix`:

```nix
{ pkgs, ... }:

{
  users.users.yurii = {
    isNormalUser = true;
    shell = pkgs.fish;
  };
}
```

Rebuild with only that, and NixOS refuses. The message says what’s missing
and how to fix it:

```console
$ sudo nixos-rebuild switch
[sudo] password for yurii:
building the system configuration...
…
error:
       Failed assertions:
       - users.users.yurii.shell is set to fish, but
       programs.fish.enable is not true. This will cause the fish
       shell to lack the basic nix directories in its PATH and might make
       logging in as that user impossible. You can fix it with:
       programs.fish.enable = true;
       If you know what you're doing and you are fine with the behavior,
       set users.users.yurii.ignoreShellProgramCheck = true;
       instead.
```

Meaning a shell needs two lines. One sets it up for the whole system, and one
picks it for your account. Without the first, fish wouldn’t have the Nix
directories in its PATH. So it couldn’t find your programs.

zsh and xonsh get the same check. Bash needs nothing extra, because NixOS sets
it up by default.

### Try it

Give anna an account that can use `sudo`. Add `users.users.anna` below `yurii`, with `isNormalUser = true;` and `extraGroups = [ "wheel" ];` inside.

- Add a normal account named `anna`

- Add `anna` to the `wheel` groupconfiguration.nixNixOS moduleA NixOS module.

```nix
{
  users.users.yurii = {
    isNormalUser = true;
    description = "Yurii";
    extraGroups = [ "networkmanager" "wheel" ];
  };
}
```

Switch to fish. Change `pkgs.bash` to `pkgs.fish`, and add `programs.fish.enable = true;` above `users.users.yurii`.

- Set `users.users.yurii.shell` to `pkgs.fish`

- Set `programs.fish.enable` to `true`configuration.nixNixOS moduleA NixOS module.

```nix
{ pkgs, ... }:

{
  users.users.yurii = {
    isNormalUser = true;
    shell = pkgs.bash;
  };
}
```

## Services

A service is a program that keeps running in the background, like an SSH
server that lets you log in to this machine from another computer. On most
Linux distributions you install it, edit its config file and enable its
systemd unit by hand. On NixOS, the file the installer writes already has the
line for it, commented out:

`configuration.nix`:

```nix
{
  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;
}
```

Remove the `#` in front of `services.openssh.enable`, rebuild, and NixOS does all of it under the hood: it writes
`/etc/ssh/sshd_config`, creates the `sshd` system account, opens port 22 in
the firewall, and adds `sshd.service`, which systemd starts right away and on
every boot. Your job is only to choose the end result.

The options under `services.openssh` work together. Here the server moves to
port 2222 and password logins are turned off:

`configuration.nix`:

```nix
{
  services.openssh.enable = true;
  services.openssh.ports = [ 2222 ];
  services.openssh.settings.PasswordAuthentication = false;
}
```

After a rebuild, `/etc/ssh/sshd_config` has both of them:

```console
$ grep -E '^(Port|PasswordAuthentication) ' /etc/ssh/sshd_config
PasswordAuthentication no
Port 2222
```

Notice how `false` became `no`. Meaning `services.openssh.settings` is written
straight into `sshd_config`, in that file’s own format. And `ports` did more
than the `Port` line. The firewall now opens 2222 instead of 22.

Most services follow the same pattern, with an `enable` option and more
options under the same name, which
search.nixos.org lists.

The same pattern runs a home server. Jellyfin is a free media server, and two
lines set it up:

`configuration.nix`:

```nix
{
  services.jellyfin.enable = true;
  services.jellyfin.openFirewall = true;
}
```

`enable` creates the `jellyfin` system account and `jellyfin.service`, which
starts on every boot. `openFirewall` opens Jellyfin’s default ports, TCP 8096
and 8920 and UDP 1900 and 7359, so other devices on your network can reach it.
After a rebuild, open port 8096 of that machine in a browser.

### Try it

Keep port 22 and also listen on 2222: change `[ 22 ]` to `[ 22 2222 ]`.

- Set `services.openssh.ports` to `[ 22 2222 ]`configuration.nixNixOS moduleA NixOS module.

```nix
{
  services.openssh.enable = true;
  services.openssh.ports = [ 22 ];
}
```

Stop anyone from logging in as root over SSH. Add `services.openssh.settings.PermitRootLogin = "no";` below the `enable` line.

- Set `services.openssh.settings.PermitRootLogin` to `"no"`configuration.nixNixOS moduleA NixOS module.

```nix
{
  services.openssh.enable = true;
}
```

## hardware-configuration.nix

During installation, NixOS scans your machine and writes a second file next to
`configuration.nix`. It records the kernel modules your hardware needs, which
partitions get mounted where, and your swap. This is the one a fresh install
in a virtual machine generated.

`hardware-configuration.nix`:

```nix
# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/profiles/qemu-guest.nix")
    ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "virtio_pci" "ahci" "sr_mod" "virtio_blk" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/c937dc02-de5f-446f-8ac2-eadbb97dfa1f";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/8D53-C3FF";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
```

The comment at the top says not to edit this file, because running
`nixos-generate-config` again overwrites it. `configuration.nix` pulls it in
through `imports`, so your own changes go there instead.

Each name under `fileSystems` is a mount point, so `"/"` is the root partition
and `"/boot"` the boot partition. A name like `/` isn’t a plain word, which is
why it’s in quotes.

Partitions are found by UUID, an ID written to each partition when it was
formatted. No other machine has those IDs, so this file only fits the machine
it came from.

That matters when you take your configuration to a new machine. Most of
`configuration.nix` carries over, but this file doesn’t, and neither does one
copied from someone else’s setup.

So let NixOS scan the new machine instead. If you installed NixOS on it, the
installer already wrote one to `/etc/nixos`. Otherwise, run this in your
configuration’s directory:

```console
$ sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix
```

It prints the new file instead of writing anything to `/etc/nixos`, and `>`
saves it right there, in place of the old one.

A disk you add later goes into `configuration.nix`, written the same way.
Instead of a UUID, you can name it by the label you gave it when you formatted
it.

### Try it

This mounts an ext4 partition at `/data`, but doesn't say which one. Below the `fsType` line, add `fileSystems."/data".device = "/dev/disk/by-label/data";`.

- Find it by the label `data`configuration.nixNixOS moduleA NixOS module.

```nix
{
  networking.hostName = "nixos";
  fileSystems."/data".fsType = "ext4";
}
```

## NixOS from a flake

Every option and package in your configuration comes from nixpkgs, and without
a flake, which version of nixpkgs that is depends on the machine: whatever
its nixpkgs channel last downloaded. Build the same `configuration.nix` on two machines and you can get
two different systems. A flake fixes that by bundling the nixpkgs version with
your configuration.

The flake for a NixOS machine is short. It has one input, nixpkgs, and one
output under `nixosConfigurations`, named after the machine:

`flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs = inputs: {
    nixosConfigurations.snowflake = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      modules = [
        ./configuration.nix
      ];
    };
  };
}
```

`nixpkgs.lib.nixosSystem` is the function that builds a NixOS system. You give
it the system the machine runs on, and `modules`, the list of files to build it
from.

Your `configuration.nix` goes in there unchanged, so moving to a flake is mostly
a matter of putting `flake.nix` next to your existing files. The one exception
is anything you import from a channel, like `<home-manager/nixos>`. A flake
can’t look up channels, so that has to come in as an input instead.

The first build writes the exact nixpkgs revision into `flake.lock`. Every
build after that uses the same one, until you run `nix flake update`. So two
machines built from this directory get the same nixpkgs.

To build from the flake, pass its directory to `nixos-rebuild` with `--flake`.
Here the flake lives in `~/nixos-config`:

```console
$ sudo nixos-rebuild switch --flake ~/nixos-config#snowflake
[sudo] password for yurii:
building the system configuration...
…
Done. The new configuration is /nix/store/…-nixos-system-snowflake-26.05.20261002.774debe
```

The part after `#` picks the entry from `nixosConfigurations`. Leave it out, and
`nixos-rebuild` looks for an entry named after the machine’s current host name.

Flakes are still marked experimental, but `nixos-rebuild` turns them on for
its own run.

### Try it

The `modules` list is empty, so this system has none of your settings. Add `./configuration.nix` to it.

- Build `snowflake` from `./configuration.nix`flake.nixFlakeA flake with inputs and outputs.Project filesA file in the example project.

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs = inputs: {
    nixosConfigurations.snowflake = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      modules = [
      ];
    };
  };
}
```

## Several machines in one flake

Once you have a desktop and a laptop, most of their configuration is the same:
your user, Git, SSH. One flake can hold both machines, and the shared part is
written once.

Each machine gets its own entry under `nixosConfigurations`. The entry lists
the modules that machine is built from.

Each machine also gets its own directory under `hosts`. The shared part goes in
`modules/common.nix`, and both entries list it:

`flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs = inputs: {
    nixosConfigurations.desktop = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hosts/desktop/configuration.nix
        ./modules/common.nix
      ];
    };

    nixosConfigurations.laptop = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hosts/laptop/configuration.nix
        ./modules/common.nix
      ];
    };
  };
}
```

Both machines get the `yurii` account, Git and SSH from `common.nix`, and
everything else comes from their own directory. And each
`configuration.nix` imports the `hardware-configuration.nix` right next to
it, so a machine only ever gets its own.

That matters, because `hardware-configuration.nix` describes one specific
machine: its disks, its partitions and the kernel modules its hardware needs.
A copy from your other machine tells NixOS to mount partitions that aren’t
there.

So on every new machine, generate a fresh one into its directory. Run it on the
new machine itself, inside your config directory:

```console
$ sudo nixos-generate-config --show-hardware-config > hosts/laptop/hardware-configuration.nix
```

Then `git add` the new directory. A flake only sees files Git tracks. Forget it,
and Nix can’t find the laptop’s files:

```console
$ git status --short
?? hosts/laptop/
$ nix eval .#nixosConfigurations.laptop.config.networking.hostName
error:
       … while calling the 'seq' builtin
         at «github:NixOS/nixpkgs/774debe7a0d1b496e35677ad955a1011c6ff74f3?narHash=sha256-nQyFkMR78WP6PiXKkDW2SjqzLf/spQqjRuxRGSbcV8k%3D»/lib/modules.nix:402:18:
          401|         options = checked options;
          402|         config = checked (removeAttrs config [ "_module" ]);
             |                  ^
          403|         _module = checked (config._module);
       … while evaluating a branch condition
         at «github:NixOS/nixpkgs/774debe7a0d1b496e35677ad955a1011c6ff74f3?narHash=sha256-nQyFkMR78WP6PiXKkDW2SjqzLf/spQqjRuxRGSbcV8k%3D»/lib/modules.nix:305:9:
          304|       checkUnmatched =
          305|         if config._module.check && config._module.freeformType == null && merged.unmatchedDefns != [ ] then
             |         ^
          306|           let
       (stack trace truncated; use '--show-trace' to show the full, detailed trace)
       error: Path 'hosts/laptop/configuration.nix' in the repository "/home/yurii/nixos-config" is not tracked by Git.
       To make it visible to Nix, run:
       git -C "/home/yurii/nixos-config" add "hosts/laptop/configuration.nix"
$ git add hosts/laptop
$ nix eval .#nixosConfigurations.laptop.config.networking.hostName
warning: Git tree '/home/yurii/nixos-config' is dirty
"laptop"
```

To switch a machine, name its entry after a `#` in the flake’s directory:

```console
$ sudo nixos-rebuild switch --flake .#laptop
```

Leave out `#laptop`, and `nixos-rebuild` picks the entry named after the
machine’s current host name. That’s why each host sets `networking.hostName`
to the name of its entry. A fresh install is still called `nixos`, so the very
first switch needs the name spelled out.

### Try it

Add a third machine. Copy the whole `nixosConfigurations.laptop` entry and paste it right below. In the copy, change both `laptop` to `server`.

- Give the server SSH from `common.nix`flake.nixFlakeA flake with inputs and outputs.Project filesA file in the example project.

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs = inputs: {
    nixosConfigurations.desktop = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hosts/desktop/configuration.nix
        ./modules/common.nix
      ];
    };

    nixosConfigurations.laptop = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hosts/laptop/configuration.nix
        ./modules/common.nix
      ];
    };
  };
}
```

## Passing inputs to modules

Almost every NixOS flake needs this. Modules from Home Manager, sops-nix or
disko all come from flake inputs, and your `configuration.nix` has to reach
them somehow.

Say `configuration.nix` wants to import Home Manager’s NixOS module, the one
that lets your system configuration set up your home directory too. That module
lives in a flake input, and modules don’t get your inputs. The module system
hands every module arguments like `config`, `lib` and `pkgs`, and your flake’s
inputs aren’t among them.

Ask for `inputs` anyway, and see what happens. This `configuration.nix` wants
`inputs`, but the flake never hands them over:

`flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs: {
    nixosConfigurations.snowflake = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./configuration.nix ];
    };
  };
}
```

Rebuild, and evaluation stops:

```console
$ sudo nixos-rebuild switch --flake .#snowflake
[sudo] password for yurii:
…
       … while evaluating the module argument `inputs' in "/nix/store/v7g97wamjg6mffa22fps892xak9kajrj-source/configuration.nix":
       … noting that argument `inputs` is not externally provided, so querying `_module.args` instead, requiring `config`
       … if you get an infinite recursion here, you probably reference `config` in `imports`. If you are trying to achieve a conditional import behavior dependent on `config`, consider importing unconditionally, and using `mkEnableOption` and `mkIf` to control its effect.
       (stack trace truncated; use '--show-trace' to show the full, detailed trace)
       error: infinite recursion encountered
Command 'nix --extra-experimental-features 'nix-command flakes' build --print-out-paths '.#nixosConfigurations."snowflake".config.system.build.nixos-rebuild' --no-link' returned non-zero exit status 1.
```

The line with “noting that” says why. Nobody handed `inputs` to the module, so
Nix looks for it in `config` instead. And `config` can’t be ready while
`imports` is still being worked out. The hint below that line is about a
different mistake, so you can skip it.

`specialArgs` is how you provide it. It’s a set you give to `nixosSystem`, and
every name in it becomes an argument that any module can ask for. The usual
move is to hand over all inputs at once:

`flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs: {
    nixosConfigurations.snowflake = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [ ./configuration.nix ];
    };
  };
}
```

`inherit inputs;` is short for `inputs = inputs;`. Now every module can write
`inputs` in its header and reach any input from there.

Many flakes unpack the inputs with `{ nixpkgs, ... }@inputs:`. The `@inputs`
keeps the whole set under the name `inputs` too, so `inherit inputs;` still
works.

It even works right inside `imports`, because names from `specialArgs`
are there from the start.

Home Manager modules are a module system of their own, so they don’t see
these arguments. Under NixOS, you pass them on once more, next to your Home
Manager user:

`configuration.nix`:

```nix
{ inputs, ... }:

{
  home-manager.extraSpecialArgs = { inherit inputs; };
  home-manager.users.yurii = ./home.nix;
}
```

Now `home.nix` can start with `{ inputs, ... }:` too.

### Try it

`specialArgs` can carry any value, not only inputs. `configuration.nix` also asks for `username`. Add `username = "yurii";` inside `specialArgs`, after `inherit inputs;`.

- Hand `username` to every module, so the `yurii` account existsflake.nixFlakeA flake with inputs and outputs.Project filesA file in the example project.

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs: {
    nixosConfigurations.snowflake = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [ ./configuration.nix ];
    };
  };
}
```

## Graphics drivers

Your desktop, your browser and every game draw with your GPU, and the GPU
needs drivers for that. On NixOS they come from one option,
`hardware.graphics.enable`. It installs Mesa, the open drivers most GPUs run on.

You’ll rarely write that line yourself. A login screen like GDM, or a window
manager like Hyprland, turns it on for you.

Got an AMD or Intel GPU? Then you’re done. Their kernel drivers are already
part of Linux, and Mesa does the rest.

NVIDIA is the odd one out. Out of the box you get nouveau, an open driver
that works, but it’s slow in games and can’t run CUDA. For those you want
NVIDIA’s own driver, and that takes three lines:

`configuration.nix`:

```nix
{
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia.open = true;

  nixpkgs.config.allowUnfree = true;
}
```

`services.xserver.videoDrivers` is the switch. Don’t let the `xserver` fool
you, it works for Wayland desktops too.

`nixpkgs.config.allowUnfree` is there because NVIDIA’s driver is unfree.
Leave it out, and the rebuild stops and tells you to add it. Here’s that
error, with the middle cut down to `…`:

```console
error: Refusing to evaluate package 'nvidia-x11-595.71.05' in /nix/store/3zvg83mg9aavm9bgh26ydljchply7i25-source/pkgs/os-specific/linux/nvidia-x11/generic.nix:317 because it has an unfree license (‘unfreeRedistributable’)
…
b) For `nixos-rebuild` you can set
  { nixpkgs.config.allowUnfree = true; }
in configuration.nix to override this.
```

`hardware.nvidia.open` picks between NVIDIA’s two kernel drivers, an open one
and a closed one. The open one only works on RTX and GTX 16xx cards, and NixOS
makes you choose. Leave it out, and the rebuild stops with `expected a Boolean but found null`.

Older cards have one more catch. By default NixOS installs NVIDIA’s 595 driver,
and NVIDIA stopped supporting GTX 9xx and 10xx cards after its 580 driver.
`hardware.nvidia.branch` asks for that older driver instead.

So it comes down to your card:

- RTX cards and GTX 16xx: `open = true`.

- GTX 9xx and 10xx: `open = false`, and `branch = "legacy_580"`.

After a rebuild and a reboot, `nvidia-smi` shows your card and the driver
version. That’s how you know NVIDIA’s driver is the one running.

Some programs, like Wine and many older games, are 32-bit and need 32-bit
drivers. `hardware.graphics.enable32Bit` installs them. If you play through
Steam, `programs.steam.enable = true;` turns it on for you.

### Try it

This machine has a GTX 1080. Set up its driver the way the list above says, under the `videoDrivers` line.

- Set `hardware.nvidia.open` to `false`

- Set `hardware.nvidia.branch` to `"legacy_580"`configuration.nixNixOS moduleA NixOS module.

```nix
{
  services.xserver.videoDrivers = [ "nvidia" ];

  nixpkgs.config.allowUnfree = true;
}
```

This machine also plays games through Steam. Turn Steam on.

- Set `programs.steam.enable` to `true`configuration.nixNixOS moduleA NixOS module.

```nix
{
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia.open = false;
  hardware.nvidia.branch = "legacy_580";

  nixpkgs.config.allowUnfree = true;
}
```

## Desktops and window managers

GNOME and Hyprland both give you windows on a screen, but they’re very
different things. GNOME is a desktop environment. It’s the whole graphical
session, with its own panel, settings app, file manager and more. Hyprland is a
window manager. It only arranges your windows, as tiles side by side, and
leaves the rest to you. KDE Plasma is a desktop environment too, and niri is a
window manager like Hyprland.

On NixOS, you switch each one on with an option or two. When you pick
GNOME, the installer writes these lines:

`configuration.nix`:

```nix
{
  # Enable the GNOME Desktop Environment.
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
}
```

`services.desktopManager.gnome.enable` installs GNOME, and
`services.displayManager.gdm.enable` turns on GDM, the login screen that starts
it. For Plasma, the installer writes `services.displayManager.sddm.enable` and
`services.desktopManager.plasma6.enable` instead.

Wayland window managers like Hyprland and niri live under `programs` instead.
Here’s Hyprland added next to GNOME:

`configuration.nix`:

```nix
{
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  programs.hyprland.enable = true;
}
```

After a rebuild, the login screen offers both. You pick GNOME or Hyprland each
time you log in. niri works the same way, with `programs.niri.enable`.

You enable the module, not the package. This line only installs
the Hyprland program:

`configuration.nix`:

```nix
{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.hyprland ];
}
```

This one installs it too, and adds Hyprland to the login screen:

`configuration.nix`:

```nix
{
  programs.hyprland.enable = true;
}
```

It also sets up the pieces a desktop needs around it, like screen sharing and
graphics support.

### Try it

Switch this machine from GNOME to Plasma. Change `gdm` to `sddm` and `gnome` to `plasma6`.

- Set `services.displayManager.sddm.enable` to `true`

- Set `services.desktopManager.plasma6.enable` to `true`configuration.nixNixOS moduleA NixOS module.

```nix
{
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
}
```

Hyprland is installed here, but the login screen doesn't offer it. Replace the `environment.systemPackages` line with `programs.hyprland.enable = true;`.

- Set `programs.hyprland.enable` to `true`configuration.nixNixOS moduleA NixOS module.

```nix
{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.hyprland ];
}
```

## Install NixOS

Install NixOS from scratch, the same way you would on a real computer.

Takes about 15 minutes.

You’ll:

- boot the NixOS installer

- go through the installer’s pages: time zone, keyboard, your account, the
desktop, unfree software and the disk

- let it install, then restart into your new system and log in

The installer also writes your `configuration.nix` and
`hardware-configuration.nix` from what you picked.

Everything happens in your browser. Nothing gets installed on your computer.

## Configure NixOS

Make your first change to NixOS: a new name and a few programs.

Takes about 10 minutes.

You’ll:

- open `configuration.nix`

- rename the machine to `snowflake`, turn on Neovim and add Git

- rebuild with `sudo nixos-rebuild switch`

- restart, and find your old system still in the boot menu

Continues from Install NixOS.

Everything happens in your browser. Nothing gets installed on your computer.

## Turn it into a flake

Build `snowflake` from a flake, so it uses the nixpkgs written in `flake.lock`
instead of whatever your channel has.

Takes about 20 minutes.

You’ll:

- turn on flakes

- copy your configuration into `~/nixos-config`, a directory you own

- write its `flake.nix`

- rebuild from the flake, and tidy away the old files in `/etc/nixos`

Continues from Configure NixOS.

Everything happens in your browser. Nothing gets installed on your computer.

