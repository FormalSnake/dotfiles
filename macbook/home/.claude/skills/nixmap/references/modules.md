# Module system

## Modules

A NixOS `configuration.nix`, a Home Manager `home.nix` and a nix-darwin
configuration all look alike, and that’s because they’re the same kind of
file: a module. A module is just an attribute set of settings, like
`programs.git.enable = true;`, or a function that returns one.

So you’re not stuck with one big file. Once it grows, you split it into
modules, one for your editor, one for your desktop, one for a web server. The
module system, which ships with nixpkgs, reads all of them and combines them
into one configuration.

Most modules are functions, because they need something from outside, usually
`pkgs` to name packages. The module system calls the function with one set that holds
`config`, `lib`, `pkgs` and a few more, and the module picks out the ones it uses.

`editor.nix`:

```nix
{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.neovim ];
  environment.variables.EDITOR = "nvim";
}
```

Notice the `...` in the header. It’s there because the set has more names than
any module asks for, and without it NixOS stops with “called with unexpected
argument”.

### Try it

This module is a plain set, so it cannot use `pkgs` yet. Add `{ pkgs, ... }:` above its opening brace, then put `pkgs.git` inside the empty list.

- Ask for `pkgs` and add `pkgs.git` to `environment.systemPackages`tools.nixNixOS moduleA NixOS module.

```nix
{
  environment.systemPackages = [ ];
}
```

## Options

A line like `programs.git.enable = true;` in a NixOS or Home Manager
configuration sets an option. An option is a setting that some module declared
in advance, with a name, a type that says which values it accepts,
usually a default, and a description.

Setting an option doesn’t create anything. You give a value to an option that
already exists, and every option you don’t mention keeps its default. NixOS
and Home Manager each come with thousands of them.

Hover an option’s name in the editor below to see its type, default and
description. For NixOS, search.nixos.org
shows the same for every option.

`configuration.nix`:

```nix
{
  networking.hostName = "workstation";
  time.timeZone = "Europe/Kyiv";
  programs.git.enable = true;
}
```

Mistakes stop you before anything gets built, because every
option and its type are known in advance. A typo like `programs.gti.enable`
fails with “The option `programs.gti’ does not exist”, and `"yes"` where a
boolean belongs fails with “is not of type `boolean’”.

### Try it

`networking.firewall.allowedTCPPorts` is declared as a list of ports. Open port 80 for a web server: add `networking.firewall.allowedTCPPorts = [ 80 ];` under the Git line.

- Open port 80 in `networking.firewall.allowedTCPPorts`configuration.nixNixOS moduleA NixOS module.

```nix
{
  networking.hostName = "workstation";
  time.timeZone = "Europe/Kyiv";
  programs.git.enable = true;
}
```

## The config argument

Say one file sets the host name, and another wants to print it in the login
message. So the second file needs to read an option, not only set one.

That’s what the `config` argument is for. Add it to a module’s header,
and it holds the final value of every option. It’s the result after all
modules have been combined. So a module can use a choice made in another file
without knowing which file made it.

Here `motd.nix` builds the login message from the host name that `host.nix`
sets:
motd.nixNixOS modulehost.nix Add a module merge enabled modules

merged configuration

Every module is switched off, so there is nothing to build.

Notice how `motd.nix` comes first, yet it reads a value that `host.nix` sets.
Meaning the order of modules doesn’t matter, because `config` is the result of
all of them together.

It may look odd that a module reads a result it’s part of. It works because
Nix is lazy: it only works out a value when something
asks for it. The module system hands every module the finished `config` up
front, and each value inside gets computed on first use.

NixOS’s own modules do this all the time. This is a piece of the SSH module.
It reads the ports you chose for SSH, wherever you chose them, and opens
exactly those in the firewall:

`nixos/modules/services/networking/ssh/sshd.nix`:

```nix
{ config, lib, ... }:

let
  cfg = config.services.openssh;
in
{
  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      networking.firewall.allowedTCPPorts = lib.optionals cfg.openFirewall cfg.ports;
    })
  ];
}
```

`cfg` is just a short name for `config.services.openssh`. And `cfg.ports` is
whatever any module set `services.openssh.ports` to.

`lib.optionals` gives back the ports only when `cfg.openFirewall` is true.
Otherwise it gives an empty list. `lib.mkIf cfg.enable` makes all of it apply only
while SSH is on.

The `config =` inside is a different thing from the argument. It’s where the
module sets options. The `config` on the first line is where it reads them.

What breaks is a value that depends on itself. Here `host.nix`
sets the host name to the host name. To know it, Nix has to know it first:
motd.nixNixOS modulehost.nix Add a module merge enabled modules

merged configuration

Every module is switched off, so there is nothing to build.

The error says infinite recursion. To fix it, the host name has to come from
somewhere else, like a plain `"laptop"`.

### Try it

Make `motd.nix` show the time zone that `host.nix` sets. Add `{ config, ... }:` above its opening brace, then add `+ " (" + config.time.timeZone + ")"` after `"Welcome"`.motd.nixNixOS modulehost.nix Add a module merge enabled modules

merged configuration

Every module is switched off, so there is nothing to build.

## imports

If you use NixOS, you’ve already seen `imports` at the top
of `configuration.nix`: `imports = [ ./hardware-configuration.nix ];`. It’s how
modules find each other. It’s a list of paths to other module
files, and every module in it joins the same evaluation as the module that
lists it.

Here `configuration.nix` imports two small modules. `editors.nix` adds Vim to
`environment.systemPackages`, and `tools.nix` adds Git and ripgrep:
configuration.niximports the restNixOS module the files it importseditors.niximportedtools.niximported Add a module merge enabled modules

merged configuration

Nothing is imported, so there is nothing to build.

All three packages end up in the result. Every imported module
adds its settings to the same pile, and the module system merges them. Take
`./tools.nix` out of the list, and Git and ripgrep leave the result.

The paths are ordinary Nix paths, so they’re relative to the file that lists
them. Say your config is split into directories like this:

```console
$ find nixos-config -name '*.nix'
nixos-config/laptop/configuration.nix
nixos-config/laptop/hardware.nix
nixos-config/shared/desktop.nix
```

Then `laptop/configuration.nix` imports both like this:

`laptop/configuration.nix`:

```nix
{
  imports = [
    ./hardware.nix
    ../shared/desktop.nix
  ];
}
```

`./` starts in the `laptop` directory, where this file is. `../` steps up one
directory, into `nixos-config`.

Don’t mix it up with `import`. `import ./desktop.nix` just reads the file and
gives you back what’s in it:
desktop.nixread only

```nix
{
  services.libinput.enable = true;
}
```

```nix
import ./desktop.nix
```

You get back a plain set, and nothing changes in your config. `imports` is
what makes the file part of it.

Not every entry has to be a path. Most NixOS add-ons come with a module of
their own, and you import it the same way. Here Home Manager’s module comes
from the flake’s inputs:

`configuration.nix`:

```nix
{ inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    inputs.home-manager.nixosModules.home-manager
  ];
}
```

The second entry is not a path. It’s a module someone else wrote, and it
joins the same pile as your own files. That’s how Home Manager, disko
and most other NixOS add-ons get into a config.

If you use flakes, `inputs` comes from your `flake.nix`. The flake has to hand
it to your modules with `specialArgs = { inherit inputs; };`.

An imported module can have its own `imports`. So one entry file can pull in a
whole tree of modules.

A file imported from several places still counts once. Here
`desktop.nix` and `printing.nix` both import `./users.nix`, which puts `yurii`
in the `wheel` group. `configuration.nix` imports it too:
configuration.niximports the restNixOS moduleProject files the files it importsdesktop.niximportedprinting.niximportedusers.niximported Add a module merge enabled modules

merged configuration

Nothing is imported, so there is nothing to build.

Three modules adding to the same list would give you `wheel` three times, like
the packages above. But `users.nix` is the same file every time, so it joins
once.

### Try it

`ssh.nix` sits next to `configuration.nix`, but nothing imports it yet. Add `./ssh.nix` to the end of the `imports` list.

- Import `./ssh.nix`, so its `services.openssh.enable` reaches the configurationconfiguration.nixNixOS moduleA NixOS module.Project filesA file in the example project.

```nix
{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "workstation";
}
```

## Merging definitions

Once your configuration is split into several files, they start touching the
same options. `editors.nix` wants Vim installed, and `tools.nix` wants Git and
ripgrep. Both set `environment.systemPackages`, and neither has to know about
the other, because the module system merges their values:
editors.nixNixOS moduletools.nix Add a module merge enabled modules

merged configuration

Every module is switched off, so there is nothing to build.

Lists join, so all three packages end up installed. Switch a module off in its
header and its packages leave the result.

NixOS does this too. `programs.git.enable = true;` turns on a module inside
nixpkgs. That module adds Git to the same `environment.systemPackages` list as
your files. This is the part of it that does that:

`nixos/modules/programs/git.nix`:

```nix
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.git;
in

{
  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      environment.systemPackages = [ cfg.package ];
    })
  ];
}
```

Sets merge name by name. Here each file adds one environment variable, and
both end up in `environment.variables`:
editors.nixNixOS moduletools.nix Add a module merge enabled modules

merged configuration

Every module is switched off, so there is nothing to build.

A setting like `networking.hostName` holds one value, so there’s nothing to
join. Two equal definitions are fine. Two different ones stop the evaluation:
base.nixNixOS moduleserver.nix Add a module merge enabled modules

merged configuration

Every module is switched off, so there is nothing to build.

So a disagreement shows up before anything gets built, and Nix never guesses
which file you meant. In a real rebuild, the error also suggests
`lib.mkForce`. That lets one file win on purpose.

The option decides which of these happens. Its declaration gives it
a type: `environment.systemPackages` is a list of packages,
`environment.variables` is a set, and `networking.hostName` is a string. Meaning
the same `=` joins, merges or conflicts depending on what the option holds.

### Try it

Both files set `EDITOR`. Change it to `"vim"` in `tools.nix`, and read what the module system says.editors.nixNixOS moduletools.nix Add a module merge enabled modules

merged configuration

Every module is switched off, so there is nothing to build.

Let `server.nix` win on purpose. Change `"web"` to `lib.mkForce "web"`.base.nixNixOS moduleserver.nix Add a module merge enabled modules

merged configuration

Every module is switched off, so there is nothing to build.

## mkDefault and mkForce

Sometimes two modules disagree on purpose. A module shared by all your machines
suggests a value, and one machine wants its own. With two plain definitions,
that’s a conflict:
profile.nixNixOS modulehost.nix Add a module merge enabled modules

merged configuration

Every module is switched off, so there is nothing to build.

Wrap the suggestion in `lib.mkDefault`, and it gives way:
profile.nixNixOS modulehost.nix Add a module merge enabled modules

merged configuration

Every module is switched off, so there is nothing to build.

Sometimes the module you disagree with isn’t yours, and it didn’t use
`mkDefault`. Say a shared `desktop.nix` turns on the X server, and this machine
wants it off. Wrap your own value in `lib.mkForce`, and it wins:
desktop.nixNixOS modulehost.nix Add a module merge enabled modules

merged configuration

Every module is switched off, so there is nothing to build.

That works because every definition has a priority number, and the lower
number wins:

- `lib.mkForce` gives `50`

- a plain definition gets `100`

- `lib.mkDefault` gives `1000`

- the option’s own default sits at `1500`

So `mkForce` beats a plain definition, and a plain definition beats
`mkDefault`. All three replace the option’s default.

A `mkDefault` never joins a fight between plain definitions. Here only
`server.nix` and `host.nix` clash:
profile.nixNixOS moduleserver.nixhost.nix Add a module merge enabled modules

merged configuration

Every module is switched off, so there is nothing to build.

`mkDefault` and `mkForce` don’t decide anything by themselves.
They only wrap the value with its priority number. The module system reads that
number later, while merging:

```nix
lib.mkDefault "x86_64-linux"
```

```nix
lib.mkForce false
```

You’ll find `mkDefault` on your own machine too. If you use NixOS, your
`hardware-configuration.nix` has this line:

`hardware-configuration.nix`:

```nix
{ config, lib, pkgs, modulesPath, ... }:

{
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
```

The installer only suggests a platform. Your own configuration can still
replace it without a conflict.

### Try it

NixOS's minimal profile turns off logrotate, the service that cleans up old log files, with `mkDefault`. Turn it back on. In `configuration.nix`, add `services.logrotate.enable = true;`.minimal.nixNixOS moduleconfiguration.nix Add a module merge enabled modules

merged configuration

Every module is switched off, so there is nothing to build.

Both files only suggest a value, so they tie at `1000` and clash. In `laptop.nix`, change `lib.mkDefault false` to a plain `false`.common.nixNixOS modulelaptop.nix Add a module merge enabled modules

merged configuration

Every module is switched off, so there is nothing to build.

## mkIf

Sometimes a setting should only apply in some cases. Say you want fail2ban,
which blocks addresses that keep failing to log in, but only while SSH is on.
The obvious way is to copy SSH’s switch:

`ssh.nix`:

```nix
{ config, ... }:

{
  services.fail2ban.enable = config.services.openssh.enable;
}
```

With SSH off, this line doesn’t stay quiet. It says `false`, and
that’s a definition like any other. So if another module turns fail2ban on,
the two disagree, and the rebuild stops with “The option
`services.fail2ban.enable’ has conflicting definition values”.

What you meant was “only when SSH is on, and otherwise say nothing”. That’s
exactly what `lib.mkIf` says:

`ssh.nix`:

```nix
{ config, lib, ... }:

{
  services.fail2ban.enable = lib.mkIf config.services.openssh.enable true;
}
```

With SSH off, it’s as if this module never set the option. fail2ban keeps its
default, or whatever other modules set, and nothing clashes.

So how can a value be “nothing”? `mkIf` doesn’t decide anything by itself. It
just packs the condition and the value into a set:

```nix
lib.mkIf false true
```

The module system opens that set later, while merging, and skips it when the
condition is `false`. It only looks inside once every module has been read, so
the condition can safely read `config`.

This is how almost every service in NixOS is written. Here is the module for
the Orca screen reader from nixpkgs:

`nixos/modules/services/accessibility/orca.nix`:

```nix
{
  config,
  lib,
  ...
}:
let
  cfg = config.services.orca;
  inherit (lib) mkIf;
in
{
  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    systemd.packages = [ cfg.package ];
    services.gnome.at-spi2-core.enable = true;
    services.speechd.enable = true;
  };
}
```

Meaning `services.orca.enable = true;` in your configuration is the switch.
Until you flip it, those four lines don’t exist.

### Try it

Open port 22 only while SSH is on. Replace `false` after `lib.mkIf` with `config.services.openssh.enable`.

- Add `22` to `networking.firewall.allowedTCPPorts` only when `config.services.openssh.enable` is `true`firewall.nixNixOS moduleA NixOS module.

```nix
{ config, lib, ... }:

{
  networking.firewall.allowedTCPPorts = lib.mkIf false [ 22 ];
}
```

## Conditional imports and infinite recursion

Once your configuration is split into modules, it’s tempting to import some of
them only on certain machines. Say `gaming.nix` turns on Steam, and you only
want it where there’s a desktop. So you make the import depend on an option:
configuration.nixNixOS moduleProject files Add a module merge enabled modules

merged configuration

Every module is switched off, so there is nothing to build.

Nothing comes out, not even the host name. NixOS stops with `infinite recursion encountered`.

`config` is the finished configuration, and NixOS builds it out of every module
it imports. To know what `config.services.displayManager.enable`
is, it has to read all the modules first, but to know which modules there are,
it has to read `config`. Each one waits for the other. That’s why, on a real
machine, the full error comes with a hint: “if you get an infinite recursion
here, you probably reference `config` in `imports`”.

The fix is the one that hint suggests. Import the module everywhere, and give
it its own switch. `lib.mkEnableOption` declares a `true` or `false` option
that starts out `false`, and `lib.mkIf` only applies the settings when it’s on.
Now every machine imports `gaming.nix`, and the ones that want it say so in
their own configuration:
configuration.niximports the restNixOS moduleProject files the files it importsgaming.niximportedworkstation.niximported Add a module merge enabled modules

merged configuration

Nothing is imported, so there is nothing to build.

This time it works. The host name is back, and Steam is on.

You may still want Steam on every machine with a desktop. It’s tempting to
wrap the whole module in an `if` on `config` for that:
gaming.nixNixOS module Add a module merge enabled modules

merged configuration

Every module is switched off, so there is nothing to build.

It stops with the same infinite recursion. To know what this module sets,
NixOS has to run the `if`. The `if` needs `config`, and `config` needs this
module. `lib.mkIf` is the fix there too. It hands the module system its settings right
away, and only checks the condition later, once `config` is ready. It doesn’t
need an `else` either.

### Try it

Fix `gaming.nix`. Change `if` to `lib.mkIf`, delete `then`, and delete `else { }`.gaming.nixNixOS moduledesktop.nix Add a module merge enabled modules

merged configuration

Every module is switched off, so there is nothing to build.

## Declaring options

Every option you set was declared by some module first. NixOS’s SSH module,
for example, declares `services.openssh.enable` and `services.openssh.ports`
in its own file, under `options`. Each one is a `lib.mkOption` call with a
set that describes the setting: a `type` for the values it accepts, a
`default` for when nobody sets it, and a `description` for the documentation.

`sshd.nix`:

```nix
{
  config,
  lib,
  pkgs,
  ...
}:
{
  options = {

    services.openssh = {

      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable the OpenSSH secure shell daemon, which
          allows secure remote logins.
        '';
      };

      ports = lib.mkOption {
        type = lib.types.listOf lib.types.port;
        default = [ 22 ];
        description = ''
          Specifies on which ports the SSH daemon listens.
        '';
      };
    };
  };
}
```

Your own modules can declare options the same way. The most common one is an
on/off switch like `enable` above, so `lib.mkEnableOption` writes it for you:
a boolean, `false` by default, with a description that reads “Whether to
enable” followed by your words. That’s how a module of yours gets turned on
with one line from another file, just like SSH.

Here’s what it writes for you, spelled out. The `example` is shown in the
docs next to the default:

desktop.nixexcerptambient libA piece of a larger file. `lib` was bound by the part not shown, so it is supplied here too.

```nix
{
  options.desktopApps.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    example = true;
    description = "Whether to enable desktop apps.";
  };
}
```

And here’s the short way:

desktop.nixexcerptambient libA piece of a larger file. `lib` was bound by the part not shown, so it is supplied here too.

```nix
{
  options.desktopApps.enable = lib.mkEnableOption "desktop apps";
}
```

These two are the same option.

Options aren’t only on/off switches. This module declares which browser to
install, and installs it:

`desktop.nix`:

```nix
{ config, lib, pkgs, ... }:

{
  options = {
    desktopApps.browser = lib.mkOption {
      type = lib.types.package;
      default = pkgs.firefox;
    };
  };

  config = {
    environment.systemPackages = [ config.desktopApps.browser ];
  };
}
```

The option’s type is `package`, so its value is a package itself, like
`pkgs.firefox`. The module puts that value straight into the list.

This time `environment.systemPackages` sits under `config`. In a
module with `options`, Nix needs to know which names you declare and which
ones you set. So its own settings have to go under `config`. Leave one at the
top, next to `options`, and the evaluation stops:
desktop.nixNixOS module Add a module merge enabled modules

merged configuration

Every module is switched off, so there is nothing to build.

The error names the setting, and even tells you the fix. It says to move it
“into the explicit `config’ attribute”.

With `config` in place, Firefox gets installed unless another file says
otherwise. Here `laptop.nix` says otherwise:
desktop.nixNixOS modulelaptop.nix Add a module merge enabled modules

merged configuration

Every module is switched off, so there is nothing to build.

The result has Chromium in it, and Firefox is gone. The default only
counts when nobody sets the option.

The type keeps out values that make no sense. Set the browser to `5`, and the
evaluation stops:
desktop.nixNixOS modulelaptop.nix Add a module merge enabled modules

merged configuration

Every module is switched off, so there is nothing to build.

This time Nix tells you which option got a bad value, and what type it
expected:
`A definition for option `desktopApps.browser' is not of type `package'`.

### Try it

Add a switch for games. Under `options`, after the browser option, add `desktopApps.games.enable = lib.mkEnableOption "games";`.

- Declare `desktopApps.games.enable` with `lib.mkEnableOption "games"`desktop.nixNixOS moduleA NixOS module.

```nix
{ config, lib, pkgs, ... }:

{
  options = {
    desktopApps.browser = lib.mkOption {
      type = lib.types.package;
      default = pkgs.firefox;
    };
  };

  config = {
    environment.systemPackages = [ config.desktopApps.browser ];
  };
}
```

Add an editor option. Under `options`, add `desktopApps.editor = lib.mkOption { type = lib.types.package; default = pkgs.neovim; };`. Then add `config.desktopApps.editor` to the `environment.systemPackages` list.

- Neovim is installeddesktop.nixNixOS moduleA NixOS module.

```nix
{ config, lib, pkgs, ... }:

{
  options = {
    desktopApps.browser = lib.mkOption {
      type = lib.types.package;
      default = pkgs.firefox;
    };
  };

  config = {
    environment.systemPackages = [ config.desktopApps.browser ];
  };
}
```

## Option types

The `type` in an option’s declaration says which values the option accepts.
`services.openssh.ports` is a list of `lib.types.port`, and a port is a whole
number from 0 to 65535. So `[ 2222 ]` is fine, but a typo like `[ 99999 ]`
stops the evaluation instead of becoming an SSH server that never starts.

The type also decides what happens when several modules set the same option.
`networking.extraHosts` has the type `lines`, which joins strings with a newline
in between. So both modules below get their line into `/etc/hosts`:
nas.nixNixOS moduleprinter.nix Add a module merge enabled modules

merged configuration

Every module is switched off, so there is nothing to build.

`i18n.defaultLocale` is a plain `str`, and a system can only have one default
language. Two different values can’t be joined, so the evaluation stops and
names both of them:
base.nixNixOS modulegerman.nix Add a module merge enabled modules

merged configuration

Every module is switched off, so there is nothing to build.

A `listOf` joins the lists instead. That’s how every module can add its own
packages to `environment.systemPackages`, and all of them get installed:
editors.nixNixOS moduletools.nix Add a module merge enabled modules

merged configuration

Every module is switched off, so there is nothing to build.

Types are built from pieces. `bool`, `int`, `str` and `port` stand on their
own. `listOf`, `attrsOf` and `nullOr` take another type and wrap it, and you
can wrap as deep as you need.

Every type also has a `description`, a name for people to read. It’s the type
line you see on search.nixos.org. Ask a wrapped type for it, and you can read
the pieces right back:

```nix
(lib.types.nullOr (lib.types.listOf lib.types.str)).description
```

Meaning an option of this type takes either `null` or a list of strings. A
`port` reads longer, because its description also gives the range:

```nix
(lib.types.listOf lib.types.port).description
```

### Try it

`lib.types.int` would also accept `99999`, which no port can be. Change `lib.types.int` to `lib.types.port`.

- Declare `web.port` with `lib.types.port`, so `8080` passes and `99999` failsweb.nixNixOS moduleA NixOS module.

```nix
{ lib, ... }:

{
  options.web.port = lib.mkOption {
    type = lib.types.int;
    default = 8080;
    description = "Port the web server listens on.";
  };
}
```

