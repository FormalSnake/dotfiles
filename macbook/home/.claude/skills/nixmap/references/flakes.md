# Flakes

## Flakes

Almost all Nix code uses code from somewhere else, usually nixpkgs, the huge
collection of packages. But which version of it?

Here’s a `shell.nix`, a file that describes a shell with the tools a project
needs. This one only needs Python:

`shell.nix`:

```nix
let
  pkgs = import <nixpkgs> { };
in
pkgs.mkShell {
  packages = [ pkgs.python3 ];
}
```

`<nixpkgs>` means “whatever nixpkgs this machine points to”, which is usually
a channel. And every machine has its own. Here’s the same file on two laptops.
On one with this year’s nixpkgs:

```console
$ nix-shell
[nix-shell:~/my-project]$ python3 --version
Python 3.13.15
```

And on one with last year’s:

```console
$ nix-shell
[nix-shell:~/my-project]$ python3 --version
Python 3.12.12
```

The exact same shell, two different Pythons. Meaning a project that works on
your laptop can break on your friend’s, or even on your own the moment you
decide to update your NixOS.

A flake fixes that. It’s just a directory with a `flake.nix` file in it.
Let’s build one up from nothing. A very basic flake could look like this:

`flake.nix`:

```nix
{
  inputs = { };

  outputs = inputs: {
    mynumber = 67;
  };
}
```

A flake says two things. `inputs` is the stuff it wants to download from the
internet. `outputs` is any Nix code you want it to give back. Here, the flake
downloads nothing and gives back a number.

Don’t mind the `inputs:` in front of the braces for now. We’ll get to it as soon
as there’s something to download.

To get that number, ask for it with `nix eval`. The `.` means the flake in this
directory, and the part after `#` picks one of its outputs:
flake.nix

```
$ nix eval .#
67
```

Now let’s download something. Here’s the same flake with one input, nixpkgs:

`flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs = inputs: {
    mynumber = 67;
  };
}
```

Each input gets a name you pick, here `nixpkgs`, and a `url` that says where
to download it from. This one is the `nixos-26.05` branch of nixpkgs on
GitHub.

Ask for the number again:
flake.nix

```
$ nix eval .#
warning: creating lock file "/home/yurii/my-flake/flake.lock":
• Added input 'nixpkgs':
    'github:NixOS/nixpkgs/774debe7a0d1b496e35677ad955a1011c6ff74f3?narHash=sha256-nQyFkMR78WP6PiXKkDW2SjqzLf/spQqjRuxRGSbcV8k%3D' (2026-10-02)
67
```

Still 67, but look at the warning. Nix downloaded nixpkgs and made a second
file next to `flake.nix`, called `flake.lock`. That long line is what it wrote
in it: the exact commit of nixpkgs it got, `774debe`, from October 2.

That’s the lock. Your `flake.nix` only asks for a branch, and branches keep
moving. The lock remembers which commit you actually got, and from now on Nix
uses that one. Share `flake.lock` along with `flake.nix`, and everyone who uses
your flake gets that same commit too. If you’ve used npm, it’s the same idea as
`package.json` and `package-lock.json`.

Now let’s use what we downloaded. Remember the `inputs:` in front of `outputs`?
That’s because `outputs` is a function. Nix downloads every input first,
then calls `outputs` with all of them, each under the name you picked. So
`inputs.nixpkgs` is the whole of nixpkgs, and `inputs.nixpkgs.lib` is its
library of handy functions. `toUpper` is one of them, and it turns text into
capitals:

`flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs = inputs: {
    mynumber = 67;
    loud = inputs.nixpkgs.lib.toUpper "hello from nixpkgs";
  };
}
```

flake.nix

```
$ nix eval .#
"HELLO FROM NIXPKGS"
```

Now our Python shell. Let’s put it in the flake as an output called `myshell`:

`flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs = inputs:
    let
      pkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
    in
    {
      myshell = pkgs.mkShell {
        packages = [ pkgs.python3 ];
      };
    };
}
```

The `mkShell` part is copied straight from `shell.nix`, and so is the `pkgs`
line, almost. `import inputs.nixpkgs` loads nixpkgs and gives back its
packages, like `import <nixpkgs>` did. Only now it’s the nixpkgs from our
input, at the commit in the lock.

The one new part is `system = "x86_64-linux"`. Inside a flake, Nix doesn’t look
at the machine it runs on, so you tell nixpkgs which kind of machine you want
packages for. `x86_64-linux` means ordinary 64-bit Linux PCs.

Now step into the shell with `nix develop`:

```console
$ nix develop
error: flake 'path:/home/yurii/my-flake' does not provide attribute 'devShells.x86_64-linux.default', 'devShell.x86_64-linux', 'packages.x86_64-linux.default' or 'defaultPackage.x86_64-linux'
```

Nix can’t find our shell. It even says where it looked, right in the error.
The first spot it names, `devShells.x86_64-linux.default`, is where
`nix develop` expects a shell. It’s just this command’s convention:
`devShells`, then your system, then `default`.

So let’s move our shell there:

`flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs = inputs:
    let
      pkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
    in
    {
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = [ pkgs.python3 ];
      };
    };
}
```

```console
$ nix develop
$ python3 --version
Python 3.13.15
```

Now back to the two laptops. Copy the directory to both, `flake.lock` included,
and step into the shell. On the one with this year’s nixpkgs:

```console
$ nix develop
$ python3 --version
Python 3.13.15
```

And on the one with last year’s:

```console
$ nix develop
$ python3 --version
Python 3.13.15
```

Same flake, same lock, same Python. The nixpkgs each laptop has doesn’t matter
anymore. That’s the whole point of flakes.

Most flakes live in a Git repository, and that’s where almost everyone
trips up once. Nix only sees the files Git knows about. Say you’ve run
`git init` in the directory, but haven’t added anything yet. Step into the
shell, and Nix acts like the flake isn’t there:

```console
$ nix develop
error: Path 'flake.nix' in the repository "/home/yurii/my-flake" is not tracked by Git.
       To make it visible to Nix, run:
       git -C "/home/yurii/my-flake" add "flake.nix"
```

The error even tells you the fix. Add the files, and it works:

```console
$ git add .
$ nix develop
warning: Git tree '/home/yurii/my-flake' is dirty
$ python3 --version
Python 3.13.15
```

You don’t even have to commit. The warning only means you have changes you
haven’t committed yet. Commit when you’re happy, and it goes away.

The lock never moves by itself. When you do want newer packages, run
`nix flake update`. It moves every input to the newest commit on its branch,
and writes that into the lock:

```console
$ nix flake update
warning: updating lock file "/home/yurii/my-flake/flake.lock":
• Updated input 'nixpkgs':
    'github:NixOS/nixpkgs/774debe7a0d1b496e35677ad955a1011c6ff74f3?narHash=sha256-nQyFkMR78WP6PiXKkDW2SjqzLf/spQqjRuxRGSbcV8k%3D' (2026-10-02)
  → 'github:NixOS/nixpkgs/7993f34ee47e28a3d607a525aadc6c94b73be728?narHash=sha256-ZGq3ptZzA%2BoO0N/Wi/F%2BGbuTijLkYExD01LvpNFAvr0%3D' (2026-10-12)
```

Your `flake.nix` didn’t change. It still asks for `nixos-26.05`. Only the lock
caught up with the branch.

Don’t like what the update brought? The old lock is still in Git, so put it
back, and you’re on `774debe` again:

```console
$ git restore flake.lock
```

On NixOS with a flake, this is how you update your whole system. Run
`nix flake update`, then rebuild. And if something breaks, restore the old
lock and rebuild again.

Outputs aren’t only dev shells. Each kind has its own name, and the command
that uses it knows where to look:

- `devShells` are shells, for `nix develop`.

- `packages` are programs, for `nix run` and `nix build`.

- `nixosConfigurations` are whole NixOS systems, for `nixos-rebuild switch --flake`.

- `homeConfigurations` are Home Manager setups, for `home-manager switch --flake`.

Most flakes you’ll find look a little different from ours:

`flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs = { self, nixpkgs, ... }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in
    {
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = [ pkgs.python3 ];
      };
    };
}
```

It’s the same flake, written shorter in two places. First, the inputs are
unpacked right where `outputs` starts, so it can say `nixpkgs` instead of
`inputs.nixpkgs`. `self` is the flake itself, and the `...` lets `outputs`
ignore any inputs it doesn’t name.

Second, `nixpkgs.legacyPackages.x86_64-linux` takes the place of the whole
`import`. It’s the same package set, already imported by nixpkgs for every kind
of machine. You’ll see this shorthand everywhere. The name doesn’t mean the
packages are old.

The flake playground lets you wire all of this up yourself. Pick inputs, plug
outputs into them and commands into the outputs, and watch the `flake.nix` it
writes for you. Try to break it, too:
Toolbox

Add inputs, outputs and commands, and watch flake.nix change.

#### InputsnixpkgsHome Managermy-program source

#### OutputsNixOS systemHM homemy-program packagedev shell

#### CLInixos-rebuildhome-managernix buildnix developflake.nixflake.lock

```
1
2
3
4
```

```
{
  outputs = { self, ... }: {
  };
}
```
Your board is empty, so the flake offers nothing yet.0 piecesOpen flake playground

### Try it

Get the newest Python. Change `nixos-26.05` in the `url` to `nixos-unstable`.

- Point `nixpkgs` at the `nixos-unstable` branchflake.nixFlakeA flake with inputs and outputs.

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs = inputs:
    let
      pkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
    in
    {
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = [ pkgs.python3 ];
      };
    };
}
```

The lock still holds a `nixos-26.05` commit, so the next time you use the
flake, Nix moves that input over on its own:

```console
$ nix develop
warning: Git tree '/home/yurii/my-flake' is dirty
warning: updating lock file "/home/yurii/my-flake/flake.lock":
• Updated input 'nixpkgs':
    'github:NixOS/nixpkgs/774debe7a0d1b496e35677ad955a1011c6ff74f3?narHash=sha256-nQyFkMR78WP6PiXKkDW2SjqzLf/spQqjRuxRGSbcV8k%3D' (2026-10-02)
  → 'github:NixOS/nixpkgs/7fd4004d0511991fff3a0524856a9be09e28c5f0?narHash=sha256-i5qk1kLiit98rRbh1AXmWBNT9QXC/y4l5Wk/u5EdpDQ%3D' (2026-10-11)
$ python3 --version
Python 3.14.7
```

Make the flake give a program too. Below the dev shell's closing `};`, add `packages.x86_64-linux.default = pkgs.cowsay;`.

- Offer `cowsay` as the default package

- Keep the Python shellflake.nixFlakeA flake with inputs and outputs.

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs = inputs:
    let
      pkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
    in
    {
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = [ pkgs.python3 ];
      };
    };
}
```

Now `nix run` runs it. Anything after `--` goes to cowsay itself:

```console
$ nix run . -- moo
warning: Git tree '/home/yurii/my-flake' is dirty
 _____
< moo >
 -----
        \   ^__^
         \  (oo)\_______
            (__)\       )\/\
                ||----w |
                ||     ||
```

## Flake references

A flake reference is an address Nix knows how to fetch a flake from. You type
them all the time:

- `nix run nixpkgs#hello`

- `nix build .#hello`

- `sudo nixos-rebuild switch --flake .#snowflake`

The part before `#` is the address. The part after it is what you want from
that flake.

`.` is the flake in the directory you’re in.

`nixpkgs` is a short name. Nix looks it up in its registry, a list of names and
the addresses they stand for. Out of the box, `nixpkgs` means
nixpkgs-unstable. On NixOS built from a flake, commands like
`nix run nixpkgs#hello` get the nixpkgs your system is built from instead.

You also write one in a flake’s inputs, with the same syntax. It’s the
string in `url`, like `inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";`.
There, `nixpkgs` still means nixpkgs-unstable, even on NixOS.

Every address is made of a few parts: how to fetch it, where it lives, and
sometimes which version. Click the parts of each address to see what they do:

What gets pinned: Handy for quick commands. In a flake, flake.lock writes down the real address and the exact commit it found.nix build nixpkgs#hello

The part after the repository picks the version. It can be a branch, a tag or
an exact commit:

- `github:NixOS/nixpkgs/nixos-26.05` is a branch. It moves forward as the
branch gets updates. In an input, `flake.lock` still keeps you on one commit
until you run `nix flake update`.

- `github:NixOS/nixpkgs/26.05` is a tag. It names one commit and stays there.

- `github:NixOS/nixpkgs/2efa67fd26b6df417c33e4603185c701f260dd83` is one exact
commit.

And every address is also a shorthand for an attribute set, where each of those
pieces gets a name. These two `nixpkgs` inputs are the same input:

`flake.nix`:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }: { };
}
```

`flake.nix`:

```nix
{
  inputs.nixpkgs = {
    type = "github";
    owner = "NixOS";
    repo = "nixpkgs";
    ref = "nixos-26.05";
  };

  outputs = { self, nixpkgs }: { };
}
```

The short form is the one you’ll see almost everywhere. The long form is handy
when an address has many parts. Take
`git+https://example.org/team/tool?ref=v2&dir=nix`. It fetches a Git repository
from its `v2` branch. Then it uses the flake in the `nix` directory. In the long
form, each part gets its own line:

`flake.nix`:

```nix
{
  inputs.tool = {
    type = "git";
    url = "https://example.org/team/tool";
    ref = "v2";
    dir = "nix";
  };
}
```

### Try it

Write the `home-manager` input in its long form. Replace its `url` line with `inputs.home-manager = { };`, and give it one line each for `type`, `owner`, `repo` and `ref`.

- Fetch `nix-community/home-manager` from GitHub

- Follow the `release-26.05` branchflake.nixFlakeA flake with inputs and outputs.

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  inputs.home-manager.url = "github:nix-community/home-manager/release-26.05";

  outputs = { self, nixpkgs, home-manager }: {
    packages.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.hello;
  };
}
```

## Installables

Most `nix` commands take an address like `nixpkgs#hello`. You
type one every time you run a program or try it out in a shell:

```console
$ nix run nixpkgs#cowsay -- hi
 ____
< hi >
 ----
        \   ^__^
         \  (oo)\_______
            (__)\       )\/\
                ||----w |
                ||     ||
$ nix shell nixpkgs#hello
$ hello
Hello, world!
```

Different commands, same kind of address. Nix calls it an installable: a
flake reference, a `#`, and the path of an attribute inside that flake’s
outputs.

The part before `#` is an ordinary flake reference. `nixpkgs` is a nickname
Nix looks up in its flake registry, a list of short names for well-known
flakes. Out of the box it stands for nixpkgs-unstable, so that branch’s address on
GitHub gets you the same package:

```console
$ nix eval nixpkgs#cowsay.version
"3.8.4"
$ nix eval github:NixOS/nixpkgs/nixpkgs-unstable#cowsay.version
"3.8.4"
```

The part after `#` is the path to the thing you want. In nixpkgs, hello sits
deep in the outputs, under `legacyPackages`, then your system, then its name.
You can type all of that:

```console
$ nix eval nixpkgs#legacyPackages.x86_64-linux.hello.version
"2.12.3"
```

But you almost never do, because the short name finds the same package:

```console
$ nix eval nixpkgs#hello.version
"2.12.3"
```

Nix fills in the start for you, for the system you’re on. The
system is never in the short name. Meaning the same `nixpkgs#hello` works on a
Linux PC and on a Mac, and each one gets the hello built for it.

Misspell a name, and the error shows every place it looked:

```console
$ nix eval nixpkgs#helo
error: flake 'flake:nixpkgs' does not provide attribute 'packages.x86_64-linux.helo', 'legacyPackages.x86_64-linux.helo' or 'helo'
       Did you mean one of halo, hello, helm, below or belr?
```

Each command looks in its own place first. `nix run` tries `apps`, and
`nix develop` tries `devShells`:

```console
$ nix run nixpkgs#helo
error: flake 'flake:nixpkgs' does not provide attribute 'apps.x86_64-linux.helo', 'packages.x86_64-linux.helo', 'legacyPackages.x86_64-linux.helo' or 'helo'
       Did you mean one of halo, hello, helm, below or belr?
$ nix develop nixpkgs#helo
error: flake 'flake:nixpkgs' does not provide attribute 'devShells.x86_64-linux.helo', 'packages.x86_64-linux.helo', 'legacyPackages.x86_64-linux.helo' or 'helo'
       Did you mean one of halo, hello, helm, below or belr?
```

Last of all, Nix tries the path exactly as you wrote it. That’s how you reach
anything else in a flake. nixpkgs has a `lib` output next to `legacyPackages`,
so Nix finds it at the exact path you typed:

```console
$ nix eval nixpkgs#lib.licenses.mit.fullName
"MIT License"
```

`nixos-rebuild` has its own place too. It puts `nixosConfigurations.` in front
of the name you give it. Here is that line in its source in nixpkgs:

```console
$ grep -n "nixosConfigurations" pkgs/by-name/ni/nixos-rebuild-ng/src/nixos_rebuild/models.py
107:        nixos_attr = f'nixosConfigurations."{attr or cls._get_hostname(target_host) or "default"}"'
```

So `nixos-rebuild switch --flake .#laptop` looks up
`nixosConfigurations.laptop`. Leave out the name, and it uses your computer’s
hostname.

Your own flakes work the same way. Here a project’s flake offers cowsay, and
hello as its default package:

`flake.nix`:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }: {
    packages.x86_64-linux.cowsay = nixpkgs.legacyPackages.x86_64-linux.cowsay;
    packages.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.hello;
  };
}
```

```console
$ nix build .#cowsay
warning: creating lock file "/home/yurii/my-flake/flake.lock":
• Added input 'nixpkgs':
    'github:NixOS/nixpkgs/774debe7a0d1b496e35677ad955a1011c6ff74f3?narHash=sha256-nQyFkMR78WP6PiXKkDW2SjqzLf/spQqjRuxRGSbcV8k%3D' (2026-10-02)
$ ./result/bin/cowsay hi
 ____
< hi >
 ----
        \   ^__^
         \  (oo)\_______
            (__)\       )\/\
                ||----w |
                ||     ||
```

`.#cowsay` is the flake in this directory, then the name.

Leave out the name, and Nix builds `packages.x86_64-linux.default`. Plain
`nix build` means `.`. So these three build the same hello:

```console
$ nix build
$ nix build .
$ nix build .#default
$ ./result/bin/hello
Hello, world!
```

nixpkgs has no default package, so there the same thing fails. The error says
where Nix looked:

```console
$ nix build nixpkgs
error: flake 'flake:nixpkgs' does not provide attribute 'packages.x86_64-linux.default' or 'defaultPackage.x86_64-linux'
```

## follows

Inputs have inputs of their own. Home Manager’s flake depends on nixpkgs too,
and Nix locks that one to whatever commit Home Manager’s own `flake.lock`
says. So with just two inputs in your flake, you already get two copies of
nixpkgs:

```console
$ nix flake metadata
Resolved URL:  git+file:///tmp/dotfiles
Locked URL:    git+file:///tmp/dotfiles?ref=refs/heads/master&rev=50c54ed5bb49973cb217fa151697b767ea8e20a5
Path:          /nix/store/x5vmjdps4i4kbzs18d5mzidn0rr9pyh2-source
Revision:      50c54ed5bb49973cb217fa151697b767ea8e20a5
Revisions:     1
Last modified: 2026-10-07 15:39:51
Fingerprint:   81194a07c5d526457551f0ca382675c0865abae3d2e24b63e102736c9fea15c2
Inputs:
├───home-manager: github:nix-community/home-manager/db7d5e2332710f5abb088f6b5de927d7f9511b35?narHash=sha256-f%2BkOxEmOUnQazVAmGg0i8hzwgd1kX/geY%2Bk/Dpheye8%3D (2026-10-03 03:00:01)
│   └───nixpkgs: github:NixOS/nixpkgs/7fc6f2c20af09cdcaf48b92ec3121860139ec668?narHash=sha256-bNyvoIyOCu7lzoCpWKWGIsHpTtERUWzqYWFPlN%2B%2BWTw%3D (2026-09-28 22:43:15)
└───nixpkgs: github:NixOS/nixpkgs/2efa67fd26b6df417c33e4603185c701f260dd83?narHash=sha256-v72qr4LsSz61tQki/41nHKZKPY6NSeZavtGlAInOCng%3D (2026-10-07 06:11:14)
```

Both track `nixos-26.05`, just locked on different days. Meaning two nixpkgs
downloads where one would do.

`follows` tells Home Manager to use your nixpkgs instead. It’s one line under
Home Manager’s `url`:

`home-manager.inputs.nixpkgs.follows = "nixpkgs";`

The left side is a path into Home Manager’s inputs. The right side is the name
of your input.

Many flakes write it nested inside Home Manager’s input instead. Braces in
place of dots, but it’s the same line:

`flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager }: { };
}
```

With the one-line form in place, `nix flake metadata` shows:

```console
$ nix flake metadata
warning: Git tree '/tmp/dotfiles' is dirty
warning: updating lock file "/tmp/dotfiles/flake.lock":
• Updated input 'home-manager/nixpkgs':
    'github:NixOS/nixpkgs/7fc6f2c20af09cdcaf48b92ec3121860139ec668?narHash=sha256-bNyvoIyOCu7lzoCpWKWGIsHpTtERUWzqYWFPlN%2B%2BWTw%3D' (2026-09-28)
  → follows 'nixpkgs'
Resolved URL:  git+file:///tmp/dotfiles
Path:          /nix/store/ymqpr17na0kv4b1qb7kzbynlzbja5hzj-source
Revision:      50c54ed5bb49973cb217fa151697b767ea8e20a5-dirty
Last modified: 2026-10-07 15:39:51
Fingerprint:   950557e40eed3b51108868b6d523aa691bf9e5744e5ec83ce34d3e27bbd63aa9
Inputs:
├───home-manager: github:nix-community/home-manager/db7d5e2332710f5abb088f6b5de927d7f9511b35?narHash=sha256-f%2BkOxEmOUnQazVAmGg0i8hzwgd1kX/geY%2Bk/Dpheye8%3D (2026-10-03 03:00:01)
│   └───nixpkgs follows input 'nixpkgs'
└───nixpkgs: github:NixOS/nixpkgs/2efa67fd26b6df417c33e4603185c701f260dd83?narHash=sha256-v72qr4LsSz61tQki/41nHKZKPY6NSeZavtGlAInOCng%3D (2026-10-07 06:11:14)
```

The second copy is gone. But Home Manager now runs on a
nixpkgs commit its authors didn’t lock themselves. That’s why you pair
matching releases, `release-26.05` with `nixos-26.05`, so the two stay close.

You’ll write a line like this for almost every input that brings its own
nixpkgs, like Home Manager, nix-darwin or sops-nix.

### Try it

Under the `home-manager.url` line, add `home-manager.inputs.nixpkgs.follows = "nixpkgs";`.

- Make Home Manager's `nixpkgs` follow yoursflake.nixFlakeA flake with inputs and outputs.

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager.url = "github:nix-community/home-manager/release-26.05";
  };

  outputs = { self, nixpkgs, home-manager }: { };
}
```

## Packages from a second nixpkgs

A NixOS configuration takes every package from one nixpkgs, usually a release
branch like `nixos-26.05`. Sometimes you want one program newer than your
branch has, without moving the whole system to `nixos-unstable`. For that, add
a second nixpkgs input on the unstable branch, and take only that program from
it:

```console
$ cat flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
  };
  outputs = inputs: {
    nixosConfigurations.snowflake = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {
        pkgs-unstable = inputs.nixpkgs-unstable.legacyPackages.x86_64-linux;
      };
      modules = [ ./configuration.nix ];
    };
  };
}
$ cat configuration.nix
{ pkgs, pkgs-unstable, ... }:
{
  users.users.yurii = {
    isNormalUser = true;
    packages = [
      pkgs.git
      pkgs-unstable.zed-editor
    ];
  };
}
```

The new input gives you its packages under `legacyPackages.x86_64-linux`, the
package set for 64-bit Intel and AMD Linux. It’s the same kind of thing `pkgs`
is, only from the unstable branch.

`specialArgs` is a set of extra arguments every module can ask for. Here it
hands over that set as `pkgs-unstable`.

So yurii gets Git from `nixos-26.05` and Zed 1.21.0 from `nixos-unstable`,
while the system’s own `pkgs` still has Zed 1.3.6:

```console
$ nix eval .#nixosConfigurations.snowflake.config.users.users.yurii.packages
[ «derivation /nix/store/0x5gbp616f0hdkpm4hm9cdc48sk30ygn-git-2.54.0.drv» «derivation /nix/store/i9c9pp81jcx2f59xpdvdy3q0nf7z5crl-zed-editor-1.21.0.drv» ]
$ nix eval .#nixosConfigurations.snowflake.pkgs.zed-editor.version
"1.3.6"
```

Each input has its own entry in `flake.lock`. Meaning you can
move just one of them:

```console
$ nix flake update nixpkgs-unstable
warning: updating lock file "/tmp/tmp.GDuGlINHqo/flake.lock":
• Updated input 'nixpkgs-unstable':
    'github:NixOS/nixpkgs/88c4c23f3d6e5a4116ee19e148df5a0f2004f861?narHash=sha256-CDsV5NBbKeL37GoM2VPcPKQ4GUEdSf58CUex1d8B%2B/A%3D' (2026-09-27)
  → 'github:NixOS/nixpkgs/6510408d147d8c5e6d76043e899e9251756f6a75?narHash=sha256-XK4KceonkwD8LuMAt/vNrz982mXJM5jeHAxMwsUXXAQ%3D' (2026-10-10)
```

`nixpkgs` stays where it was.

Swap Zed for VS Code, which is unfree, and allow unfree packages the usual
NixOS way:

```console
$ cat configuration.nix
{ pkgs, pkgs-unstable, ... }:
{
  nixpkgs.config.allowUnfree = true;
  users.users.yurii = {
    isNormalUser = true;
    packages = [
      pkgs.git
      pkgs-unstable.vscode
    ];
  };
}
```

nixpkgs still refuses VS Code. And among its suggestions is the very line you
already have:

```console
$ nix eval .#nixosConfigurations.snowflake.config.users.users.yurii.packages
[ «derivation /nix/store/0x5gbp616f0hdkpm4hm9cdc48sk30ygn-git-2.54.0.drv» «error: Refusing to evaluate package 'vscode-1.140.0' in /nix/store/rhsxvv1380jmchb5p3a43d24mhlmp2ry-source/pkgs/applications/editors/vscode/vscode.nix:104 because it has an unfree license (‘unfree’)
a) To temporarily allow unfree packages, you can use an environment variable
   for a single invocation of the nix tools.
…
b) For `nixos-rebuild` you can set
  { nixpkgs.config.allowUnfree = true; }
in configuration.nix to override this.
…
```

That’s because `nixpkgs.config` only shapes `pkgs`. Your `pkgs-unstable` never
sees it.

nixpkgs itself is a function. Import the input, and you can call it with
settings of its own:

```console
$ cat flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
  };
  outputs = inputs: {
    nixosConfigurations.snowflake = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {
        pkgs-unstable = import inputs.nixpkgs-unstable {
          system = "x86_64-linux";
          config.allowUnfree = true;
        };
      };
      modules = [ ./configuration.nix ];
    };
  };
}
```

This `import` needs `system` spelled out, because a flake can’t look up
which system it runs on. Leave it out, and Nix stops with
`attribute 'currentSystem' missing`.

Now both packages evaluate:

```console
$ nix eval .#nixosConfigurations.snowflake.config.users.users.yurii.packages
[ «derivation /nix/store/0x5gbp616f0hdkpm4hm9cdc48sk30ygn-git-2.54.0.drv» «derivation /nix/store/f4yy7ln544dwsiml9h36v0mn2z1cf52x-vscode-1.140.0.drv» ]
```

## flake-parts

A flake’s `packages` and `devShells` need one entry per system. Say you want
`hello` as the default package on Linux PCs, ARM Linux machines and Apple
Silicon Macs. A plain flake writes the same line three times, once under each
system name, and asks nixpkgs for the matching `legacyPackages` each time:

`flake.nix`:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { nixpkgs, ... }: {
    packages.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.hello;
    packages.aarch64-linux.default = nixpkgs.legacyPackages.aarch64-linux.hello;
    packages.aarch64-darwin.default = nixpkgs.legacyPackages.aarch64-darwin.hello;
  };
}
```

Now offer cowsay as a second package. That’s three more lines, one per system
again:

`flake.nix`:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { nixpkgs, ... }: {
    packages.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.hello;
    packages.aarch64-linux.default = nixpkgs.legacyPackages.aarch64-linux.hello;
    packages.aarch64-darwin.default = nixpkgs.legacyPackages.aarch64-darwin.hello;
    packages.x86_64-linux.cowsay = nixpkgs.legacyPackages.x86_64-linux.cowsay;
    packages.aarch64-linux.cowsay = nixpkgs.legacyPackages.aarch64-linux.cowsay;
    packages.aarch64-darwin.cowsay = nixpkgs.legacyPackages.aarch64-darwin.cowsay;
  };
}
```

Every package gets copied once per system, and so does every dev shell.
flake-parts is a library that writes that part for you. It isn’t part of Nix or nixpkgs. It
lives in the `hercules-ci/flake-parts` repository on GitHub, and you add it
like any other input.

You hand `flake-parts.lib.mkFlake` your inputs and a set. `systems` lists the
systems you support. `perSystem` is written once, as a function that gets the
right `pkgs` for each of them. Here’s the same flake again, with one line per
package:

`flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];

      perSystem = { pkgs, ... }: {
        packages.default = pkgs.hello;
        packages.cowsay = pkgs.cowsay;
      };
    };
}
```

The `inputs@` gives the whole set of inputs one name, `inputs`, because
`mkFlake` wants all of them.

Both flakes give the same outputs. `nix flake show` lists the same six
packages for either one:

```console
$ nix flake show
git+file:///tmp/tmp.PcQeByc5aH/my-tool?ref=refs/heads/main&rev=f409ac695805d1b61e51eb610807652b87b43b4a
└───packages
    ├───aarch64-darwin
    │   ├───cowsay omitted (use '--all-systems' to show)
    │   └───default omitted (use '--all-systems' to show)
    ├───aarch64-linux
    │   ├───cowsay omitted (use '--all-systems' to show)
    │   └───default omitted (use '--all-systems' to show)
    └───x86_64-linux
        ├───cowsay: package 'cowsay-3.8.4'
        └───default: package 'hello-2.12.3'
```

There’s no system name inside `perSystem`. flake-parts takes
`pkgs` from your `nixpkgs` input, already picked for the system, and files
each package under every system in the list. That’s also why it wants an input
called `nixpkgs`.

So supporting another system means adding one word to `systems`, not one more
line for every package.

Not every output belongs to a system. A NixOS machine already says what it
runs on in its own configuration, so `nixosConfigurations` has no system names
in it. Outputs like that go under `flake`, next to `perSystem`, and come out
exactly as you write them:

`flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ flake-parts, nixpkgs, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];

      perSystem = { pkgs, ... }: {
        packages.default = pkgs.hello;
      };

      flake.nixosConfigurations.snowflake = nixpkgs.lib.nixosSystem {
        modules = [ ./configuration.nix ];
      };
    };
}
```

```console
$ nix flake show
git+file:///tmp/tmp.BwmxxPTcDr/my-tool?ref=refs/heads/main&rev=c45d4a28e4d3823b35ad3c3210a7f76774d3752a
├───nixosConfigurations
│   └───snowflake: NixOS configuration
└───packages
    ├───aarch64-darwin
    │   └───default omitted (use '--all-systems' to show)
    ├───aarch64-linux
    │   └───default omitted (use '--all-systems' to show)
    └───x86_64-linux
        └───default: package 'hello-2.12.3'
```

`snowflake` sits right under `nixosConfigurations`, with no system name around
it. The package still got one per system.

The set you hand `mkFlake` is a module, the same
kind as a NixOS configuration. So it can have `imports`, and a big `flake.nix`
splits into a few smaller files. Here `perSystem` moves into its own file. It
also gets a dev shell, which is copied per system just like a package:

`packages.nix`:

```nix
{
  perSystem = { pkgs, ... }: {
    packages.default = pkgs.hello;
    packages.cowsay = pkgs.cowsay;
    devShells.default = pkgs.mkShell {
      packages = [ pkgs.cowsay ];
    };
  };
}
```

`flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ ./packages.nix ];
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
    };
}
```

```console
$ nix flake show
git+file:///tmp/tmp.PcQeByc5aH/my-tool?ref=refs/heads/main&rev=2d2c35f652e0b6a8a31d74214f13e63cd15d82c0
├───devShells
│   ├───aarch64-darwin
│   │   └───default omitted (use '--all-systems' to show)
│   ├───aarch64-linux
│   │   └───default omitted (use '--all-systems' to show)
│   └───x86_64-linux
│       └───default: development environment 'nix-shell'
└───packages
    ├───aarch64-darwin
    │   ├───cowsay omitted (use '--all-systems' to show)
    │   └───default omitted (use '--all-systems' to show)
    ├───aarch64-linux
    │   ├───cowsay omitted (use '--all-systems' to show)
    │   └───default omitted (use '--all-systems' to show)
    └───x86_64-linux
        ├───cowsay: package 'cowsay-3.8.4'
        └───default: package 'hello-2.12.3'
```

The same six packages are there, and the dev shell came out once per system.

Say you want the `home-manager` command in your dev shell. It comes from
another flake, so you add it as a `home-manager` input. That flake files its
packages under system names too.

Every file you hand `mkFlake` can ask for your `inputs` at the top. Inside `perSystem`,
`system` is the name of the current system. With those two you can reach in
the long way:

`packages.nix`:

```nix
{ inputs, ... }:
{
  perSystem = { pkgs, system, ... }: {
    devShells.default = pkgs.mkShell {
      packages = [ inputs.home-manager.packages.${system}.default ];
    };
  };
}
```

`perSystem` also gets `inputs'`, with a quote at the end. With it, the same
line gets shorter:

`packages.nix`:

```nix
{
  perSystem = { pkgs, inputs', ... }: {
    devShells.default = pkgs.mkShell {
      packages = [ inputs'.home-manager.packages.default ];
    };
  };
}
```

They’re the same package. `inputs'` already picked the system for you.

You’ll meet this a lot, because many flakes on GitHub are written with
flake-parts. Here’s how nixvim’s `flake.nix` ends:

```console
$ tail -7 flake.nix
  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;
      imports = [ ./flake ];
    };
}
```

It’s the same `mkFlake`, with `systems` and `imports`. nixvim takes `inputs`
as one name instead of `inputs@{ ... }`, and reaches `flake-parts` through it
with a dot. Both ways hand `mkFlake` every input.

Its `systems` comes from an input too. That input is a tiny repository with
nothing but a list of system names. The rest of the flake lives in its `flake`
directory, pulled in by `imports`.

### Try it

Support ARM Linux machines too. Add `"aarch64-linux"` to the end of `systems`.

- Offer `hello` on ARM Linux machinesflake.nixFlakeA flake with inputs and outputs.

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-darwin" ];

      perSystem = { pkgs, ... }: {
        packages.default = pkgs.hello;
      };
    };
}
```

Offer cowsay on every system too. Add `packages.cowsay = pkgs.cowsay;` under the `packages.default` line.

- Offer `cowsay` on Linux PCs and on Apple Silicon Macsflake.nixFlakeA flake with inputs and outputs.

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];

      perSystem = { pkgs, ... }: {
        packages.default = pkgs.hello;
      };
    };
}
```

## Systems

A program built for a Linux PC won’t run on an Apple Silicon Mac. That’s why
`packages` and `devShells` have an extra level with a system name in it, like
`packages.x86_64-linux.default` or `packages.aarch64-darwin.default`.

A system name is just a CPU architecture and an operating system joined with a
dash. You’ll mostly meet four: `x86_64-linux` for ordinary Linux PCs,
`aarch64-linux` for ARM Linux machines, `aarch64-darwin` for Apple Silicon
Macs and `x86_64-darwin` for Intel Macs.

`flake.nix`:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }: {
    packages.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.hello;
    packages.aarch64-darwin.default = nixpkgs.legacyPackages.aarch64-darwin.hello;
  };
}
```

Note how each line names its system twice. Once to say who the package is
for, and once to ask nixpkgs for a `hello` built for that system, because
`legacyPackages` has a separate package set for every system it supports.
The name after `packages` only says where the package is filed, the one after
`legacyPackages` decides what gets built. Mix them up and Nix won’t complain,
it just hands a Mac a package built for Linux.

You rarely type the system on the command line. Nix fills in the one you’re
running on, so on a Linux PC `nix build .#cowsay` looks for
`packages.x86_64-linux.cowsay`, and `nix flake show` doesn’t even evaluate
the systems that aren’t yours:

```console
$ nix flake show
git+file:///tmp/my-tool?ref=refs/heads/master&rev=2bf86330b3d2bbba070f86cdd4dcd72eeb8c4110
└───packages
    ├───aarch64-darwin
    │   └───default omitted (use '--all-systems' to show)
    └───x86_64-linux
        └───default: package 'hello-2.12.3'
$ nix build .#cowsay
error: flake 'git+file:///tmp/my-tool' does not provide attribute 'packages.x86_64-linux.cowsay', 'legacyPackages.x86_64-linux.cowsay' or 'cowsay'
```

`nixosConfigurations` don’t get this level, because a NixOS configuration
names its system inside.

### Try it

Support ARM Linux machines too. Copy the `x86_64-linux` line, paste it right below, and change both `x86_64-linux` in the copy to `aarch64-linux`.

- Offer `packages.aarch64-linux.default`

- Build it for ARM Linuxflake.nixFlakeA flake with inputs and outputs.

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }: {
    packages.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.hello;
  };
}
```

Someone copied the Linux line for Macs and changed only the first system. Change `legacyPackages.x86_64-linux` in the `aarch64-darwin` line to `legacyPackages.aarch64-darwin`.

- Give Macs a `hello` built for `aarch64-darwin`flake.nixFlakeA flake with inputs and outputs.

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }: {
    packages.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.hello;
    packages.aarch64-darwin.default = nixpkgs.legacyPackages.x86_64-linux.hello;
  };
}
```

## Flakes only see files in Git

When your flake lives in a Git repository, Nix only lets it see files Git
knows about. A file you just created and never added is invisible, even though
it sits right next to `flake.nix`.

That’s because Nix copies your flake into the
store before it reads it, and it asks Git which files
to copy. Meaning files Git doesn’t track never end up in the store. That keeps
out a `result` link you listed in `.gitignore`. But it also keeps out a file you
forgot to add.

Here `flake.nix` reads a second file, `shell.nix`, with `import`. But
`shell.nix` was never added to Git:

```console
$ git status --short
?? shell.nix
$ nix develop
error:
       … while calling the 'import' builtin
         at /tmp/my-project/flake.nix:5:38:
            4|   outputs = { self, nixpkgs }: {
            5|     devShells.x86_64-linux.default = import ./shell.nix {
             |                                      ^
            6|       pkgs = nixpkgs.legacyPackages.x86_64-linux;
       error: Path 'shell.nix' in the repository "/tmp/my-project" is not tracked by Git.
       To make it visible to Nix, run:
       git -C "/tmp/my-project" add "shell.nix"
$ git add shell.nix
$ nix develop --command node --version
warning: Git tree '/tmp/my-project' is dirty
v24.21.0
```

Nix even prints the command that fixes it. Note that `git add` is enough,
because Nix needs the file tracked, not committed. Until you commit, it only
warns that the Git tree is dirty and carries on.

So the rule of thumb: every time you create a new file for your flake,
`git add` it before you run anything.

## Put it in Git

Put your configuration on GitHub, so you can get it back on any machine.

Takes about 35 minutes.

You’ll:

- turn `~/nixos-config` into a Git repository, and see why Nix wants your files
added to Git

- make your first commit

- give GitHub an SSH key and push your configuration to it

- add `htop` to your system and push that too

Continues from Turn it into a flake.

GitHub is part of the simulation, so you don’t need an account.
Everything happens in your browser. Nothing gets installed on your computer.

