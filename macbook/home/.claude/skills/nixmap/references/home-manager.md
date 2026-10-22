# Home Manager

## Home Manager

Your system is only half of your setup. The other half lives in your home
directory: your shell, your Git name and email, your editor settings, and the
pile of dotfiles you copy by hand every time you get a new machine.

Home Manager lets you describe that half in Nix. Your user’s packages and
program settings go in a module, usually called `home.nix`. Then
`home-manager switch` builds it and links the results into your home directory.

You don’t need NixOS for it. It runs on any Linux with Nix and on macOS. On
NixOS it can also be part of your system configuration.

To start, run this. It writes a starter `home.nix` and a `flake.nix` into
`~/.config/home-manager`, and switches to it:

```console
$ nix run home-manager/release-26.05 -- init --switch
```

Here’s a small `home.nix` with one package and Git set up:

`home.nix`:

```nix
{ pkgs, ... }:

{
  home.username = "yurii";
  home.homeDirectory = "/home/yurii";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  home.packages = [ pkgs.fzf ];

  programs.git = {
    enable = true;
    settings.user = {
      name = "Yurii";
      email = "yurii@example.com";
    };
  };
}
```

`home.packages` is the list of packages for your user only.

`home.username` and `home.homeDirectory` tell Home Manager whose home directory
this is, so put your own name there.

`programs.home-manager.enable` installs the `home-manager` command itself. From
then on, you just run `home-manager switch`.

`home.stateVersion` is the Home Manager release you started with. Some changes
in newer releases only switch on once this number is new enough, so your setup
keeps working the way it did. Not every change waits for it, so skim the
release notes when you update. Set it once and leave it, even after you update.

Run `home-manager switch`, and look at what it made:

```console
$ which fzf
/home/yurii/.nix-profile/bin/fzf
$ cat ~/.config/git/config
[user]
	email = "yurii@example.com"
	name = "Yurii"
$ readlink ~/.config/git/config
/nix/store/ll17a5snqmxfc09p60vbc9illjyix15m-home-manager-files/.config/git/config
```

fzf comes from your profile in your home directory, not from `/usr/bin`,
so installing it didn’t need root.

The Git config is a link into the store. Home
Manager built every file in the store first, then linked each one into place.
Meaning your dotfiles now come from `home.nix`, and on a new machine one
`home-manager switch` puts all of them back.

If you already had that file, the first switch stops, because the old file is
in the way:

```console
$ home-manager switch
…
Existing file '/home/yurii/.config/git/config' would be clobbered
```

Run `home-manager switch -b backup` instead. Home Manager renames your old
file to `config.backup`, and then links the new one.

### Try it

`ripgrep` searches through files. Add `pkgs.ripgrep` after `pkgs.fzf` in `home.packages`.

- Add `pkgs.ripgrep` to `home.packages`home.nixHome ManagerA Home Manager module.

```nix
{ pkgs, ... }:

{
  home.username = "yurii";
  home.homeDirectory = "/home/yurii";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  home.packages = [ pkgs.fzf ];
}
```

`bat` is `cat` with syntax colors, and Home Manager has a module for it. Below the `home.packages` line, add `programs.bat.enable = true;`.

- Turn on `programs.bat`home.nixHome ManagerA Home Manager module.

```nix
{ pkgs, ... }:

{
  home.username = "yurii";
  home.homeDirectory = "/home/yurii";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  home.packages = [ pkgs.fzf ];
}
```

## programs

Installing a program is the easy part. Configuring it usually means a dotfile
in a format of its own: INI-style sections for Git, command line flags for
bat, TOML for Starship.

Adding `pkgs.git` to `home.packages` installs Git and nothing else.
`programs.git.enable = true;` does more: it installs Git and lets Home Manager
write Git’s config file from options in your `home.nix`. You describe the
settings in Nix, and Home Manager handles the syntax. It has modules like this
for hundreds of programs, all under `programs`.

`home.nix`:

```nix
{
  programs.git = {
    enable = true;
    settings = {
      user.name = "Yurii";
      user.email = "338125742+yurii@users.noreply.github.com";
    };
  };
}
```

After a switch, Home Manager has written `~/.config/git/config` in Git’s own
format:

```console
$ cat ~/.config/git/config
[user]
	email = "338125742+yurii@users.noreply.github.com"
	name = "Yurii"
```

Starship wants TOML instead, and its module takes the same kind of Nix set:

`home.nix`:

```nix
{
  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      directory.truncation_length = 2;
    };
  };
}
```

```console
$ cat ~/.config/starship.toml
add_newline = false
[directory]
truncation_length = 2
```

Notice how `directory.truncation_length` turned into a `[directory]` section,
just like `user.name` turned into `[user]` for Git. You write one shape in Nix,
and each module turns it into whatever its program reads.

These files are links into the read-only
Nix store, so editing them by hand won’t work. The
next change goes into `home.nix`, and the next switch writes a new file.

So if there is a `programs` module for something, it’s usually a better choice
than a plain package. The Home Manager manual lists every module and its
options.

### Try it

Give new repositories a `main` branch. Add `init.defaultBranch = "main";` inside `settings`, under the email line.

- Set `programs.git.settings.init.defaultBranch` to `"main"`home.nixexcerptHome ManagerA Home Manager module.

```nix
{
  programs.git = {
    enable = true;
    settings = {
      user.name = "Yurii";
      user.email = "338125742+yurii@users.noreply.github.com";
    };
  };
}
```

## home.file

Not every program has a Home Manager module, and sometimes you just want a
config file exactly as you wrote it. `home.file` puts any file anywhere in
your home directory.

Each name under `home.file` is a path inside your home directory. Its value says
where the content comes from. Write the content right in Nix with `text`, or
take an existing file or directory with `source`:

`home.nix`:

```nix
{
  home.file.".hushlogin".text = "";
  home.file.".config/nvim".source = ./nvim;
}
```

The first line makes an empty `~/.hushlogin`, which tells many Linux systems to
skip the welcome message when you log in. The second puts the `nvim` directory
that sits next to your `home.nix` at `~/.config/nvim`, with everything inside
it.

You’ll also see a shorter form for files in `~/.config`. These two do the same
thing:

`home.nix`:

```nix
{
  home.file.".config/nvim".source = ./nvim;
}
```

`home.nix`:

```nix
{
  xdg.configFile."nvim".source = ./nvim;
}
```

`xdg.configFile` is just `home.file` that starts in `~/.config`. Home
Manager’s own modules use it too. `programs.git`, for example, writes your Git
settings to `xdg.configFile."git/config"`.

The names are in quotes because without them, a dot starts a new name
inside the one before. Here is the same name written both ways:

```nix
{ init.lua = "a"; "init.lua" = "b"; }
```

The quoted `"init.lua"` stays one name. The bare `init.lua` turns into `lua`
inside `init`.

A name that starts with a dot is worse. Without quotes, Nix can’t even read
the file:

```nix
{ .hushlogin = ""; }
```

```nix
{ ".hushlogin" = ""; }
```

Names with a slash in them, like `".config/nvim"`, need quotes too.

Home Manager writes each file into the Nix store,
and puts a symlink to it at that path. After a
switch:

```console
$ ls -l ~/.hushlogin
lrwxrwxrwx 1 yurii users 73 Oct 11 01:01 /home/yurii/.hushlogin -> /nix/store/dnnzk6z4kgnw5shk7l55iqm08fkw611b-home-manager-files/.hushlogin
$ ls ~/.config/nvim
init.lua  lua
$ ls -lL ~/.hushlogin
-r--r--r-- 1 root root 0 Jan  1  1970 /home/yurii/.hushlogin
```

`-L` follows the link to the file itself. It shows `r--` with no `w`, and the
file belongs to `root`. Meaning the file is read only. To change it, you change
`home.nix` and switch again.

Home Manager also won’t overwrite a file you made yourself, unless you tell it
to. Say you already
had your own `~/.config/nvim` before you added it to `home.nix`. The switch
stops, and your directory stays as it was:

```console
$ home-manager switch
…
Please do one of the following:
- In standalone mode, use 'home-manager switch -b backup' to back up files automatically.
- When used as a NixOS or nix-darwin module, set either
  - 'home-manager.backupFileExtension', or
  - 'home-manager.backupCommand',
  to move the file to a new location in the same directory, or run a custom command.
- Set 'force = true' on the related file options to forcefully overwrite the files below. eg. 'xdg.configFile."mimeapps.list".force = true'
Existing file '/home/yurii/.config/nvim' would be clobbered
```

To get past it, move your directory away and switch again. Or switch with
`home-manager switch -b backup`. Home Manager then renames your directory to
`nvim.backup` for you.

### Try it

nano reads its settings from `~/.nanorc`. Turn on line numbers: add `home.file.".nanorc".text = "set linenumbers";` under the `.hushlogin` line.

- Write `set linenumbers` to `~/.nanorc` with `home.file`home.nixexcerptHome ManagerA Home Manager module.

```nix
{
  home.file.".hushlogin".text = "";
}
```

## Home Manager inside NixOS

Home Manager can run on its own, with its own `home-manager` command. Then your
system and your home update in two separate steps, and each keeps its own
history. Meaning rolling back the system leaves your home where it was.

On NixOS you can build your home together with the system instead. Then one
`nixos-rebuild switch` applies the system and every home in it. Roll the
system back, and your home goes back with it.

Home Manager ships a NixOS module for that,
`home-manager.nixosModules.home-manager`. Put it in your flake’s `modules` list
next to `./configuration.nix`. Then each user’s home goes under
`home-manager.users`:

`flake.nix`:

```nix
{
  description = "My NixOS machine";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager }: {
    nixosConfigurations.snowflake = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.yurii = import ./home.nix;
        }
      ];
    };
  };
}
```

Here yurii’s home comes from `home.nix`, the same kind of file a standalone
Home Manager uses. You can even leave out `home.username` and
`home.homeDirectory`, because the NixOS module fills them in from
`users.users.yurii`.

The home is now part of the system. One switch starts a service that sets up
yurii’s home. yurii’s Git config is then a link into the store:

```console
$ sudo nixos-rebuild switch --flake .#snowflake
[sudo] password for yurii:
building the system configuration...
…
activating the configuration...
…
the following new units were started: home-manager-yurii.service, …
$ readlink ~/.config/git/config
/nix/store/3gnfpkwdxa52fwmj7p9556b6gmfqihl5-home-manager-files/.config/git/config
```

`useGlobalPkgs = true;` gives your home the same `pkgs` as the rest of the
machine. Say your system allows unfree packages, and your home wants Discord:

`configuration.nix`:

```nix
{
  nixpkgs.config.allowUnfree = true;
}
```

`home.nix`:

```nix
{ pkgs, ... }:

{
  home.packages = [ pkgs.discord ];
}
```

With `useGlobalPkgs`, this builds. Without it, Home Manager imports nixpkgs a
second time just for your home. That copy never sees `allowUnfree`, so the
rebuild stops:

```console
$ sudo nixos-rebuild switch --flake .#snowflake
[sudo] password for yurii:
building the system configuration...
error:
       …
       error: Refusing to evaluate package 'discord-1.0.158' in /nix/store/…/discord/default.nix:70 because it has an unfree license (‘unfree’)
…
Command 'nix --extra-experimental-features 'nix-command flakes' build --print-out-paths '.#nixosConfigurations."snowflake".config.system.build.toplevel' --no-link' returned non-zero exit status 1.
```

Turn on `useUserPackages`, and your home’s packages come with the system.
`nixos-rebuild` installs them through `users.users.yurii.packages`. Ask the
flake for that list, and your whole home shows up in it as one package:

```console
$ nix eval .#nixosConfigurations.snowflake.config.users.users.yurii.packages
[ «derivation /nix/store/…-home-manager-path.drv» ]
```

Turn `useUserPackages` off, and that list is empty. Home Manager then installs
your packages into `~/.nix-profile` instead. That’s one more place to keep
track of.

Home Manager still can’t do what needs root. Say you want fish as
your login shell. Enabling fish
in `home.nix` installs fish and writes its configuration, but it can’t make
fish your login shell:

`home.nix`:

```nix
{
  programs.fish.enable = true;
}
```

Making it your login shell changes the system’s list of users, so that part
goes in `configuration.nix`. Set only the shell there, and NixOS stops the
rebuild:

```console
$ sudo nixos-rebuild switch --flake .#snowflake
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

So enable fish in `configuration.nix` too:

`configuration.nix`:

```nix
{ pkgs, ... }:

{
  programs.fish.enable = true;
  users.users.yurii.shell = pkgs.fish;
}
```

### Try it

anna has an account now, and an `anna.nix` next to `home.nix`. Under yurii's line, add `home-manager.users.anna = import ./anna.nix;`.

- Build anna's home from `anna.nix`, so anna gets fishflake.nixFlakeA flake with inputs and outputs.Project filesA file in the example project.

```nix
{
  description = "My NixOS machine";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager }: {
    nixosConfigurations.snowflake = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.yurii = import ./home.nix;
        }
      ];
    };
  };
}
```

## NixOS settings in Home Manager

When Home Manager runs as a NixOS module, your home and your system are built
together, and sometimes the home needs to know what the system did. Say one
`home.nix` is shared by your desktop and your server. fish is installed on the
desktop but not on the server, and you only want fish’s configuration where
fish actually is.

For that, Home Manager passes every home module an extra argument, `osConfig`.
It’s the NixOS `config`: the final value of every system option. Add it to the
header of `home.nix`, and you can read any NixOS option from there:

`home.nix`:

```nix
{ osConfig, ... }:

{
  home.stateVersion = "26.05";

  programs.fish.enable = osConfig.programs.fish.enable;
}
```

Now the fish configuration in your home follows the system. The desktop’s
`configuration.nix` has `programs.fish.enable = true;`, so your home configures
fish there. The server’s doesn’t, so your home leaves fish alone.

The machine’s host name is a NixOS option too, `networking.hostName`. Meaning
one `home.nix` can tell your machines apart. Here your commits get your work
email on the work laptop, and your own email everywhere else:

`home.nix`:

```nix
{ osConfig, ... }:

{
  home.stateVersion = "26.05";

  programs.git.enable = true;
  programs.git.settings.user.email =
    if osConfig.networking.hostName == "work-laptop"
    then "yurii@work.example"
    else "yurii@example.com";
}
```

Note that `osConfig` only reads. To change a NixOS option, you still set it
on the NixOS side. And it’s only filled in when Home Manager is part of NixOS.
In standalone Home Manager, `osConfig` is `null`, so reading an option
from it stops with `expected a set but found null: null`.

## Install Home Manager

Set up your home with the same rebuild that sets up your system.

Takes about 30 minutes.

You’ll:

- add Home Manager to your flake

- write a `home.nix` with fzf and your Git name and email

- rebuild, and find fzf installed and Git set up

Continues from Put it in Git.

Everything happens in your browser. Nothing gets installed on your computer.

## Take your home with you

Take the home you set up on NixOS to an Ubuntu laptop.

Takes about 30 minutes.

You’ll:

- let your `home.nix` work without NixOS, and push it to GitHub

- install Nix on the laptop and clone your repository

- run Home Manager there, without installing it

- end up with the same Git settings on both machines

Continues from Install Home Manager.

Both machines and GitHub are simulated.
Everything happens in your browser. Nothing gets installed on your computer.

