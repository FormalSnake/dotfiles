# Nix CLI

## Installing Nix

On NixOS, Nix is already installed. On macOS or any other Linux,
the installer from nixos.org/download sets it
up next to your existing system. This is the command most people want:

```console
$ curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install | sh -s -- --daemon
```

That’s the multi-user install. Pick it on macOS, and on any Linux that runs
systemd, has SELinux turned off and lets you use `sudo`.

It creates `/nix` and puts the Nix store inside it. A background
service, the Nix daemon, runs every build as a separate build user, one
that can’t write to your home directory. So a build never touches your own
files.

If your machine doesn’t fit, use the single-user install. It skips the daemon,
so builds run as you, and `/nix` belongs to you:

```console
$ curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install | sh -s -- --no-daemon
```

When it finishes, open a new terminal. The installer added a few lines to your
shell’s startup files to put `nix` on your `PATH`, and only a new terminal
reads them. Check that `nix` is there. Your version will likely be newer than
this one:

```console
$ nix --version
nix (Nix) 2.34.8
```

Flakes and `nix` commands are still experimental. Turn them on first:NixOSNixOne command

On NixOS, for every user. Add this to `configuration.nix`, and rebuild:
`configuration.nix`:

```nix
{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
```

On any other Linux or macOS, for your user. Add one line to `~/.config/nix/nix.conf`:

```console
$ mkdir -p ~/.config/nix
$ echo "extra-experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

Just this once, with nothing saved. Put the flag right after `nix`:

```console
$ nix --extra-experimental-features "nix-command flakes" run nixpkgs#hello
Hello, world!
```

Now try one. `nix run` downloads GNU Hello and runs it, without installing
anything:

```console
$ nix run nixpkgs#hello
Hello, world!
```

If you ever want Nix gone again, the Nix manual has
uninstall steps for
each kind of install.

## Legacy and experimental commands

Nix comes with two sets of commands, and guides use both, so it helps to tell
them apart at a glance.

The legacy commands have a dash in their name: `nix-build`, `nix-shell`,
`nix-env`, `nix-store`, `nix-instantiate`, `nix-channel` and
`nix-collect-garbage`. They’ve been around for many years, they’re stable, and
they work on every install right away. You point them at a `.nix` file, and
they find nixpkgs through `<nixpkgs>`, the copy your setup points to.

The experimental commands are one `nix` command with a subcommand after a
space: `nix build`, `nix shell`, `nix run`, `nix develop`, `nix flake` and
more. They were designed together with flakes, so most of them take a flake
address like `nixpkgs#hello`. Their interface can still change, and a fresh
install leaves them switched off.

Here’s the same job, evaluating `6 * 7`, done both ways:

```console
$ nix-instantiate --eval -E '6 * 7'
42
$ nix eval --expr '6 * 7'
42
```

Most commands have a match in the other set:

- `nix-build` reads a `default.nix`. `nix build` reads a `flake.nix`.

- `nix-shell -p hello` matches `nix shell nixpkgs#hello`.

- `nix-shell` on its own reads a `shell.nix`. Its match is `nix develop`.

- `nix-env -iA nixpkgs.hello` matches `nix profile add nixpkgs#hello`.

- `nix-collect-garbage` matches `nix store gc`.

The dash matters. `nix build` and `nix-build` look for different
files. Try both in a directory with only a flake in it:

```console
$ ls
flake.lock  flake.nix
$ nix build
$ ls
flake.lock  flake.nix  result
$ nix-build
error: path '/home/alice/project/default.nix' does not exist
```

The trickiest pair is `nix-shell` and `nix shell`. With `-p`, both give you
hello. Without it, `nix-shell` goes looking for a file instead:

```console
$ nix-shell -p hello --run hello
Hello, world!
$ nix shell nixpkgs#hello --command hello
Hello, world!
$ nix-shell
error: no argument specified and no 'shell.nix' or 'default.nix' file found in the working directory
```

Older guides and the NixOS manual mostly use the dashed ones. Flake READMEs use
the new ones. Since the dash changes what runs, type the command exactly as the
guide writes it.

Both sets work on the same Nix store. Here’s hello built with each from the
same nixpkgs, and both land on the very same store path:

```console
$ nix-build '<nixpkgs>' -A hello
/nix/store/9lmc8ad19psaj2cpwav6a0yzjqlrn00j-hello-2.12.3
$ nix build nixpkgs#hello --print-out-paths
/nix/store/9lmc8ad19psaj2cpwav6a0yzjqlrn00j-hello-2.12.3
```

Meaning a package built by one is already there for the other. So you can mix
them freely. Many people use the experimental commands for their flakes and
still reach for a legacy one now and then.

## nix-build

Plenty of READMEs and guides still tell you to run `nix-build`, or
`nix-build '<nixpkgs>' -A hello`. It builds a Nix file and leaves a `result`
link to what it built in the current directory. The newer command for the same
job is `nix build`.

Here’s a tiny derivation that writes one line into its output:

`hello-world.nix`:

```nix
derivation {
  name = "hello-world";
  system = "x86_64-linux";
  builder = "/bin/sh";
  args = [ "-c" "echo hello world > $out" ];
}
```

Give `nix-build` the file, and it builds it:

```console
$ nix-build hello-world.nix
this derivation will be built:
  /nix/store/dp5na63mzhc3a2kkiy37b3xq642k7lhy-hello-world.drv
building '/nix/store/dp5na63mzhc3a2kkiy37b3xq642k7lhy-hello-world.drv'...
/nix/store/kbh84yclhgn33j34j9i4wxha04v79q5f-hello-world
$ readlink result
/nix/store/kbh84yclhgn33j34j9i4wxha04v79q5f-hello-world
$ cat result
hello world
```

The last line `nix-build` prints is the store path it built, and `result`
points right at it.

Leave the file out, and `nix-build` builds `default.nix` from the current
directory:

`default.nix`:

```nix
derivation {
  name = "hello-world";
  system = "x86_64-linux";
  builder = "/bin/sh";
  args = [ "-c" "echo hello world > $out" ];
}
```

```console
$ ls
default.nix
$ nix-build
/nix/store/kbh84yclhgn33j34j9i4wxha04v79q5f-hello-world
```

Nothing was built this time. `hello-world` was already in the store from the
last run.

A file can also hold a whole set of packages. Here `packages.nix` has two:

`packages.nix`:

```nix
{
  hello = derivation {
    name = "hello";
    system = "x86_64-linux";
    builder = "/bin/sh";
    args = [ "-c" "echo hello > $out" ];
  };
  bye = derivation {
    name = "bye";
    system = "x86_64-linux";
    builder = "/bin/sh";
    args = [ "-c" "echo bye > $out" ];
  };
}
```

`-A` picks one of them by its name:

```console
$ nix-build packages.nix -A bye
this derivation will be built:
  /nix/store/4dbnb2x5s0lb1jfc5qbkaidz714kqviy-bye.drv
building '/nix/store/4dbnb2x5s0lb1jfc5qbkaidz714kqviy-bye.drv'...
/nix/store/56m4lg6glk2rr171wflwb40km215hmmg-bye
$ cat result
bye
```

nixpkgs is exactly such a set, only much bigger. Give
`nix-build` `'<nixpkgs>'` as the file and `-A hello`, and it builds the `hello`
package from your machine’s copy of nixpkgs:

```console
$ nix-build '<nixpkgs>' -A hello
/nix/store/9lmc8ad19psaj2cpwav6a0yzjqlrn00j-hello-2.12.3
$ ./result/bin/hello
Hello, world!
```

`hello` was already in the store, so all it printed is the path.

The quotes around `<nixpkgs>` keep your shell from reading `<` and `>`.

Add `--no-out-link` when you don’t want the `result` link. It still prints the
path, but leaves your directory alone. That’s handy in a script, which only
needs the path:

```console
$ nix-build '<nixpkgs>' -A hello --no-out-link
/nix/store/9lmc8ad19psaj2cpwav6a0yzjqlrn00j-hello-2.12.3
$ $(nix-build '<nixpkgs>' -A hello --no-out-link)/bin/hello
Hello, world!
```

Here’s the same `bye` built both ways:

```console
$ nix-build packages.nix -A bye
/nix/store/56m4lg6glk2rr171wflwb40km215hmmg-bye
$ nix build --file packages.nix bye
$ readlink result
/nix/store/56m4lg6glk2rr171wflwb40km215hmmg-bye
```

Same store path. Only the way you name the file and the package changes.

## nix-shell

Need a program for a few minutes, without installing it? `nix-shell` starts a
Bash shell with extra packages on your `PATH`. It’s
always Bash, even if you normally use another shell. With `-p`, you list the
packages by their names in nixpkgs:

```console
$ nix-shell -p hello jq
[nix-shell:~]$ hello
Hello, world!
[nix-shell:~]$ jq --version
jq-1.8.2
[nix-shell:~]$ exit
exit
$ hello
bash: hello: command not found
```

Notice how `hello` is gone after `exit`. Meaning it was never installed. The
shell only borrowed it.

To run one command and come straight back, put it after `--run`:

```console
$ nix-shell -p hello --run hello
Hello, world!
```

`nix-shell` can also sit at the top of a script. Then the script brings its
own tools:

```console
$ cat name.sh
#!/usr/bin/env nix-shell
#! nix-shell -i bash -p jq
echo '{"name": "nix"}' | jq .name
$ ./name.sh
"nix"
```

`-i bash` says which program runs the rest of the file. Whoever runs the script
doesn’t need to install jq first.

The packages come from the nixpkgs your machine already has, usually a
channel. So the jq you get depends on when that
channel was last updated.

To pick the nixpkgs yourself, pass it with `-I`. Point it at one exact commit,
and everyone who runs the line gets the same jq:

```console
$ nix-shell -p jq -I nixpkgs=https://github.com/NixOS/nixpkgs/archive/774debe7a0d1b496e35677ad955a1011c6ff74f3.tar.gz --run "jq --version"
unpacking 'https://github.com/NixOS/nixpkgs/archive/774debe7a0d1b496e35677ad955a1011c6ff74f3.tar.gz' into the Git cache...
jq-1.8.2
```

Projects often start their README with a list of things to install first. A
`shell.nix` replaces that list. It sits in the project directory, and its
`packages` list is what the shell gets:

`shell.nix`:

```nix
let
  pkgs = import <nixpkgs> { };
in
pkgs.mkShell {
  packages = [ pkgs.cowsay ];
}
```

Run `nix-shell` without `-p` next to it, and cowsay is there:

```console
$ nix-shell
[nix-shell:~/my-project]$ cowsay moo
 _____
< moo >
 -----
        \   ^__^
         \  (oo)\_______
            (__)\       )\/\
                ||----w |
                ||     ||
```

Meaning anyone who clones the project and types `nix-shell` gets cowsay. Add
the same `-I` as before, and they get the same cowsay too.

Without `-p`, `nix-shell` looks for `shell.nix` in the current directory, then
`default.nix`. It stops with an error when there’s neither:

```console
$ nix-shell
error: no argument specified and no 'shell.nix' or 'default.nix' file found in the working directory
```

## nix repl

Writing an expression into a file just to see its value gets old fast.
`nix repl` gives you an interactive prompt instead: type an expression, press
Enter, and it prints the value right away. So whenever you’re unsure how some
piece of Nix behaves, try it here first, without touching any of your real
files. The editable boxes on this map work the same way, just inside your
browser.

The repl also lets you name a value with `name = value`. You can use that name
in everything you type afterwards. Here’s a short real session:

```console
$ nix repl
Nix 2.34.8
Type :? for help.
nix-repl> 2 + 3
5
nix-repl> port = 8080
nix-repl> port + 1
8081
nix-repl> :l <nixpkgs>
Added 27249 variables.
…
nix-repl> hello.version
"2.12.3"
nix-repl> hello.meta.description
"Program that produces a familiar, friendly greeting"
nix-repl> :q
```

Notice the lines that start with a colon. They aren’t Nix, they’re commands
for the repl itself. `:?` lists all of them, and `:q` quits.

The one you’ll use most is `:l <nixpkgs>`. `<nixpkgs>` means the copy of
nixpkgs your system is set up with. `:l` loads it, so every package becomes a
name you can type, like `hello` above. That’s where the 27249 variables come
from.

You don’t need to know what’s inside a package to look around. Type
`hello.meta.` and press Tab. The repl lists everything in hello’s `meta`, the
set of facts about the package:

```console
nix-repl> hello.meta.
hello.meta.available            hello.meta.maintainersPosition
hello.meta.broken               hello.meta.name
hello.meta.changelog            hello.meta.nonTeamMaintainers
hello.meta.description          hello.meta.outputsToInstall
hello.meta.homepage             hello.meta.platforms
hello.meta.identifiers          hello.meta.position
hello.meta.insecure             hello.meta.problems
hello.meta.license              hello.meta.unfree
hello.meta.longDescription      hello.meta.unsupported
hello.meta.mainProgram
hello.meta.maintainers
nix-repl> hello.meta.homepage
"https://www.gnu.org/software/hello/manual/"
```

Two more commands take you from looking to doing. `:e hello` opens hello’s
`package.nix` in your editor, so you can read how it’s made. `:b hello` builds
it and tells you where it landed in the store:

```console
nix-repl> :b hello
This derivation produced the following outputs:
  out -> /nix/store/9lmc8ad19psaj2cpwav6a0yzjqlrn00j-hello-2.12.3
```

Your own flake works too. `:lf .` loads the flake in the current directory,
and its outputs become names you can type. On a NixOS machine with a flake,
that lets you read any option of your system without rebuilding. Say the flake’s
`configuration.nix` sets `networking.hostName = "snowflake";` and turns on SSH
with `services.openssh.enable = true;`:

```console
$ nix repl
Nix 2.34.8
Type :? for help.
nix-repl> :lf .
Added 13 variables.
_type, inputs, lastModified, lastModifiedDate, narHash, nixosConfigurations, outPath, outputs, rev, revCount, shortRev, sourceInfo, submodules
nix-repl> nixosConfigurations.snowflake.config.networking.hostName
"snowflake"
nix-repl> nixosConfigurations.snowflake.config.services.openssh.ports
[ 22 ]
```

The file never mentions a port. 22 is the default the SSH module picked, and
the repl shows it anyway, because `config` is the finished system with every
default filled in.

## Experimental features

The newer `nix` commands, like `nix build` and `nix run`, and flakes are
experimental features, and a fresh install of Nix leaves them switched off.
Using one prints an error that names the missing feature:

```console
$ nix eval --expr '1 + 2'
error: experimental Nix feature 'nix-command' is disabled; add '--extra-experimental-features nix-command' to enable it
```

`nix-command` switches on the `nix` subcommands, and `flakes` switches on
flakes. You almost always want both, because addresses like `nixpkgs#hello`
need the two together.

Flakes and `nix` commands are still experimental. Turn them on first:NixOSNixOne command

On NixOS, for every user. Add this to `configuration.nix`, and rebuild:
`configuration.nix`:

```nix
{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
```

On any other Linux or macOS, for your user. Add one line to `~/.config/nix/nix.conf`:

```console
$ mkdir -p ~/.config/nix
$ echo "extra-experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

Just this once, with nothing saved. Put the flag right after `nix`:

```console
$ nix --extra-experimental-features "nix-command flakes" run nixpkgs#hello
Hello, world!
```

The line in the Nix tab starts with `extra-`. That makes it add these two to
the features already on, instead of replacing the whole list.

`nix repl` is an exception. It starts even with both features
switched off.

## nix eval

Sometimes you want one value and no conversation. `nix eval` evaluates a
single expression, prints the result and exits, which makes it handy in
scripts and for quick checks. With `--expr`, the expression comes straight
from the command line, so wrap it in single quotes to keep your shell from
touching it.

```console
$ nix eval --expr '6 * 7'
42
$ nix eval --expr '"hello-" + "2.12.3"'
"hello-2.12.3"
```

It can also read a value straight out of a package. `nixpkgs#hello` names the
`hello` package in nixpkgs, and `.version` picks its version:

```console
$ nix eval nixpkgs#hello.version
"2.12.3"
$ nix eval nixpkgs#hello.meta.description
"Program that produces a familiar, friendly greeting"
```

The version comes back in quotes, because `nix eval` prints a value the way Nix
would write it. That’s easy for you to read, but a script usually wants just
the text. Add `--raw`, and you get the bare string:

```console
$ nix eval --raw nixpkgs#hello.version
2.12.3
$ echo "hello is at version $(nix eval --raw nixpkgs#hello.version)"
hello is at version 2.12.3
```

Lists and sets have no bare text form. When another program reads them, add
`--json`. Here’s the same set both ways:

```console
$ nix eval --expr '{ name = "hello"; tags = [ "gnu" "demo" ]; }'
{ name = "hello"; tags = [ "gnu" "demo" ]; }
$ nix eval --json --expr '{ name = "hello"; tags = [ "gnu" "demo" ]; }'
{"name":"hello","tags":["gnu","demo"]}
```

The version you see depends on which nixpkgs revision `nixpkgs` points to on
your machine.

## nix build

Sometimes you want a package as real files on your disk. Maybe to check that
it builds, or to look at what’s inside.

`nix build` builds something into the Nix store. Give it a package, like
`nixpkgs#hello`. That’s the `hello` package from nixpkgs.

Before you build anything, ask Nix what it would do. Add `--dry-run`:

```console
$ nix build nixpkgs#hello --dry-run
these 5 paths will be fetched (10.8 MiB download, 36.2 MiB unpacked):
  /nix/store/znb3q6g1ik34454j3vcjx824h1871asg-glibc-2.42-84
  /nix/store/9lmc8ad19psaj2cpwav6a0yzjqlrn00j-hello-2.12.3
  /nix/store/8pf3c5kh87gpzyfm8cc3lym5j14npzyw-libidn2-2.3.8
  /nix/store/39m23yla3lnw563f4a1sa6hnn0dgjyj1-libunistring-1.4.2
  /nix/store/hna4zsz4rdnl4mdbmwmks7cx3cdkkyqc-xgcc-15.3.0-libgcc
```

Notice that Nix plans to fetch five paths and build nothing. Meaning “build”
doesn’t always mean compiling. This exact `hello` is already on
`cache.nixos.org`, so Nix just downloads it. The other four paths are
libraries `hello` needs to run, like glibc.

Now build it for real. `nix build` leaves a symlink called `result` in the
current directory. It points at the package in the store. Run the program
straight from the link:

```console
$ nix build nixpkgs#hello
$ ./result/bin/hello
Hello, world!
$ readlink result
/nix/store/9lmc8ad19psaj2cpwav6a0yzjqlrn00j-hello-2.12.3
```

`nix build` printed nothing when it finished. The `result` link is how you
find what it built.

Now run the dry run again. `hello` is in your store, so there’s nothing left
to do. It prints nothing:

```console
$ nix build nixpkgs#hello --dry-run
```

Most of the time, though, you build your own project. In a directory with a
flake, plain `nix build` builds the flake’s default package. Here the default
is a tiny script of your own, called `greet`:

`flake.nix`:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in
    {
      packages.x86_64-linux.default = pkgs.writeShellScriptBin "greet" ''
        echo "Hello from my own flake!"
      '';
      packages.x86_64-linux.cowsay = pkgs.cowsay;
    };
}
```

```console
$ nix build
warning: creating lock file "/home/yurii/my-flake/flake.lock":
• Added input 'nixpkgs':
    'github:NixOS/nixpkgs/774debe7a0d1b496e35677ad955a1011c6ff74f3?narHash=sha256-nQyFkMR78WP6PiXKkDW2SjqzLf/spQqjRuxRGSbcV8k%3D' (2026-10-02)
$ ./result/bin/greet
Hello from my own flake!
```

You didn’t name a package here. These three are the same build:

```console
$ nix build
$ nix build .
$ nix build .#default
```

The `.` is the flake in this directory. The `#default` picks its default
package. To build another package, put its name after `.#`:

```console
$ nix build .#cowsay
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

`nixpkgs#hello` at the top works the same way. `nixpkgs` is a short name that
Nix looks up in its registry. Out of the box, it stands for
nixpkgs-unstable.

You’ll also meet projects without a flake. They keep their recipe in a plain
`.nix` file, and you pass that file with `--file`. Here’s a tiny derivation
that writes one line into its output:

`hello-world.nix`:

```nix
derivation {
  name = "hello-world";
  system = "x86_64-linux";
  builder = "/bin/sh";
  args = [ "-c" "echo hello world > $out" ];
}
```

```console
$ nix build --file hello-world.nix
$ cat result
hello world
```

In a script, you usually want the store path itself. `--print-out-paths`
prints it when the build is done. `--no-link` skips the `result` link, so
nothing is left in your directory:

```console
$ nix build nixpkgs#hello --no-link --print-out-paths
/nix/store/9lmc8ad19psaj2cpwav6a0yzjqlrn00j-hello-2.12.3
$ $(nix build nixpkgs#hello --no-link --print-out-paths)/bin/hello
Hello, world!
```

When a build fails, `nix build` stops and shows the end of the build’s log.
Say you make a typo and write `$oot` instead of `$out`:

`hello-world.nix`:

```nix
derivation {
  name = "hello-world";
  system = "x86_64-linux";
  builder = "/bin/sh";
  args = [ "-c" "echo hello world > $oot" ];
}
```

```console
$ nix build --file hello-world.nix
error: Cannot build '/nix/store/03xwlws9siwmmsw2g2k1zpjhlvsb95jy-hello-world.drv'.
       Reason: builder failed with exit code 1.
       Output paths:
         /nix/store/rlif6968wqr1f6g6mxy7g6kdbg6jv4sa-hello-world
       Last 1 log lines:
       > sh: can't create : nonexistent directory
       For full logs, run:
         nix log /nix/store/03xwlws9siwmmsw2g2k1zpjhlvsb95jy-hello-world.drv
```

The line starting with `>` comes from the build itself. `$oot` is empty, so
`sh` tries to write to a file with no name. For the whole log, run the
`nix log` command at the end.

While a build runs, `nix build` hides its log. Add `-L` to see it. Here the
builder forgets `> $out`, so `hello world` goes to the log instead:

`hello-world.nix`:

```nix
derivation {
  name = "hello-world";
  system = "x86_64-linux";
  builder = "/bin/sh";
  args = [ "-c" "echo hello world" ];
}
```

```console
$ nix build --file hello-world.nix -L
hello-world> hello world
error: builder for '/nix/store/m8s2qvxd5rag0kr3i2agyyq7ckjidri0-hello-world.drv' failed to produce output path for output 'out' at "/nix/store/m8s2qvxd5rag0kr3i2agyyq7ckjidri0-hello-world.drv.chroot/root/nix/store/wmhy6sa98m5s8gf4m2r5nmkp1v6sa8ky-hello-world"
```

The `hello-world>` line is the build’s own output, with the package name in
front. The error says why the build failed. Nothing was
written to `$out`.

## nix shell

Want to try a tool without installing it? `nix shell` starts a new shell with
the packages you ask for on your `PATH`. Close that shell, and they’re off
your `PATH` again, with nothing added to your system’s package list.

Each package is written as an address. The part before `#` says where to get
it, and the part after `#` says which package:

- `nixpkgs#jq` is jq from nixpkgs

- `github:NixOS/nixpkgs/nixos-24.05#jq` is jq from the `nixos-24.05` branch on GitHub

- `.#my-tool` is `my-tool` from the flake in the current directory

For nixpkgs, the name after `#` is the package’s name, the same one
search.nixos.org shows.

You can ask for several packages at once:

```console
$ jq --version
bash: jq: command not found
$ nix shell nixpkgs#hello nixpkgs#jq
$ hello
Hello, world!
$ jq --version
jq-1.8.2
$ exit
exit
$ jq --version
bash: jq: command not found
```

The new shell is your usual one, the one your `SHELL` variable
names. So your prompt, aliases and completions all come along.

The address decides which version you get. An older branch of nixpkgs has an
older jq:

```console
$ nix shell github:NixOS/nixpkgs/nixos-24.05#jq
$ jq --version
jq-1.7.1
```

The packages stay in the Nix store until you collect garbage. So the next time
you ask for the same ones, Nix reuses them instead of downloading them again.

To run just one command, put it after `--command`. Nix runs it with the
packages on your `PATH`, and you’re back in your shell right away:

```console
$ nix shell nixpkgs#jq --command jq .version package.json
"1.4.2"
```

Not to be confused with `nix-shell`, with a dash. Both of these give you a
shell with jq:

```console
$ nix-shell -p jq
```

```console
$ nix shell nixpkgs#jq
```

The dashed one is the legacy command, and it always starts Bash.

## nix run

Sometimes you need a program once, to try it or for a single job. `nix run`
runs it straight from a flake, without installing it.

Give it an address like `nixpkgs#hello`, which means the `hello` package from
nixpkgs. It fetches or builds the package, runs its program, and drops you
back where you were:

```console
$ nix run nixpkgs#hello
Hello, world!
$ hello
bash: hello: command not found
```

The program ran, but it isn’t installed. Type `hello` on its own afterwards,
and your shell can’t find it.

Anything after `--` goes to the program instead of to `nix`:

```console
$ nix run nixpkgs#hello -- --greeting "Hello from nix run"
Hello from nix run
```

You’ll meet this in project READMEs too. Many say to try a tool with
`nix run github:owner/repo`. That runs it straight from its repository, without
cloning anything. nixpkgs itself is a repository on GitHub:

```console
$ nix run github:NixOS/nixpkgs#hello
Hello, world!
```

A package’s name isn’t always its command’s name. ripgrep’s package is called
`ripgrep`, but its command is `rg`. `nix run` still runs the right one,
because the package says so in `meta.mainProgram`:

```nix
pkgs.ripgrep.meta.mainProgram
```

So `nix run nixpkgs#ripgrep` runs `bin/rg` from the package:

```console
$ nix run nixpkgs#ripgrep -- --version | head -1
ripgrep 15.1.0
```

When a package has no `meta.mainProgram`, `nix run` falls back to its `pname`.
dos2unix is one of those. Its package holds four commands, `dos2unix`,
`mac2unix`, `unix2dos` and `unix2mac`, and the pname picks `dos2unix`:

```console
$ nix eval nixpkgs#dos2unix.pname
"dos2unix"
$ nix run nixpkgs#dos2unix -- --version | head -1
dos2unix 7.5.4 (2026-01-30)
```

That means `nix run nixpkgs#dos2unix` always runs `dos2unix`. To run `unix2dos` from
the same package, a flake can name it as an app. Here the app `to-windows`
runs `unix2dos`, which turns Unix line endings into Windows ones:

`flake.nix`:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { nixpkgs, ... }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in
    {
      apps.x86_64-linux.to-windows = {
        type = "app";
        program = "${pkgs.dos2unix}/bin/unix2dos";
      };
    };
}
```

An app is a set with `type = "app"` and a `program`, the path of the file to
run.

Before it looks for a package, `nix run` checks the flake’s `apps` output for
the name. So in that directory, `nix run .#to-windows` runs `unix2dos`, even
though no package has that name:

```console
$ nix run .#to-windows -- notes.txt
warning: creating lock file "/home/yurii/my-flake/flake.lock":
• Added input 'nixpkgs':
    'github:NixOS/nixpkgs/774debe7a0d1b496e35677ad955a1011c6ff74f3?narHash=sha256-nQyFkMR78WP6PiXKkDW2SjqzLf/spQqjRuxRGSbcV8k%3D' (2026-10-02)
unix2dos: converting file notes.txt to DOS format...
```

Leave out the `#` and the name, and `nix run` looks for `default` instead,
first under `apps`, then under `packages`. That’s what a README’s plain
`nix run github:owner/repo` runs. This flake has neither yet.

### Try it

Rename `to-windows` to `default`, so a plain `nix run` in this directory runs `unix2dos`.

- Offer an app named `default`flake.nixFlakeA flake with inputs and outputs.

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { nixpkgs, ... }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in
    {
      apps.x86_64-linux.to-windows = {
        type = "app";
        program = "${pkgs.dos2unix}/bin/unix2dos";
      };
    };
}
```

