# Nixpkgs and packaging

## Nixpkgs

Nix knows how to build software, but somebody still has to write down how to
build Firefox, Git or Neovim. Those recipes all live in nixpkgs, one giant
repository on GitHub that the community maintains
together, and it’s massive. search.nixos.org
lists more than 140,000 packages from it.

And it’s not just packages. nixpkgs also holds `lib`, a library of handy
functions, and every module behind the NixOS options. You don’t even need NixOS
to use it, because Nix on any Linux or macOS installs from the very same place.
NixOS / nixpkgs›nixpkgs/›pkgs/package recipes›by-name/packages grouped by name›ba/›bat/›󱄅package.nix

The recipe for building bat.›bt/›btop/›󱄅package.nix

The recipe for building btop.›fd/›fd/›󱄅package.nix

The recipe for building fd.›gi/›git/›󱄅package.nix

The recipe for building Git.›update.sh

A script for updating the Git package.›he/›hello/›󱄅package.nix

The recipe for building GNU Hello.›󱄅test.nix

A test that runs GNU Hello and checks its output.›ht/›htop/›󱄅package.nix

The recipe for building htop.›jq/›jq/›󱄅package.nix

The recipe for building jq.›ju/›just/›󱄅package.nix

The recipe for building just.›ne/›neovim-unwrapped/›󱄅package.nix

The recipe for building Neovim before adding its wrapper.›󱄅treesitter-parsers.nix

Sources for the Tree-sitter parsers bundled with Neovim.›ri/›ripgrep/›󱄅package.nix

The recipe for building ripgrep.›tm/›tmux/›󱄅package.nix

The recipe for building tmux.›wg/›wget/›󱄅package.nix

The recipe for building Wget.›applications/packages grouped by category›editors/›vim/›󱄅default.nix

The recipe for building Vim.›󱄅macvim.nix

The recipe for building MacVim.›networking/›browsers/›firefox/›󱄅wrapper.nix

Adds the launcher and desktop integration around Firefox.›󱄅update.nix

Creates a script for updating Firefox package versions.›top-level/assembles the package set›󱄅default.nix

Assembles the Nixpkgs package set.›󱄅all-packages.nix

Connects package recipes to the attributes you type in pkgs.›󱄅aliases.nix

Maps older package names to their replacements.›lib/reusable Nix functions›󱄅lists.nix

Functions for working with lists.›󱄅strings.nix

Functions for working with strings.›󱄅attrsets.nix

Functions for working with attribute sets.›󱄅options.nix

Helpers for declaring and working with options.›󱄅types.nix

Types used to check module option values.›󱄅modules.nix

The machinery behind the module system.›󱄅default.nix

Collects the library functions into lib.›nixos/NixOS modules and tests›modules/›programs/›󱄅git.nix

NixOS options and configuration for Git.›󱄅firefox.nix

NixOS options and configuration for Firefox.›󱄅fish.nix

NixOS options and configuration for the Fish shell.›services/›networking/›ssh/›󱄅sshd.nix

NixOS options and configuration for the OpenSSH server.›web-servers/›nginx/›󱄅default.nix

NixOS options and configuration for nginx.›󱄅vhost-options.nix

Options for individual websites served by nginx.›config/›󱄅users-groups.nix

NixOS options and configuration for users and groups.›󱄅system-path.nix

Builds the system environment from the configured packages.›system/

The modules that assemble the operating system.›tests/›󱄅firefox.nix

Tests Firefox on a virtual NixOS machine.›󱄅nginx.nix

Tests nginx on virtual NixOS machines.›󱄅openssh.nix

Tests OpenSSH on virtual NixOS machines.›󱄅default.nix

The entry point for NixOS evaluation.›maintainers/people caring for packages›󱄅maintainer-list.nix

The people who look after packages.›doc/project documentation›README.md

How to contribute to the Nixpkgs reference manual.›stdenv.md

Documentation for the standard package-building environment.›functions.md

Documentation for Nixpkgs library functions.›󱄅default.nix

The entry point that evaluates nixpkgs.›󱄅flake.nix

The flake outputs the repository provides.

Open `pkgs`, then `by-name`, `he` and `hello`. That `package.nix` is the
recipe for GNU Hello, a tiny program that prints a greeting. Then open `gi` and
`git` next to it for Git’s recipe.

The two-letter directories like `he` and `gi` aren’t part of the
name. They’re just its first two letters. They sort all those packages into
smaller directories.

This is the top of hello’s `package.nix`, cut down to a few of its lines:

`hello/package.nix`:

```nix
{
  stdenv,
  fetchurl,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "hello";
  version = "2.12.3";

  src = fetchurl {
    url = "mirror://gnu/hello/hello-${finalAttrs.version}.tar.gz";
    hash = "sha256-DV9gFUOC/uELEUocNOeF2LH0kgc64tOm97FHaHs2aqA=";
  };
})
```

Don’t worry about reading every piece of it. Just notice that it
names the program, its version, and where to download the source code. That’s
the heart of every recipe.

When Nix evaluates nixpkgs, all those recipes turn into one giant
attribute set, where each package gets its
own name. So you never type the directory path. You select `hello` or `git`
from that set, the same way you select any other attribute.

On the command line, `nixpkgs#` means “from nixpkgs”. So `nixpkgs#hello.version` asks nixpkgs
for `hello`, then for its `version`:

```console
$ nix eval nixpkgs#hello.version
"2.12.3"
```

The name is all you ever write, and you’ll write it everywhere. In a NixOS
configuration, installing Git is the line
`environment.systemPackages = [ pkgs.git ];`. On the command line it’s
`nixpkgs#git`. Both mean the recipe from that `git` directory.

Wherever it comes from, that set usually goes by the name `pkgs`. In this repl,
`pkgs` is already there for you, so go ahead and pick some packages out of it:

Change `hello` to `git`, and see which Git version this nixpkgs has.

```nix
pkgs.hello.version
```

To find a package’s name, search for it on
search.nixos.org.

## pkgs

`pkgs.git`, `pkgs.firefox`, `pkgs.neovim`. Almost every Nix file you’ll read
names packages like this. But `pkgs` isn’t built into Nix. It’s just a name
everybody agrees on for the giant package set from nixpkgs.

In a file of your own, you get it by importing nixpkgs and calling what comes
back. `<nixpkgs>` is the copy of nixpkgs on your machine:

```nix
let
  pkgs = import <nixpkgs> { };
in
  [ pkgs.git pkgs.ripgrep ]
```

Each package prints as a `.drv` file in the store. That’s its build recipe,
which Nix calls a derivation. Meaning simply
selecting `pkgs.git` doesn’t build or install anything yet.

You can’t skip the `{ }`. Without it, you only have the function,
and no packages at all:

```nix
let
  withoutCall = import <nixpkgs>;
  withCall = import <nixpkgs> { };
in
  { function = withoutCall; package = withCall.hello; }
```

That `{ }` is where your settings go, and leaving it empty means you want the
defaults. For example, some packages, like Steam, aren’t open source. nixpkgs
calls them unfree, and by default it refuses them:

```nix
let
  pkgs = import <nixpkgs> { };
in
  [ pkgs.git pkgs.steam ]
```

Say yes with `config.allowUnfree = true;` in the set, and Steam is there too:

```nix
let
  pkgs = import <nixpkgs> { config.allowUnfree = true; };
in
  [ pkgs.git pkgs.steam ]
```

You won’t always import it yourself though. NixOS and Home Manager hand `pkgs`
to your configuration, and a flake gets it from its nixpkgs input. But however
it arrives, `pkgs.git` is Git.

### Try it

A package is a set too, and it knows a lot about itself. ripgrep's command isn't actually called `ripgrep`. Change `description` to `mainProgram` to find out what you really type.

```nix
let
  pkgs = import <nixpkgs> { };
in
  pkgs.ripgrep.meta.description
```

## Package attributes

Every package page on search.nixos.org
shows a description, a license and a homepage. But where does all that come
from? From the package itself.

`pkgs.hello` is a derivation, and like every
derivation, it’s just an attribute set. Most of it is build instructions for
Nix, but a few attributes are there for you to read.

Start with the name. `pname` is the package’s name, `version` is its version,
and `name` simply joins the two with a dash:

```nix
[ pkgs.hello.pname pkgs.hello.version pkgs.hello.name ]
```

`meta` holds everything you’d want to know before installing it, and that’s
exactly where the search page gets its text:

```nix
pkgs.hello.meta.description
```

It also has `mainProgram`, the command the package gives you. That’s how
`nix run nixpkgs#ripgrep` knows to start `rg`.

`outputs` lists the parts the package is built into, each with a store path of
its own. Hello is small, so it has a single output, `out`:

```nix
pkgs.hello.outputs
```

Note that reading these builds nothing. Meaning they’re values written in
the recipe, not files from the finished package, so you can look at any
package before you download it.

### Try it

Hello comes in one part. Change `pkgs.hello` to `pkgs.git`, and see how many parts Git comes in.

```nix
let
  package = pkgs.hello;
in
{
  name = package.name;
  description = package.meta.description;
  outputs = package.outputs;
}
```

Git comes in three parts: `out` with the program, `doc` with its documentation
and `debug` with its debugging symbols. Each part lands in the store on
its own, so you can have the program without the documentation.

## lib

Packages aren’t the only thing in nixpkgs. `lib` is its library of ordinary Nix
functions for lists, strings, attribute sets and
version numbers, plus data like the almost 300 software licenses packages
can declare.

You’ll meet it as the `lib` argument at the top of package recipes and of NixOS
and Home Manager modules, and as `nixpkgs.lib` in a flake. Hello’s recipe, for
example, writes `license = lib.licenses.gpl3Plus;` in its `meta`.

`lib` isn’t built into Nix. It’s just Nix code in the `lib` directory of
nixpkgs. Meaning it’s there wherever nixpkgs is, whether you’re on NixOS or not.
There are hundreds of functions in it, so instead of memorizing them, search
noogle.dev, which is like search.nixos.org, but for
functions.

### Try it

Here are three of them at work. `lib.licenses.gpl3Plus.fullName` reads the
license’s full name, `lib.versions.major` picks the first number out of a
version, and `lib.unique` drops repeated items from a list.

Change `gpl3Plus` to `mit`.

```nix
{
  license = lib.licenses.gpl3Plus.fullName;
  version = lib.versions.major "2.12.3";
  tools = lib.unique [ "git" "vim" "git" ];
}
```

`lib.versions` has a neighbour that keeps two numbers. Change `lib.versions.major` to `lib.versions.majorMinor`.

```nix
{
  license = lib.licenses.gpl3Plus.fullName;
  version = lib.versions.major "2.12.3";
  tools = lib.unique [ "git" "vim" "git" ];
}
```

## callPackage

Open almost any recipe in nixpkgs and it starts the same way: a function that
takes everything it depends on as a set argument. This is the top of cowsay’s
`package.nix`:

`cowsay/package.nix`:

```nix
{
  lib,
  fetchFromGitHub,
  makeWrapper,
  nix-update-script,
  perl,
  stdenv,
  testers,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "cowsay";
  version = "3.8.4";
})
```

Somebody has to call that function with all of those, and that’s
`callPackage`. You give it the path to a recipe, it imports the file, looks at
the names the function asks for, takes each one from `pkgs` and makes the
call. Meaning a recipe never needs to know where nixpkgs comes from, it just
names what it needs.

Your own recipes work the same way. Here `package.nix` asks for `stdenv`, and
`default.nix` loads it with `pkgs.callPackage ./package.nix { }`:

`package.nix`:

```nix
{ stdenv }:

stdenv.mkDerivation {
  pname = "my-program";
  version = "1.0";
  src = ./.;

  buildPhase = ''
    gcc -o my-program main.c
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp my-program $out/bin
  '';
}
```

`default.nix`:

```nix
let
  pkgs = import <nixpkgs> { };
in
pkgs.callPackage ./package.nix { }
```

```console
$ nix build --file default.nix
$ ./result/bin/my-program
hello from my-program
```

The set at the end wins over `pkgs`, so you can hand a recipe something else
without touching the file. nixpkgs does that itself: it defines `fcitx5-lua`
by calling its recipe with `{ lua = lua5_3; }`, which gives it Lua 5.3 instead
of the default 5.2.

Every name the recipe asks for has to exist in `pkgs` or in that
set, unless the recipe gives it a default, because `callPackage` has nowhere
else to look. Ask for `opensll` by mistake, and it stops with
`Function called without required argument "opensll"`, followed by
`did you mean "openslp", "openssl" or "openal"?`.

## override

Some recipes in nixpkgs come with switches you can flip. Here’s the top of
htop’s recipe:

`htop/package.nix`:

```nix
{
  lib,
  fetchFromGitHub,
  fetchpatch2,
  stdenv,
  autoreconfHook,
  pkg-config,
  ncurses,
  libcap,
  libnl,
  sensorsSupport ? (stdenv.hostPlatform.isLinux && !stdenv.hostPlatform.isStatic),
  lm_sensors,
  systemdSupport ? lib.meta.availableOn stdenv.hostPlatform systemdLibs,
  systemdLibs,
  withVimKeys ? false,
}:

assert systemdSupport -> stdenv.hostPlatform.isLinux;

stdenv.mkDerivation (finalAttrs: {
  pname = "htop" + lib.optionalString withVimKeys "-vim";
  version = "3.5.1";
})
```

The last parameter is `withVimKeys ? false`. The `? false`
means it’s off unless someone says otherwise. `pkgs.htop` is this recipe
called with the defaults. So how do you get the one with Vim keys?

That’s exactly what `override` is for. It calls the recipe again with the same
arguments, except the ones you change. Everything you don’t mention stays as it was. It works
like `//` on the arguments: the old set, with your names on top.

nixpkgs itself defines `htop-vim = htop.override { withVimKeys = true; };`.
Here’s the same call in `nix repl`:

```console
$ nix repl
Nix 2.34.8
Type :? for help.
nix-repl> pkgs = import <nixpkgs> { }
nix-repl> pkgs.htop.outPath
"/nix/store/ya7qq17bc608p5svkbiwsbpl4ibrl3nn-htop-3.5.1"
nix-repl> (pkgs.htop.override { withVimKeys = true; }).outPath
"/nix/store/797bvf750brh1nahvmaq1ylkjcb5r0kj-htop-vim-3.5.1"
nix-repl> pkgs.htop.outPath
"/nix/store/ya7qq17bc608p5svkbiwsbpl4ibrl3nn-htop-3.5.1"
```

The two store paths differ, because the result is a separate package.
`pkgs.htop` itself stays exactly the same, as the last line shows.

This one comes straight from the binary cache, since nixpkgs builds `htop-vim`
too. An override nobody else uses gets built on your machine instead.

Dependencies are arguments too. bogofilter, a spam filter, keeps its data in a
database. Its recipe asks for `database ? db`, and `db` is Berkeley DB:

`bogofilter/package.nix`:

```nix
{
  lib,
  stdenv,
  fetchurl,
  db,
  flex,
  gnugrep,
  makeWrapper,
  pax,
  perl,
  valgrind,
  database ? db,
}:

let
  dbName = lib.getName database;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "bogofilter-${dbName}";
  version = "1.2.5";
})
```

Hand it SQLite instead, and you get a different bogofilter. Its name even
says which database it uses:

```console
nix-repl> pkgs.bogofilter.outPath
"/nix/store/4hjrp048g24kbnls7jr2diii2v26c9qz-bogofilter-db-1.2.5"
nix-repl> (pkgs.bogofilter.override { database = pkgs.sqlite; }).outPath
"/nix/store/m3lcr4ba5dj5x1d628ddy6zrvsklpz7v-bogofilter-sqlite-1.2.5"
```

Any name in the header can be swapped this way, not just the switches.
nixpkgs itself defines `bogofilter-sqlite` with exactly this call.

To install the result, put the whole call in parentheses inside your package
list. Without them, Nix reads the list as two separate items, the `override`
function and the set:

```console
nix-repl> [ pkgs.htop.override { withVimKeys = true; } ]
[
  { ... }
  { ... }
]
nix-repl> [ (pkgs.htop.override { withVimKeys = true; }) ]
[
  «derivation /nix/store/y0pkhr2ipfaf7xj8c6dx81dlr2z9ixw5-htop-vim-3.5.1.drv»
]
```

Notice that the first list has two items and no package in it. The first
`{ ... }` is the `override` function. nixpkgs stores it in a set, so the repl
prints it like one.

Your package list needs the parentheses too:

`environment.systemPackages = [ (pkgs.htop.override { withVimKeys = true; }) ];`

You’ll see this pattern in plenty of configs, wherever someone wants a package
built a little differently than the default.

## overrideAttrs

Say nixpkgs has a package, but you want it a little different. Maybe built
from your local copy of the source, with an extra patch, or in a newer version
than nixpkgs ships. You don’t copy the recipe for any of that. You change it
from the outside with `overrideAttrs`.

Most recipes in nixpkgs call `mkDerivation` with a set of attributes: the
`version`, the `src`, the `patches`, the build flags and so on.
`overrideAttrs` makes a new package with some of them swapped.

Give it a set, and those attributes get replaced while the rest stay as they
were. Say you’re fixing a bug in GNU Hello itself, and want nixpkgs to build
your local copy instead of the release. Swap its `src` for the folder:

```nix
let
  hello = pkgs.stdenv.mkDerivation {
    pname = "hello";
    version = "2.12.3";
    src = pkgs.fetchurl {
      url = "mirror://gnu/hello/hello-2.12.3.tar.gz";
      hash = "sha256-DV9gFUOC/uELEUocNOeF2LH0kgc64tOm97FHaHs2aqA=";
    };
  };
in
{
  before = hello.src.url;
  after = (hello.overrideAttrs { src = ./hello; }).src;
}
```

You get a new package, and `hello` itself stays the same. The new one is a
different recipe with its own store path, and the binary cache won’t have
it, so expect it to build on your machine.

Adding a patch is the most common reason to reach for `overrideAttrs`. A set is a bad fit for that, because it replaces the whole
list. Pass a function instead. It gets the old attributes, conventionally
named `old`, and returns the new ones. Here are both ways side by side:

```nix
let
  hello = pkgs.stdenv.mkDerivation {
    pname = "hello";
    version = "2.12.3";
    patches = [ ./fix-build.patch ];
  };
in
{
  replaced = (hello.overrideAttrs {
    patches = [ ./my-fix.patch ];
  }).patches;

  extended = (hello.overrideAttrs (old: {
    patches = old.patches ++ [ ./my-fix.patch ];
  })).patches;
}
```

`replaced` lost the recipe’s own patch. `extended` kept it and added yours to
the end.

Some attributes are built from others. Hello’s real recipe makes its download
link out of its own `version`, through `finalAttrs`. That’s what the attributes
look like after every change, yours included:

Inside the empty `{ }`, add `version = "2.12.2";` and watch the link follow.

```nix
let
  hello = pkgs.stdenv.mkDerivation (finalAttrs: {
    pname = "hello";
    version = "2.12.3";
    src = pkgs.fetchurl {
      url = "mirror://gnu/hello/hello-${finalAttrs.version}.tar.gz";
      hash = "sha256-DV9gFUOC/uELEUocNOeF2LH0kgc64tOm97FHaHs2aqA=";
    };
  });
in
  (hello.overrideAttrs { }).src.url
```

The link moved, but the hash still describes the old tarball, so a new
version needs a new hash as well. nixpkgs even prints a warning when you
forget.

One package in nixpkgs, `scala-next`, is nothing but that. It’s a newer release
of the regular Scala recipe with a new hash:

`pkgs/by-name/sc/scala-next/package.nix`:

```nix
{ scala, fetchurl }:

scala.bare.overrideAttrs (oldAttrs: {
  version = "3.8.3";
  pname = "scala-next";
  src = fetchurl {
    inherit (oldAttrs.src) url;
    hash = "sha256-/2LoJ+seoXgT2X5f1eDSaQEQeHFz/h4eQ9na3MNUL6c=";
  };
})
```

`inherit (oldAttrs.src) url;` is short for `url = oldAttrs.src.url;`. The
regular Scala recipe builds that link from `finalAttrs.version`, so it already
points at 3.8.3.

There’s also `override`, which changes something else: the arguments the
recipe’s function is called with.

## Overlays

Say you want htop with Vim keys. htop’s recipe in nixpkgs has a switch for
that, `withVimKeys`, and `pkgs.htop.override { withVimKeys = true; }` builds
htop with it turned on. But that only gives you a new package next to the old one.
Everything else that asks nixpkgs for `htop` by name still gets the plain one.

What you really want is to change what the name `htop` itself means. And that’s
exactly what an overlay does. nixpkgs is one big attribute set of packages, and an overlay is
a small function that hands back changes to it. Here’s one in its own file:

`vim-htop.nix`:

```nix
final: prev: {
  htop = prev.htop.override { withVimKeys = true; };
}
```

It takes two arguments. `prev` is nixpkgs before your change. `final` is
nixpkgs with all the changes in, yours included. You’ll see in a moment why
you need both. The overlay returns a set with the names to add or replace,
here just `htop`.

In older code you’ll see them called `self` and `super`. Same thing, new
names.

You hand overlays to nixpkgs as a list when you import it. Then `pkgs.htop`
itself is the Vim version:

```console
$ nix repl
Nix 2.34.8
Type :? for help.
nix-repl> pkgs = import <nixpkgs> { }
nix-repl> pkgs.htop.name
"htop-3.5.1"
nix-repl> pkgs = import <nixpkgs> { overlays = [ (import ./vim-htop.nix) ]; }
nix-repl> pkgs.htop.name
"htop-vim-3.5.1"
```

The new `htop` is built from `prev.htop`. `final.htop` is the very thing
you’re defining. Swap `prev` for `final`, and Nix goes in circles until it
gives up:

```console
$ cat vim-htop.nix
final: prev: {
  htop = final.htop.override { withVimKeys = true; };
}
$ nix repl
Nix 2.34.8
Type :? for help.
nix-repl> pkgs = import <nixpkgs> { overlays = [ (import ./vim-htop.nix) ]; }
nix-repl> pkgs.htop.name
error:
       … while evaluating the attribute 'htop.name'
         at /tmp/tmp.q1k0sm4HSX/vim-htop.nix:2:3:
            1| final: prev: {
            2|   htop = final.htop.override { withVimKeys = true; };
             |   ^
            3| }
       … while evaluating the attribute 'htop.override'
         at /tmp/tmp.q1k0sm4HSX/vim-htop.nix:2:3:
            1| final: prev: {
            2|   htop = final.htop.override { withVimKeys = true; };
             |   ^
            3| }
       error: infinite recursion encountered
       at /tmp/tmp.q1k0sm4HSX/vim-htop.nix:2:10:
            1| final: prev: {
            2|   htop = final.htop.override { withVimKeys = true; };
             |          ^
            3| }
```

For anything other than the name you’re replacing, take it from `final`. Then
you get every overlay’s changes. Here’s a second overlay that adds a `monitor`
command which starts htop:

`monitor.nix`:

```nix
final: prev: {
  monitor = final.writeShellScriptBin "monitor" "exec ${final.htop}/bin/htop";
}
```

Put it first in the list, before `vim-htop.nix`, and look at the script it
writes:

```console
$ nix repl
Nix 2.34.8
Type :? for help.
nix-repl> pkgs = import <nixpkgs> { overlays = [ (import ./monitor.nix) (import ./vim-htop.nix) ]; }
nix-repl> pkgs.monitor.text
"#!/nix/store/7n1hai8jk6vgc967drgkqi6k7j6ff28q-bash-5.3p9/bin/bash\nexec /nix/store/797bvf750brh1nahvmaq1ylkjcb5r0kj-htop-vim-3.5.1/bin/htop\n"
```

It starts `htop-vim`, even though the Vim overlay comes later in the list.
That’s because `final` is the finished set, with every overlay applied.

Swap `final.htop` for `prev.htop`, and it starts the plain one. Nothing has
changed `htop` yet at that point in the list:

```console
$ cat monitor.nix
final: prev: {
  monitor = final.writeShellScriptBin "monitor" "exec ${prev.htop}/bin/htop";
}
$ nix repl
Nix 2.34.8
Type :? for help.
nix-repl> pkgs = import <nixpkgs> { overlays = [ (import ./monitor.nix) (import ./vim-htop.nix) ]; }
nix-repl> pkgs.monitor.text
"#!/nix/store/7n1hai8jk6vgc967drgkqi6k7j6ff28q-bash-5.3p9/bin/bash\nexec /nix/store/ya7qq17bc608p5svkbiwsbpl4ibrl3nn-htop-3.5.1/bin/htop\n"
```

`monitor.nix` reads from a set that isn’t finished yet. Meaning
this only works because Nix is lazy. It looks inside
`final` only once something asks for a value, and by then every overlay is
in.

How far it carries`override`one build, through its inputscall the package's own function again with different arguments`overrideAttrs`one build, through its recipechange the attributes `mkDerivation` was handed, after that function ran`an overlay`everyone who asks for that namechange what the name itself means inside the package set

## Overlays in NixOS and flakes

An overlay you hand to `import <nixpkgs>` only changes that one `pkgs`. But
your NixOS system gets its `pkgs` from NixOS itself, so how do you get your
overlay in there?

Simple: overlays go in the `nixpkgs.overlays` option of your
`configuration.nix`:

`configuration.nix`:

```nix
{
  nixpkgs.overlays = [
    (import ./vim-htop.nix)
    (final: prev: {
      monitor = final.writeShellScriptBin "monitor" "exec ${final.htop}/bin/htop";
    })
  ];

  programs.htop.enable = true;
}
```

The second overlay is written right in the list. You don’t need a file for
every overlay.

Now `programs.htop.enable` installs `htop-vim`. That module asks for
`pkgs.htop`, and the name now means your version. Home Manager has the same
`nixpkgs.overlays` option.

Flakes share overlays too. rust-overlay is a flake that adds Rust toolchains
to nixpkgs. Its overlay is the `overlays.default` output:

```console
nix-repl> rust-overlay = builtins.getFlake "github:oxalica/rust-overlay"
nix-repl> pkgs = import <nixpkgs> { overlays = [ rust-overlay.overlays.default ]; }
nix-repl> pkgs.rust-bin.stable.latest.default.name
"rust-default-1.99.0"
```

Meaning a flake can hand you new names in `pkgs`, like `rust-bin` here.

In a NixOS flake, rust-overlay is one more input. Its `overlays.default` goes
in `nixpkgs.overlays` like the overlays above, and then any module can install
from `pkgs.rust-bin`.

## The Nix store

Most package managers spread a program across your system. Here’s where
GNU Hello, a tiny program that prints a greeting, ends up on Debian:
/›usr/›bin/›󱓞git›󱓞hello›󱓞htop›lib/›x86_64-linux-gnu/›libc.so.6›libgcc_s.so.1›libidn2.so.0›libunistring.so.5›share/›info/›hello.info.gz›man/›man1/›git.1.gz›hello.1.gz›htop.1.gz

The command goes into /usr/bin, its manual into `/usr/share/man`, and the
libraries it needs sit in `/usr/lib`, all mixed in with every other program’s
files.

Nix puts everything it installs into one directory, `/nix/store`, and gives each
package a directory of its own there, on Linux and macOS alike. Here’s Hello
again, this time in the store. Open it and look around:

Inside, the program sits in `bin`, and its manuals and translations in
`share`. The directories around it are the libraries Hello runs on.

Once something lands in the store, Nix never changes it again. Every file in
there is read-only, and a new version goes into a new directory, right next to
the old one.

That’s exactly what lets dozens of different versions of the same software live
side by side without conflicts. Programs that worked yesterday still work today,
and a faulty update is just an extra broken version you don’t have to use. Here
are four Neovim versions in one store. Say the newest one broke. The other three
still work exactly like before:

So how does your shell find `nvim`? Nothing gets copied anywhere. In a
devshell, your shell gets pointed at one of those directories:

```console
$ which nvim
/nix/store/7602dj25chzbdnipsh66lzqm6qjssllk-neovim-0.12.4/bin/nvim
```

Which version that is depends on the nixpkgs your devshell comes from. On
NixOS, your shell looks in `/run/current-system/sw/bin` instead. That’s a
directory of links, and each one points into the store.

## Store paths

Here’s where GNU Hello lives on a Linux machine:
`/nix/store/9lmc8ad19psaj2cpwav6a0yzjqlrn00j-hello-2.12.3`. It has three parts:

- `/nix/store/` is the store itself.

- `9lmc8ad19psaj2cpwav6a0yzjqlrn00j` is a hash, always 32 characters.

- `hello-2.12.3` is the name, for a package usually its name and version.

Every path in the store is named this way.

The name is there for you. Nix tells paths apart by the hash, which is why
different builds of the very same version can sit next to each other. Here’s
one machine that has four of them:

```console
$ ls -d /nix/store/*-hello-2.12.3
/nix/store/5z2yp3ysx8476c8g5w25b0smlgkjvaq3-hello-2.12.3
/nix/store/9lmc8ad19psaj2cpwav6a0yzjqlrn00j-hello-2.12.3
/nix/store/lcxc2z1h2g8wq8dxfpizy1di85kyxnqx-hello-2.12.3
/nix/store/xl1h9i29pgq2q5cszjhm5wpfxfbbqwyi-hello-2.12.3
```

Same program, same version, four hashes. Each of these was built against a
different build of glibc, the C library, so to Nix they are four different
packages, and none of them gets in the way of the others.

That’s because the hash isn’t random. For a package, Nix works it out from the
whole recipe: the source code, the build script, the system it’s built for, and
every dependency, each of which already carries a hash of its own. Change any of
that, even one compiler flag, and the hash changes with it.

So the same recipe lands at the same path on every machine, and Nix knows where
a package will end up before building anything. Here we ask one pinned version
of nixpkgs where GNU Hello goes on Linux and on an Apple Silicon Mac, and
nothing gets built to answer:

```console
$ nix eval nixpkgs/774debe7a0d1b496e35677ad955a1011c6ff74f3#legacyPackages.x86_64-linux.hello.outPath
"/nix/store/9lmc8ad19psaj2cpwav6a0yzjqlrn00j-hello-2.12.3"
$ nix eval nixpkgs/774debe7a0d1b496e35677ad955a1011c6ff74f3#legacyPackages.aarch64-darwin.hello.outPath
"/nix/store/f6ivp5fiw1nwq690548fb9qr8p968mj5-hello-2.12.3"
```

The system is part of the recipe, so we get two hashes. Run the first command
on any Linux machine or Mac and you get exactly this path, which is what lets
Nix download a package built somewhere else instead of building it again.

Files Nix copies straight into the store, like your own source code, are the
exception. Their hash comes from the contents and the name. `nix store add`
copies a file into the store and prints its path, so let’s add the same note
from two directories, then change it:

```console
$ cat notes.txt
buy milk
$ nix store add notes.txt
/nix/store/gfgd4jkdhmdv4m7rlvdj1785i84kh74i-notes.txt
$ nix store add backup/notes.txt
/nix/store/gfgd4jkdhmdv4m7rlvdj1785i84kh74i-notes.txt
$ echo "buy bread" > notes.txt
$ nix store add notes.txt
/nix/store/b1wlbkjd4cc57pp738v50a34bjdckg6c-notes.txt
```

The same contents land at one path, wherever they came from. New contents get
a new hash.

These paths aren’t directories. A store path can be a single file,
and `gfgd4jkdhmdv4m7rlvdj1785i84kh74i-notes.txt` is just the note itself. The
build recipes ending in `.drv` are single files too.

And one package can be split into several paths. jq, a tool for reading JSON,
puts its command, its library, its headers and its manuals in separate paths:

```console
$ nix build --no-link --print-out-paths 'nixpkgs/774debe7a0d1b496e35677ad955a1011c6ff74f3#jq^*'
/nix/store/vi98k7lyazj240xs82a8990gg5yqcq6g-jq-1.8.2-bin
/nix/store/2pyl29z02hcsdqj7v7dkzbmmc4rr9aa1-jq-1.8.2-dev
/nix/store/g4xf51xgn5x0cw5fq9b3hzd3i72vdsfh-jq-1.8.2-doc
/nix/store/62vs91m9a5q0sfz6lm5j5m5xi3382xc2-jq-1.8.2-man
/nix/store/2blb9nklpvhchkpfp53a6k5s8sbfa4l0-jq-1.8.2
```

The `jq` command sits in the one ending in `-bin`, and the library in the one
with no ending. So a program that only needs the library doesn’t pull in the
command or the manuals.

## Derivations

Every package in the store was built from a recipe. In Nix, that recipe is
called a derivation, and it’s just an attribute
set that says what to run, and on which system.

The simplest way to make one is the built-in
`derivation` function. Give it a set, and it gives you a derivation back:

```nix
derivation {
  name = "hello-world";
  system = "x86_64-linux";
  builder = "/bin/sh";
  args = [ "-c" "echo hello world > $out" ];
}
```

- `name` ends up in the store path.

- `system` says which kind of machine can build it, here a 64-bit Intel or AMD
Linux.

- `builder` is the program Nix runs, here a shell.

- `args` is what the builder gets, so the shell runs
`echo hello world > $out` as a script.

`$out` isn’t Nix. It’s a shell variable, and Nix sets it to the one
place in the store the builder is allowed to write to. Whatever the builder
leaves there becomes the package, here a single file that says `hello world`.

Evaluating this didn’t build anything. Instead, Nix wrote the recipe into the
store as a file ending in `.drv`, and that’s the path the repl printed. This
step is called instantiation.

The `.drv` file is the whole recipe, written down without a single line of Nix
code:

```console
$ cat /nix/store/dp5na63mzhc3a2kkiy37b3xq642k7lhy-hello-world.drv
```

It already knows the exact path the result will land at, before anything is
built. And every input in there is an exact store path too. Meaning you could
hand this file to another machine, and it could build it without ever seeing
your Nix code.

Running the recipe is called realisation. `nix-build` takes a file, writes the
recipe, and builds it, all in one go:

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
$ nix-build hello-world.nix
this derivation will be built:
  /nix/store/dp5na63mzhc3a2kkiy37b3xq642k7lhy-hello-world.drv
building '/nix/store/dp5na63mzhc3a2kkiy37b3xq642k7lhy-hello-world.drv'...
/nix/store/kbh84yclhgn33j34j9i4wxha04v79q5f-hello-world
$ cat result
hello world
$ nix-build hello-world.nix
/nix/store/kbh84yclhgn33j34j9i4wxha04v79q5f-hello-world
```

The last line is the new store path, and `result` is a
link to it. The second run builds nothing at all,
because that exact path is already in the store. As long as it stays there,
this recipe never needs building again.

The builder does have to create `$out` itself though. Remove `> $out` from the
script, and the build fails, because nothing was left behind:

```console
$ nix-build hello-world.nix
this derivation will be built:
  /nix/store/m8s2qvxd5rag0kr3i2agyyq7ckjidri0-hello-world.drv
building '/nix/store/m8s2qvxd5rag0kr3i2agyyq7ckjidri0-hello-world.drv'...
hello world
error: builder for '/nix/store/m8s2qvxd5rag0kr3i2agyyq7ckjidri0-hello-world.drv' failed to produce output path for output 'out' at "/nix/store/m8s2qvxd5rag0kr3i2agyyq7ckjidri0-hello-world.drv.chroot/root/nix/store/wmhy6sa98m5s8gf4m2r5nmkp1v6sa8ky-hello-world"
```

Every package in nixpkgs is a derivation too, and they print the exact same way:

```nix
let
  pkgs = import <nixpkgs> { };
in
  [ pkgs.hello pkgs.cowsay ]
```

Their recipes use `stdenv.mkDerivation`, which fills in a much bigger set for
you. But in the end, it calls this same `derivation` function.

### Try it

Change the last line to `hello-world.outPath`. That's where the result will land, before anything is built.

```nix
let
  hello-world = derivation {
    name = "hello-world";
    system = "x86_64-linux";
    builder = "/bin/sh";
    args = [ "-c" "echo hello world > $out" ];
  };
in
  hello-world
```

The script is part of the recipe. Change `hello world` in the script to `hello nix`. The name stays the same, but the hash doesn't, because this is a different package now.

```nix
let
  hello-world = derivation {
    name = "hello-world";
    system = "x86_64-linux";
    builder = "/bin/sh";
    args = [ "-c" "echo hello world > $out" ];
  };
in
  hello-world.outPath
```

## Your first package

The `derivation` function builds anything, as long as you hand it everything
yourself: a builder program, a system and every tool along the way. Here’s a
small C program built that way:

`default.nix`:

```nix
let
  pkgs = import <nixpkgs> { };
in
derivation {
  name = "my-program-1.0";
  system = "x86_64-linux";
  src = ./main.c;
  builder = "${pkgs.bash}/bin/bash";
  args = [ "-c" ''
    export PATH=${pkgs.coreutils}/bin:${pkgs.gcc}/bin
    gcc -o my-program $src
    mkdir -p $out/bin
    cp my-program $out/bin
  '' ];
}
```

Note how even `mkdir` and `gcc` have to be handed over by hand. Now imagine
doing that for over a hundred thousand packages, writing the same build script
over and over again.

So instead, nixpkgs sets those tools up once. `stdenv` is the standard
environment: a C compiler, `make`, Bash, coreutils, `tar`, `patch` and a few
more, all ready to go.

And `stdenv.mkDerivation` builds with them. It takes a set that describes your
package and turns it into a derivation, so you
only write down what’s special about your package.

Almost every recipe in nixpkgs is a call to it, or to something built on top of
it. Here’s the real recipe for GNU Hello, cut down to a few of its lines:

`hello/package.nix`:

```nix
{
  stdenv,
  fetchurl,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "hello";
  version = "2.12.3";

  src = fetchurl {
    url = "mirror://gnu/hello/hello-${finalAttrs.version}.tar.gz";
    hash = "sha256-DV9gFUOC/uELEUocNOeF2LH0kgc64tOm97FHaHs2aqA=";
  };

  doCheck = true;
})
```

`pname` and `version` name the package. Together they make its full name:

```nix
pkgs.hello.name
```

`src` says where the source code comes from, here a tarball that `fetchurl`
downloads.

And there isn’t a single build command in there! Hello is an ordinary GNU
project, so `mkDerivation` simply does what you’d do by hand: unpack the source,
then run `./configure`, `make` and `make install`. `doCheck = true;` adds
`make check` to that.

You could hand `mkDerivation` a plain set instead, but then the version is
typed twice:

`hello/package.nix`:

```nix
{
  stdenv,
  fetchurl,
}:

stdenv.mkDerivation {
  pname = "hello";
  version = "2.12.3";

  src = fetchurl {
    url = "mirror://gnu/hello/hello-2.12.3.tar.gz";
    hash = "sha256-DV9gFUOC/uELEUocNOeF2LH0kgc64tOm97FHaHs2aqA=";
  };
}
```

This works, but the problem is that you can bump `version`, forget the URL, and
build the old source under the new name. That’s why Hello passes a function
instead. The function gets the package’s own finished attributes as
`finalAttrs`, so the URL can simply use `finalAttrs.version`. Meaning a new
release only needs a new `version` and `hash`, and the URL follows.

Your own program works the same way. Put a `default.nix` next to its source,
and `src = ./.;` hands `mkDerivation` the directory it’s in:

`default.nix`:

```nix
let
  pkgs = import <nixpkgs> { };
in
pkgs.stdenv.mkDerivation {
  pname = "my-program";
  version = "1.0";
  src = ./.;
}
```

If your project builds the GNU way, like Hello, that’s already the whole
recipe. This directory holds a small C program with a `configure` script of its
own, and that file is all it takes:

```console
$ ls
configure  default.nix  main.c  Makefile.in
$ nix build -L --file default.nix
my-program> Running phase: unpackPhase
my-program> unpacking source archive /nix/store/jgysx33grs0k68w8irhkkiy45x74198j-my-program
my-program> source root is my-program
my-program> Running phase: patchPhase
my-program> Running phase: updateAutotoolsGnuConfigScriptsPhase
my-program> Running phase: configurePhase
my-program> patching script interpreter paths in ./configure
my-program> ./configure: interpreter directive changed from "#!/bin/sh" to "/nix/store/7n1hai8jk6vgc967drgkqi6k7j6ff28q-bash-5.3p9/bin/sh"
my-program> configure flags: --prefix=/nix/store/afx97f427sgm5hsmwxdnj7va4iv0rlpz-my-program-1.0
my-program> Running phase: buildPhase
my-program> build flags: SHELL=/nix/store/7n1hai8jk6vgc967drgkqi6k7j6ff28q-bash-5.3p9/bin/bash
my-program> gcc -o my-program main.c
my-program> Running phase: installPhase
my-program> install flags: SHELL=/nix/store/7n1hai8jk6vgc967drgkqi6k7j6ff28q-bash-5.3p9/bin/bash install
my-program> mkdir -p /nix/store/afx97f427sgm5hsmwxdnj7va4iv0rlpz-my-program-1.0/bin
my-program> cp my-program /nix/store/afx97f427sgm5hsmwxdnj7va4iv0rlpz-my-program-1.0/bin
my-program> Running phase: fixupPhase
my-program> shrinking RPATHs of ELF executables and libraries in /nix/store/afx97f427sgm5hsmwxdnj7va4iv0rlpz-my-program-1.0
my-program> shrinking /nix/store/afx97f427sgm5hsmwxdnj7va4iv0rlpz-my-program-1.0/bin/my-program
my-program> checking for references to /build/ in /nix/store/afx97f427sgm5hsmwxdnj7va4iv0rlpz-my-program-1.0...
my-program> patching script interpreter paths in /nix/store/afx97f427sgm5hsmwxdnj7va4iv0rlpz-my-program-1.0
my-program> stripping (with command strip and flags -S -p) in  /nix/store/afx97f427sgm5hsmwxdnj7va4iv0rlpz-my-program-1.0/bin
$ ./result/bin/my-program
hello from my-program
```

That’s the exact same `gcc`, `mkdir -p` and `cp` you wrote by hand at the top,
except this time you didn’t write any of it. stdenv brought the tools, and the
project’s own `configure` and `Makefile` did the rest.

That’s your first package. From here, pick the language your project is written
in, and follow its page:
C,
Python or
Rust.

### Try it

The description has the version typed in by hand. Replace `1.0` in it with `${finalAttrs.version}`. Then change `version` to `"2.0"`, and the description follows.

```nix
let
  my-program = pkgs.stdenv.mkDerivation (finalAttrs: {
    pname = "my-program";
    version = "1.0";
    src = ./.;
    meta.description = "my-program, version 1.0";
  });
in
  my-program.meta.description
```

## C projects

Most C projects start their README with a long list of things to install first,
and then the command that builds it. With Nix, a recipe right next to your code
replaces that whole list. Anyone with Nix runs one command, and your program
builds, on any machine.

Here’s a small C program that prints which OpenSSL it was built with. Its
Makefile finds OpenSSL with `pkg-config` and installs into `PREFIX`:

```console
$ ls
default.nix  main.c  Makefile  package.nix  README.md
$ cat Makefile
PREFIX ?= /usr/local
my-project: main.c
	$(CC) -o my-project main.c $(shell pkg-config --cflags --libs openssl)
install: my-project
	mkdir -p $(PREFIX)/bin
	cp my-project $(PREFIX)/bin
```

The recipe lives in `package.nix`, next to the code. It’s a function that asks
for everything the build needs. `src = ./.;` copies the project directory into
the store, and the build runs from there:

`package.nix`:

```nix
{ stdenv, pkg-config, openssl }:

stdenv.mkDerivation {
  pname = "my-project";
  version = "0.1.0";
  src = ./.;

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ openssl ];

  makeFlags = [ "PREFIX=$(out)" ];
}
```

`pkg-config` runs during the build, so it goes in `nativeBuildInputs`.
`openssl` is the library the program links against, so it goes in
`buildInputs`. And `makeFlags` hands `make` the package’s store path as its
`PREFIX`, so `make install` puts the program right there.

`default.nix` loads the recipe with `callPackage`, which hands it `stdenv`,
`pkg-config` and `openssl` from nixpkgs:

`default.nix`:

```nix
let
  pkgs = import <nixpkgs> { };
in
pkgs.callPackage ./package.nix { }
```

You never wrote a single build step. The default phases run `make`
and `make install` for you, and `-L` lets you watch them in the log:

```console
$ nix build --file default.nix -L
my-project> Running phase: unpackPhase
my-project> unpacking source archive /nix/store/1mqsa5xfxgqy06h96r5fqymrhm7a99yn-my-project
my-project> source root is my-project
my-project> Running phase: patchPhase
my-project> Running phase: updateAutotoolsGnuConfigScriptsPhase
my-project> Running phase: configurePhase
my-project> no configure script, doing nothing
my-project> Running phase: buildPhase
my-project> build flags: SHELL=/nix/store/7n1hai8jk6vgc967drgkqi6k7j6ff28q-bash-5.3p9/bin/bash PREFIX=\$\(out\)
my-project> gcc -o my-project main.c -I/nix/store/i2ahcmvfd1pzv0p4lz822x12lav0rnam-openssl-3.6.4-dev/include -L/nix/store/7fr737xfi9qw3fzvdsqmnbqid56knndp-openssl-3.6.4/lib -lssl -lcrypto
my-project> Running phase: installPhase
my-project> install flags: SHELL=/nix/store/7n1hai8jk6vgc967drgkqi6k7j6ff28q-bash-5.3p9/bin/bash PREFIX=\$\(out\) install
my-project> mkdir -p /nix/store/4b7mznf1hix1r605wpl4w217fkcbm88n-my-project-0.1.0/bin
my-project> cp my-project /nix/store/4b7mznf1hix1r605wpl4w217fkcbm88n-my-project-0.1.0/bin
my-project> Running phase: fixupPhase
my-project> shrinking RPATHs of ELF executables and libraries in /nix/store/4b7mznf1hix1r605wpl4w217fkcbm88n-my-project-0.1.0
my-project> shrinking /nix/store/4b7mznf1hix1r605wpl4w217fkcbm88n-my-project-0.1.0/bin/my-project
my-project> checking for references to /build/ in /nix/store/4b7mznf1hix1r605wpl4w217fkcbm88n-my-project-0.1.0...
my-project> patching script interpreter paths in /nix/store/4b7mznf1hix1r605wpl4w217fkcbm88n-my-project-0.1.0
my-project> stripping (with command strip and flags -S -p) in  /nix/store/4b7mznf1hix1r605wpl4w217fkcbm88n-my-project-0.1.0/bin
$ ./result/bin/my-project
my-project, built with OpenSSL 3.6.4 25 Aug 2026
```

Look at the `gcc` line. `pkg-config` filled in the OpenSSL flags for it.

And the build only sees what you list. Leave out `nativeBuildInputs`, and
`pkg-config` is missing, even if it’s installed right there on your machine:

```console
$ nix build --file default.nix
error: Cannot build '/nix/store/g0jlkwykba4dwhi3gk8phmaxxa472jfr-my-project-0.1.0.drv'.
       Reason: builder failed with exit code 2.
       Output paths:
         /nix/store/36hw77d3hafabrki3icibh8kbcw6srq2-my-project-0.1.0
       Last 15 log lines:
       > Running phase: unpackPhase
       > unpacking source archive /nix/store/xa8c92g4gg6nfgi3xm6178p3j6y9a5j5-my-project
       > source root is my-project
       > Running phase: patchPhase
       > Running phase: updateAutotoolsGnuConfigScriptsPhase
       > Running phase: configurePhase
       > no configure script, doing nothing
       > Running phase: buildPhase
       > build flags: SHELL=/nix/store/7n1hai8jk6vgc967drgkqi6k7j6ff28q-bash-5.3p9/bin/bash PREFIX=\$\(out\)
       > /nix/store/7n1hai8jk6vgc967drgkqi6k7j6ff28q-bash-5.3p9/bin/bash: line 1: pkg-config: command not found
       > gcc -o my-project main.c
       > /nix/store/bikkd0jwr8jkd3r6r5mcr28fm17yvb0z-binutils-2.46/bin/ld.bfd: /build/ccMkHjf3.o: in function `main':
       > main.c:(.text.startup+0x7): undefined reference to `OpenSSL_version'
       > collect2: error: ld returned 1 exit status
       > make: *** [Makefile:4: my-project] Error 1
       For full logs, run:
         nix log /nix/store/g0jlkwykba4dwhi3gk8phmaxxa472jfr-my-project-0.1.0.drv
```

Look for `pkg-config: command not found` in the log. Without it, the Makefile
gets no flags for OpenSSL. So `gcc` runs without the library, and the build
stops.

That’s it, your project is a Nix package now. Commit `package.nix` and
`default.nix` next to your code, and anyone can build it with one command.

## Python projects

Got a Python project? Then you’ll want `python3Packages.buildPythonApplication`.
It knows how Python projects are built, so you don’t write a single build step.
And the Python libraries your program needs are already packages in nixpkgs,
under `python3Packages`, so the recipe simply lists them.

Here’s hello-py, a tiny Python program that prints some ASCII art with the
`art` library. Its `pyproject.toml` says what it needs, like any modern Python
project:

```console
$ cat pyproject.toml
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"
[project]
name = "hello-py"
version = "0.1.0"
dependencies = ["art"]
[project.scripts]
hello-py = "hello_py:main"
```

The recipe says the same thing, in Nix:

`default.nix`:

```nix
let
  pkgs = import <nixpkgs> { };
in
pkgs.python3Packages.buildPythonApplication {
  pname = "hello-py";
  version = "0.1.0";
  pyproject = true;
  src = ./.;

  build-system = [ pkgs.python3Packages.hatchling ];
  dependencies = [ pkgs.python3Packages.art ];
}
```

- `pyproject = true;` says the project is built from its `pyproject.toml`.

- `build-system` is what builds the package, here hatchling, just like
`requires` says.

- `dependencies` is what the program needs when it runs, here `art`.

No hash for the dependencies, and no build steps:

```console
$ nix build --file default.nix
$ ./result/bin/hello-py
        _
 _ __  (_)__  __
| '_ \ | |\ \/ /
| | | || | >  <
|_| |_||_|/_/\_\
```

The builder also checks your list against `pyproject.toml`. Forget
`art` in `dependencies`, and the build stops before you ever ship a program
that crashes on its first import. The log is cut down to `…` here:

```console
$ nix build --file default.nix
error: Cannot build '/nix/store/cycmwycsvxcbgvqbd9ficggrl05brhyz-hello-py-0.1.0.drv'.
       Reason: builder failed with exit code 1.
       …
       > Running phase: pythonRuntimeDepsCheckHook
       > Executing pythonRuntimeDepsCheck
       > Checking runtime dependencies for hello_py-0.1.0-py2.py3-none-any.whl
       >   - art not installed
```

Recipes in nixpkgs look exactly the same. Here’s termdown, a countdown timer
for your terminal:

`termdown/package.nix`:

```nix
{
  lib,
  fetchFromGitHub,
  python3Packages,
}:

python3Packages.buildPythonApplication (finalAttrs: {
  pname = "termdown";
  version = "2.0.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "trehn";
    repo = "termdown";
    tag = finalAttrs.version;
    hash = "sha256-G2YOAC+b++oQUicZcY28qVDy2XqW2SuzhXcVqeSQkh8=";
  };

  build-system = with python3Packages; [
    hatchling
  ];

  dependencies = with python3Packages; [
    art
    pillow
    python-dateutil
  ];
})
```

`with python3Packages;` simply saves writing `python3Packages.` in front of every
library.

## Rust projects

Rust projects come with Cargo, and Cargo wants to download your dependencies
right in the middle of the build. But a Nix build isn’t allowed on the network.
So watch what happens with hello-rs, a tiny Rust program that uses one library,
colored, built with a plain `mkDerivation` that simply runs `cargo build`:

`default.nix`:

```nix
let
  pkgs = import <nixpkgs> { };
in
pkgs.stdenv.mkDerivation {
  pname = "hello-rs";
  version = "0.1.0";
  src = ./.;
  nativeBuildInputs = [ pkgs.cargo pkgs.rustc ];
  buildPhase = "cargo build --release";
  installPhase = "install -D target/release/hello-rs $out/bin/hello-rs";
}
```

`-v` makes `nix build` say what it builds:

```console
$ nix build -v --file default.nix
this derivation will be built:
  /nix/store/mmgh2v92rmw24y574l2dqpryz969yv7b-hello-rs-0.1.0.drv
building '/nix/store/mmgh2v92rmw24y574l2dqpryz969yv7b-hello-rs-0.1.0.drv'...
error: Cannot build '/nix/store/mmgh2v92rmw24y574l2dqpryz969yv7b-hello-rs-0.1.0.drv'.
       Reason: builder failed with exit code 101.
       Output paths:
         /nix/store/22lzkhrvmf087ydnv4y1m7jn21vliaq4-hello-rs-0.1.0
       Last 22 log lines:
       > Running phase: unpackPhase
       > unpacking source archive /nix/store/mb5qj081d4682aq15lvj9aszkj410lqy-hello-rs
       > source root is hello-rs
       > Running phase: patchPhase
       > Running phase: updateAutotoolsGnuConfigScriptsPhase
       > Running phase: configurePhase
       > no configure script, doing nothing
       > Running phase: buildPhase
       >     Updating crates.io index
       > warning: spurious network error (3 tries remaining): [6] Could not resolve hostname (Could not resolve host: index.crates.io)
       > warning: spurious network error (2 tries remaining): [6] Could not resolve hostname (Could not resolve host: index.crates.io)
       > warning: spurious network error (1 try remaining): [6] Could not resolve hostname (Could not resolve host: index.crates.io)
       > error: failed to get `colored` as a dependency of package `hello-rs v0.1.0 (/build/hello-rs)`
       >
       > Caused by:
       >   download of config.json failed
       >
       > Caused by:
       >   failed to download from `https://index.crates.io/config.json`
       >
       > Caused by:
       >   [6] Could not resolve hostname (Could not resolve host: index.crates.io)
       For full logs, run:
         nix log /nix/store/mmgh2v92rmw24y574l2dqpryz969yv7b-hello-rs-0.1.0.drv
```

Cargo goes to crates.io for colored, and inside the build there’s no network to
reach it.

So instead, nixpkgs has `rustPlatform.buildRustPackage`. It downloads your
dependencies in a separate step first, and that step may use the network,
because Nix checks what it gets against a hash, `cargoHash`. Then it runs
`cargo build` for you.

With `buildRustPackage`, there’s no `buildPhase` or `installPhase` to write at
all. But you can’t know the dependency hash before the first build. So `cargoHash`
starts out as `lib.fakeHash`, a placeholder made of `A`s. The build fails, and
tells you the real one:

`default.nix`:

```nix
let
  pkgs = import <nixpkgs> { };
in
pkgs.rustPlatform.buildRustPackage {
  pname = "hello-rs";
  version = "0.1.0";
  src = ./.;
  cargoHash = pkgs.lib.fakeHash;
}
```

```console
$ nix build -v --file default.nix
these 3 derivations will be built:
  /nix/store/d9c29ad00k57hj83jvhimlqj85jxl5sz-hello-rs-0.1.0-vendor-staging.drv
  /nix/store/qcffyiq38f9ixkwxn8izq99l4d3ihf9n-hello-rs-0.1.0-vendor.drv
  /nix/store/b6ics4dkanvd5kwfn8kkacym26z186sx-hello-rs-0.1.0.drv
building '/nix/store/d9c29ad00k57hj83jvhimlqj85jxl5sz-hello-rs-0.1.0-vendor-staging.drv'...
error: hash mismatch in fixed-output derivation '/nix/store/d9c29ad00k57hj83jvhimlqj85jxl5sz-hello-rs-0.1.0-vendor-staging.drv':
         specified: sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
            got:    sha256-0BwTOd0u9Y2aV2jog0WKiAfMhTatiNX8yahqj4FFIE8=
error: Cannot build '/nix/store/qcffyiq38f9ixkwxn8izq99l4d3ihf9n-hello-rs-0.1.0-vendor.drv'.
       Reason: 1 dependency failed.
       Output paths:
         /nix/store/ixpxlv6v0h9vxzvvwppirf9yhgw5q970-hello-rs-0.1.0-vendor
error: Cannot build '/nix/store/b6ics4dkanvd5kwfn8kkacym26z186sx-hello-rs-0.1.0.drv'.
       Reason: 1 dependency failed.
       Output paths:
         /nix/store/w35g055z7wqsa9kr81v0vhkll48f2fhj-hello-rs-0.1.0
```

The `-vendor-staging` derivation is that separate download step, and it’s the
one that failed. The real hash is right there, after `got:`.

Put `"sha256-0BwTOd0u9Y2aV2jog0WKiAfMhTatiNX8yahqj4FFIE8="` in place of
`pkgs.lib.fakeHash`, and the build goes through:

```console
$ nix build -v --file default.nix
these 2 derivations will be built:
  /nix/store/9kgi6ma7zlypfcdg679w0zvxyvwx6pi6-hello-rs-0.1.0-vendor.drv
  /nix/store/g4zh2nixzycjdmj2vq19hcxs23sixx74-hello-rs-0.1.0.drv
building '/nix/store/9kgi6ma7zlypfcdg679w0zvxyvwx6pi6-hello-rs-0.1.0-vendor.drv'...
building '/nix/store/g4zh2nixzycjdmj2vq19hcxs23sixx74-hello-rs-0.1.0.drv'...
$ ./result/bin/hello-rs
hello world
```

`cargoHash` describes the dependencies locked in `Cargo.lock`, not
your own code. So you can change your code all you want, and keep the same hash. Change `Cargo.lock`,
say to add a dependency, and the next build stops with
`ERROR: cargoHash or cargoSha256 is out of date` until you put in the new one.

## Sharing your package

Put your package in a flake, and anyone in the world can
build or run it with one command, without even cloning your repository.

`nix build` and `nix run` need to know where your package is. In a flake, that
place is the `packages` output. First comes the system the package is built
for, like `x86_64-linux` for an ordinary 64-bit Linux PC. Then comes the
package’s name. Together they make `packages.x86_64-linux.my-project`.

Below is a small C project’s recipe in a flake. It builds a program called
`my-project` that prints which OpenSSL it was built with:

`flake.nix`:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in
    {
      packages.x86_64-linux.my-project = pkgs.stdenv.mkDerivation {
        pname = "my-project";
        version = "0.1.0";
        src = ./.;

        nativeBuildInputs = [ pkgs.pkg-config ];
        buildInputs = [ pkgs.openssl ];

        makeFlags = [ "PREFIX=$(out)" ];
      };
    };
}
```

It needs `openssl`, plus `pkg-config` to find it. `makeFlags` tells its
Makefile to install into `$out`, the package’s directory in the store.

`nix flake show` lists everything a flake offers:

```console
$ nix flake show
warning: creating lock file "/tmp/my-project/flake.lock":
• Added input 'nixpkgs':
    'github:NixOS/nixpkgs/774debe7a0d1b496e35677ad955a1011c6ff74f3?narHash=sha256-nQyFkMR78WP6PiXKkDW2SjqzLf/spQqjRuxRGSbcV8k%3D' (2026-10-02)
git+file:///tmp/my-project?ref=refs/heads/master&rev=71c31f2df88a177888de247a3d5a89010bc726d0
└───packages
    └───x86_64-linux
        └───my-project: package 'my-project-0.1.0'
```

To build a package, put its address after a `#`. The `.` in front means the
flake in the current directory. These two build the same thing:

- `nix build .#packages.x86_64-linux.my-project`

- `nix build .#my-project`

Nix simply fills in `packages` and your system for you, so the short one is
what people actually type:

```console
$ nix build .#my-project
warning: Git tree '/tmp/my-project' is dirty
$ ./result/bin/my-project
my-project, built with OpenSSL 3.6.4 25 Aug 2026
```

And since `nix build` takes any flake address, `.` can just as well be a flake
on GitHub. Push yours, and anyone can build it straight from there.

## The default package

Here’s something cool. This runs nh, a helper for rebuilding NixOS, straight
from its flake on GitHub, without installing anything. Nix builds it first,
so the first run takes a few minutes:

```console
$ nix run github:nix-community/nh/v4.4.2 -- --version
nh 4.4.2
```

Notice that nobody typed a package name! That works because nh’s flake has
a package called `default`, and `nix run` starts that one whenever you don’t
name another. Plain `nix build` builds that one too.

Your own `default` usually isn’t a second recipe though. It simply points at the
package you already wrote. `self` is your flake’s own outputs, so
`self.packages.x86_64-linux.my-project` is the `my-project` package below. Meaning `default`
and `my-project` will build exactly the same package.

### Try it

Below the `my-project` package, add `packages.x86_64-linux.default = self.packages.x86_64-linux.my-project;`.

- Offer `packages.x86_64-linux.default`

- Point it at `my-project`flake.nixFlakeA flake with inputs and outputs.Project filesA file in the example project.

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in
    {
      packages.x86_64-linux.my-project = pkgs.stdenv.mkDerivation {
        pname = "my-project";
        version = "0.1.0";
        src = ./.;

        nativeBuildInputs = [ pkgs.pkg-config ];
        buildInputs = [ pkgs.openssl ];

        makeFlags = [ "PREFIX=$(out)" ];
      };
    };
}
```

Now `nix flake show` lists both names, and plain `nix run` starts your program:

```console
$ nix flake show
git+file:///tmp/my-project?ref=refs/heads/master&rev=f7b9e593932b871540e45ed7b0853621a3b14e93
└───packages
    └───x86_64-linux
        ├───default: package 'my-project-0.1.0'
        └───my-project: package 'my-project-0.1.0'
$ nix run
my-project, built with OpenSSL 3.6.4 25 Aug 2026
```

Push your flake, and anyone can run your program the exact same way as nh.

## Package your project

Turn the small Node.js project from the devshell simulation into a package anyone
can build and run.

Takes about 25 minutes.

You’ll:

- write its recipe with `buildNpmPackage`

- let the first build fail, and paste in the hash it tells you

- run your program on its own, outside the devshell

- move the recipe into `default.nix` and start it with `nix run`

Continues from Create a devshell for your project.

Everything happens in your browser. Nothing gets installed on your computer.

## Build phases

Building a program from source usually takes a few steps you’d run by hand:
unpack the source, `./configure`, `make`, `make install`. The builder that
`mkDerivation` gives you is simply a Bash script that runs those same steps for
you, one after another. Each step is called a phase.

These are the main ones, in the order they run:

- `unpackPhase` unpacks `src`.

- `patchPhase` applies your `patches`.

- `configurePhase` runs `./configure`, if the project has one.

- `buildPhase` runs `make`.

- `checkPhase` runs the project’s tests.

- `installPhase` runs `make install`.

- `fixupPhase` tidies up the result, for example by cutting debug info out of
programs to make them smaller.

Tests are off by default. `checkPhase` only runs when you set `doCheck = true;`,
so a plain build skips them.

But not every project has a `configure` script or a Makefile. When a default
doesn’t fit, you simply set that phase to your own shell code. Take a project
that’s just one C file:

```console
$ cat main.c
#include <stdio.h>
int main(void) {
  printf("hello from my-program\n");
  return 0;
}
```

There’s nothing for `make` to run, so the recipe says how to compile it and
what to keep:

`default.nix`:

```nix
let
  pkgs = import <nixpkgs> { };
in
pkgs.stdenv.mkDerivation {
  pname = "my-program";
  version = "1.0";
  src = ./.;

  buildPhase = ''
    gcc -o my-program main.c
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp my-program $out/bin
  '';
}
```

`$out` is the package’s path in the store. `installPhase` has to copy the
program there, because the build directory is thrown away afterwards and only
`$out` is kept.

With `-L`, `nix build` shows the phases as they run:

```console
$ nix build -L --file default.nix
my-program> Running phase: unpackPhase
my-program> unpacking source archive /nix/store/g9dc05gsb6fh89dkfpqa24xx2h1xv2k2-my-program
my-program> source root is my-program
my-program> Running phase: patchPhase
my-program> Running phase: updateAutotoolsGnuConfigScriptsPhase
my-program> Running phase: configurePhase
my-program> no configure script, doing nothing
my-program> Running phase: buildPhase
my-program> Running phase: installPhase
my-program> Running phase: fixupPhase
my-program> shrinking RPATHs of ELF executables and libraries in /nix/store/93wm9sc4clw7majwgj25xvcqli7c1gmx-my-program-1.0
my-program> shrinking /nix/store/93wm9sc4clw7majwgj25xvcqli7c1gmx-my-program-1.0/bin/my-program
my-program> checking for references to /build/ in /nix/store/93wm9sc4clw7majwgj25xvcqli7c1gmx-my-program-1.0...
my-program> patching script interpreter paths in /nix/store/93wm9sc4clw7majwgj25xvcqli7c1gmx-my-program-1.0
my-program> stripping (with command strip and flags -S -p) in  /nix/store/93wm9sc4clw7majwgj25xvcqli7c1gmx-my-program-1.0/bin
$ ./result/bin/my-program
hello from my-program
```

`checkPhase` is missing from the log because `doCheck` isn’t set.
`updateAutotoolsGnuConfigScriptsPhase` is an extra step `stdenv` slips in
before `configurePhase`.

Leave `installPhase` out, and the build fails. The default one finds no Makefile
and does nothing, so nothing ends up in `$out`:

```console
$ nix build -L --file default.nix
…
my-program> Running phase: installPhase
my-program> no Makefile or custom installPhase, doing nothing
my-program> Running phase: fixupPhase
error: builder for '/nix/store/6llxpzmirj8fzmi8pgcnwim0imkm9qzi-my-program-1.0.drv' failed to produce output path for output 'out' at "/nix/store/6llxpzmirj8fzmi8pgcnwim0imkm9qzi-my-program-1.0.drv.chroot/root/nix/store/ag1jb0i6qfn1vvj3808hjbbmclw0ddwq-my-program-1.0"
```

## buildInputs and nativeBuildInputs

A program rarely builds from its source alone. It needs tools that do the
building, like a compiler or CMake, and libraries it links against, like Qt or
OpenSSL. A recipe keeps those in two separate lists: `nativeBuildInputs` for the
tools, and `buildInputs` for the libraries. Open almost any recipe in nixpkgs,
and you’ll find both.

Here’s the recipe for a small Qt app built with CMake. Its `CMakeLists.txt`
asks for Qt with `find_package(Qt6 REQUIRED COMPONENTS Widgets)`. Its
`package.nix` fills both lists:

`package.nix`:

```nix
{
  stdenv,
  cmake,
  qt6,
}:

stdenv.mkDerivation {
  pname = "my-app";
  version = "1.0";
  src = ./.;

  nativeBuildInputs = [
    cmake
    qt6.wrapQtAppsHook
  ];

  buildInputs = [ qt6.qtbase ];
}
```

`cmake` and `qt6.wrapQtAppsHook` run while the package builds, so they go in
`nativeBuildInputs`. `qt6.qtbase` is the Qt library the program links
against, so it goes in `buildInputs`.

A `default.nix` next to the recipe loads it. `callPackage` fills in the
recipe’s arguments, like `cmake` and `qt6`, from nixpkgs. The build log
starts like this, with the long line of cmake flags cut down to `…`:

```console
$ cat default.nix
let
  pkgs = import <nixpkgs> { };
in
pkgs.callPackage ./package.nix { }
$ nix build -L --file default.nix
my-app> Running phase: qtPreHook
my-app> Running phase: unpackPhase
my-app> unpacking source archive /nix/store/v8h46r0dhvjk1lfrx86ylcgvj3pvjibd-my-app
my-app> source root is my-app
my-app> Running phase: patchPhase
my-app> Running phase: updateAutotoolsGnuConfigScriptsPhase
my-app> Running phase: configurePhase
my-app> cmake flags: -DCMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY=OFF …
my-app> -- The CXX compiler identification is GNU 15.3.0
my-app> -- Detecting CXX compiler ABI info
```

Notice the very first phase, `qtPreHook`. A plain build has no such phase.
It comes from `qtbase`. Any package in either list can bring a setup hook, a
bit of shell code that adds phases or changes what they do.

Then look at `configurePhase`. On its own, that step runs a `./configure`
script. In this build it runs `cmake` instead, and the lines after it are
CMake’s own. The `cmake` hook swapped the step out. The same hook points
`find_package` at everything in `buildInputs`, so `find_package(Qt6 ...)`
finds `qtbase` without a single path in the recipe.

`wrapQtAppsHook` is the one Qt apps cannot skip. Qt loads its plugins while the
program runs. `wrapQtAppsHook` handles that by putting each installed program
inside a small wrapper that tells Qt where the plugins are. The same recipe
without it looks like this:

`package.nix`:

```nix
{
  stdenv,
  cmake,
  qt6,
}:

stdenv.mkDerivation {
  pname = "my-app";
  version = "1.0";
  src = ./.;

  nativeBuildInputs = [ cmake ];

  buildInputs = [ qt6.qtbase ];
}
```

Leave the hook out, and the build stops right away:

```console
$ nix build --file default.nix
error: Cannot build '/nix/store/x0wabb04b46nsqm9zbl10izdgfj81dcb-my-app-1.0.drv'.
       Reason: builder failed with exit code 1.
       Output paths:
         /nix/store/haw1db6q8qcimfibra3nvbvkq73kwx6i-my-app-1.0
       Last 4 log lines:
       > Running phase: qtPreHook
       > Error: this derivation depends on qtbase, but no wrapping behavior was specified.
       >   - If this is an application, add wrapQtAppsHook to nativeBuildInputs
       >   - If this is a library or you need custom wrapping logic, set dontWrapQtApps = true
       For full logs, run:
         nix log /nix/store/x0wabb04b46nsqm9zbl10izdgfj81dcb-my-app-1.0.drv
```

The `qtPreHook` from before is what stops it. `qtbase` checks for the
wrapper while the package builds. So you never ship a Qt app that can’t find
its plugins.

So the rule of thumb is simple. If it runs while the package builds, it goes in
`nativeBuildInputs`. If your program uses it once it’s built, it goes in
`buildInputs`.

## Hooks and runHook

Often a default phase is almost right, and you only want one more step. For
that, the main phases each have two hooks: one that runs at the start of the phase,
and one at the end.

- `preBuild` runs at the start of `buildPhase`, and `postBuild` at its end.

- `preInstall` and `postInstall` do the same inside `installPhase`.

And so on, for the other main phases. A hook adds a step without replacing the phase.

ddgr’s recipe in nixpkgs never writes a phase at all. ddgr is a tool
that searches DuckDuckGo from your terminal. Its Makefile installs the
program and its manual, and a single hook adds what it leaves out, the shell
completions:

`ddgr/package.nix`:

```nix
{
  stdenv,
  python3,
  installShellFiles,
}:

stdenv.mkDerivation (finalAttrs: {
  version = "2.2";
  pname = "ddgr";

  nativeBuildInputs = [ installShellFiles ];

  buildInputs = [ python3 ];

  makeFlags = [ "PREFIX=$(out)" ];

  postInstall = ''
    installShellCompletion --bash --name ddgr.bash auto-completion/bash/ddgr-completion.bash
    installShellCompletion --fish auto-completion/fish/ddgr.fish
    installShellCompletion --zsh auto-completion/zsh/_ddgr
  '';
})
```

`$(out)` is how `make` reads the `out` variable, the package’s store path. So
`make install` puts ddgr into `$out`. After that, `postInstall` adds
completions for Bash, fish and zsh.

The `installShellCompletion` command comes from `installShellFiles`. That’s why
`installShellFiles` is in `nativeBuildInputs`.

Here’s `my-program`, which writes its own `installPhase`, with a `postInstall`
added next to it:

`default.nix`:

```nix
let
  pkgs = import <nixpkgs> { };
in
pkgs.stdenv.mkDerivation {
  pname = "my-program";
  version = "1.0";
  src = ./.;

  buildPhase = ''
    gcc -o my-program main.c
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp my-program $out/bin
  '';

  postInstall = ''
    echo done
  '';
}
```

The build works, but `done` never shows up in the log:

```console
$ nix build -L --file default.nix
…
my-program> Running phase: buildPhase
my-program> Running phase: installPhase
my-program> Running phase: fixupPhase
…
```

A phase you write yourself skips its hooks! That’s because the default
`installPhase` is what calls them, and your own code replaces it whole, calls
included.

The fix is to call the hooks yourself with `runHook`, at the start and end of
your phase:

`default.nix`:

```nix
let
  pkgs = import <nixpkgs> { };
in
pkgs.stdenv.mkDerivation {
  pname = "my-program";
  version = "1.0";
  src = ./.;

  buildPhase = ''
    gcc -o my-program main.c
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp my-program $out/bin
    runHook postInstall
  '';

  postInstall = ''
    echo done
  '';
}
```

Now `done` shows up in the log, right inside the install phase:

```console
$ nix build -L --file default.nix
…
my-program> Running phase: buildPhase
my-program> Running phase: installPhase
my-program> done
my-program> Running phase: fixupPhase
…
```

That’s why most recipes in nixpkgs that write their own `installPhase` start
and end it with these two lines. Here’s `sl`, the steam locomotive that rolls
across your terminal when you mistype `ls`:

`sl/package.nix`:

```nix
{
  stdenv,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "sl";
  version = "5.05";

  installPhase = ''
    runHook preInstall

    install -Dm755 -t $out/bin sl
    install -Dm644 -t $out/share/man/man1 sl.1{,.ja}

    runHook postInstall
  '';
})
```

## Fetchers

A package build normally runs without network access, so it cannot download
its source halfway through. Fetchers are the exception. `fetchurl`,
`fetchFromGitHub`, `fetchgit` and friends from `pkgs` are derivations that are
allowed online, because you write down the hash of what they’ll download before
they run.

If the download matches the hash, Nix keeps it in the store, and anyone who
builds with that hash gets exactly the same files. If it doesn’t, the build
stops with a hash mismatch. Here’s how GNU Hello gets its source:

`hello/package.nix`:

```nix
{
  stdenv,
  fetchurl,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "hello";
  version = "2.12.3";

  src = fetchurl {
    url = "mirror://gnu/hello/hello-${finalAttrs.version}.tar.gz";
    hash = "sha256-DV9gFUOC/uELEUocNOeF2LH0kgc64tOm97FHaHs2aqA=";
  };
})
```

`mirror://gnu` is simply nixpkgs shorthand for the GNU download mirrors.

The hash has to change whenever the version does, because a new
version is a different file. But how do you get the hash of a file you haven’t
even downloaded yet? You simply let Nix tell you:

- Put in `lib.fakeHash`, a placeholder made of `A`s.

- Build. The download doesn’t match, so the build fails.

- Copy the hash from the error’s `got:` line into your recipe.

Say you want the older Hello 2.12.2. Its file is different, so it needs a new
hash. Here’s the whole loop in `nix repl`, where `:b` builds whatever you give
it:

```console
$ nix repl
Nix 2.34.8
Type :? for help.
nix-repl> pkgs = import <nixpkgs> { }
nix-repl> :b pkgs.fetchurl { url = "mirror://gnu/hello/hello-2.12.2.tar.gz"; hash = pkgs.lib.fakeHash; }
error: hash mismatch in fixed-output derivation '/nix/store/10hp2cdxxhr9vspqw0ispvcr13mspsyi-hello-2.12.2.tar.gz.drv':
         specified: sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
            got:    sha256-WpqZbcKSzCTc9BHO6H6S9qrluNE72caBm0x6nc4IGKs=
[0 built (1 failed), 0.0 KiB DL]
nix-repl> :b pkgs.fetchurl { url = "mirror://gnu/hello/hello-2.12.2.tar.gz"; hash = "sha256-WpqZbcKSzCTc9BHO6H6S9qrluNE72caBm0x6nc4IGKs="; }
This derivation produced the following outputs:
  out -> /nix/store/dw402azxjrgrzrk6j0p66wkqrab5mwgw-hello-2.12.2.tar.gz
```

The same trick works for every fetcher, and for every other hash Nix will ever
ask you for.

## Choosing source files

Here’s a small C project, packaged with a recipe right next to its code. A
`default.nix` beside it loads the recipe with `callPackage`:

`package.nix`:

```nix
{ stdenv, pkg-config, openssl }:

stdenv.mkDerivation {
  pname = "my-project";
  version = "0.1.0";
  src = ./.;

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ openssl ];

  makeFlags = [ "PREFIX=$(out)" ];
}
```

`src = ./.;` is handy, but it takes the whole directory. That means any change in
it makes a new source, and a new build. Even fixing a typo in `README.md` does.
`-v` makes `nix build` say what it builds:

```console
$ echo "Fixed a typo." >> README.md
$ nix build -v --file default.nix
this derivation will be built:
  /nix/store/cbkw6ahhncvhfhkr74izavh0ilp1xvl3-my-project-0.1.0.drv
building '/nix/store/cbkw6ahhncvhfhkr74izavh0ilp1xvl3-my-project-0.1.0.drv'...
```

So instead, pick the files yourself. `lib.fileset.toSource` puts only the files you
list into the store. The recipe now asks for `lib` too:

`package.nix`:

```nix
{ lib, stdenv, pkg-config, openssl }:

stdenv.mkDerivation {
  pname = "my-project";
  version = "0.1.0";
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [ ./main.c ./Makefile ];
  };

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ openssl ];

  makeFlags = [ "PREFIX=$(out)" ];
}
```

`root` is the directory the files come from. `unions` joins your list into one set of files.

Now only `main.c` and the `Makefile` go into the store. Build it once, then
fix another typo:

```console
$ nix build -v --file default.nix
this derivation will be built:
  /nix/store/m6414cdljhx0g5vcx91vdcjd6p5z5qi1-my-project-0.1.0.drv
building '/nix/store/m6414cdljhx0g5vcx91vdcjd6p5z5qi1-my-project-0.1.0.drv'...
$ echo "Fixed another typo." >> README.md
$ nix build -v --file default.nix
```

The second build printed nothing. The README never made it into
the store, so there was nothing new to build.

## From your project to nixpkgs

A recipe that reads `src` from the directory next to it only builds where the
code is. But once you publish a release, `src` can download it from GitHub
instead. Then the recipe can live anywhere, in your own config, or even in
nixpkgs.

Here’s how that looks for a real project. hcxtools is a C project on GitHub, and
its Makefile finds OpenSSL with `pkg-config`. This recipe asks for
`fetchFromGitHub`, and uses it in `src`. Put it in a directory as `package.nix`,
next to a `default.nix` that loads it with `callPackage`:

`package.nix`:

```nix
{ stdenv, fetchFromGitHub, pkg-config, curl, openssl, zlib }:

stdenv.mkDerivation {
  pname = "hcxtools";
  version = "7.1.2";
  src = fetchFromGitHub {
    owner = "ZerBea";
    repo = "hcxtools";
    rev = "7.1.2";
    hash = "";
  };

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ curl openssl zlib ];

  makeFlags = [ "PREFIX=$(out)" ];
}
```

You don’t know the hash yet, so leave it empty. Just like `lib.fakeHash`, the
build stops and tells you the right one. `-v` makes `nix build` say what it builds:

```console
$ nix build -v --file default.nix
these 2 derivations will be built:
  /nix/store/z5k3rh86kx4pmlpbp7221jaadjmzih1r-source.drv
  /nix/store/55jxm669ds8i9dcvqj3f0dqsk293hhk3-hcxtools-7.1.2.drv
building '/nix/store/z5k3rh86kx4pmlpbp7221jaadjmzih1r-source.drv'...
error: hash mismatch in fixed-output derivation '/nix/store/z5k3rh86kx4pmlpbp7221jaadjmzih1r-source.drv':
         specified: sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
            got:    sha256-v33RpDKA4OeUU4YXXWhHpdlqQvxk4HIWQKCPskdTSTU=
error: Cannot build '/nix/store/55jxm669ds8i9dcvqj3f0dqsk293hhk3-hcxtools-7.1.2.drv'.
       Reason: 1 dependency failed.
       Output paths:
         /nix/store/d4g0xam105jn3ilf85021g5qi00nbi6q-hcxtools-7.1.2
```

Copy the hash after `got:` into `hash`, and build again:

```console
$ nix build -v --file default.nix
this derivation will be built:
  /nix/store/2raz6q02bpplv858s1n6xxbfb08b3hsb-hcxtools-7.1.2.drv
building '/nix/store/2raz6q02bpplv858s1n6xxbfb08b3hsb-hcxtools-7.1.2.drv'...
$ ./result/bin/hcxpcapngtool --version
hcxpcapngtool 7.1.2 (C) 2026 ZeroBeat
```

Now compare it with the hcxtools recipe that really lives in nixpkgs:

`hcxtools/package.nix`:

```nix
{
  lib,
  stdenv,
  fetchFromGitHub,
  pkg-config,
  curl,
  openssl,
  zlib,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "hcxtools";
  version = "7.1.2";

  src = fetchFromGitHub {
    owner = "ZerBea";
    repo = "hcxtools";
    rev = finalAttrs.version;
    sha256 = "sha256-v33RpDKA4OeUU4YXXWhHpdlqQvxk4HIWQKCPskdTSTU=";
  };

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [
    curl
    openssl
    zlib
  ];

  makeFlags = [
    "PREFIX=${placeholder "out"}"
  ];

  meta = {
    description = "Tools for capturing wlan traffic and conversion to hashcat and John the Ripper formats";
    homepage = "https://github.com/ZerBea/hcxtools";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    maintainers = with lib.maintainers; [ dywedir ];
  };
})
```

It’s the recipe you just wrote, with the exact same hash! Only a few small things
differ:

- `meta` describes the package, its license and who looks after it.

- `finalAttrs.version` reuses the version, so it’s written only once.

- `placeholder "out"` is another way to write the package’s store path.

- `sha256` is an older name for `hash`.

Meaning your `package.nix` could go into nixpkgs almost as it is. And that’s
exactly how most packages get there: somebody needed a program, wrote a recipe,
and sent it in.

## The build sandbox

A build that could read anything on your computer would quietly depend on
whatever happens to be installed there, and break on the next machine. So on
Linux, Nix runs every builder inside a sandbox, a small isolated world made for
that one build. The builder sees the store paths its derivation lists, a
temporary build directory, and a few basics like `/dev` and `/proc`. Your home
directory, the programs installed on your system and the network all stay
outside.

Nix also clears the environment, so the builder doesn’t get your environment
variables either. Let’s ask a builder where its home is:

`builder-home.nix`:

```nix
derivation {
  name = "builder-home";
  system = "x86_64-linux";
  builder = "/bin/sh";
  args = [ "-c" "echo $HOME > $out" ];
}
```

```console
$ nix-build builder-home.nix
this derivation will be built:
  /nix/store/zixy215m44cq116qr0xmczqfmbhv5qn8-builder-home.drv
building '/nix/store/zixy215m44cq116qr0xmczqfmbhv5qn8-builder-home.drv'...
/nix/store/2sd4i6fhq8q2rgsd8y1bscgzr3wbsf4n-builder-home
$ cat result
/homeless-shelter
```

Nix sets `HOME` to `/homeless-shelter`, a directory that doesn’t exist, on every
machine. Inside the sandbox there’s no `/home` either, so even a builder that
goes looking for your files by their full path finds nothing. So a build
cannot pick up a library that happens to be on your laptop, or download
something different tomorrow, because it cannot reach either.

The one exception is a download with its hash written in the recipe. It gets
network access, because Nix checks the result against that hash anyway.

On macOS, Nix leaves the sandbox off by default, so there it’s up to the
recipe to behave.

## Derivations in strings

Sooner or later one package needs the exact path of another, for a script, a
config file or a keyboard shortcut. Put a derivation inside a string with
`${ }`, and Nix puts its store path there. Here’s a tiny script that runs cowsay by
its full path:

```nix
let
  pkgs = import <nixpkgs> { };
in
  ''
    #!/bin/sh
    ${pkgs.cowsay}/bin/cowsay "Hello from Nix"
  ''
```

Every derivation has an `outPath` attribute. It’s the store path where its
result will land. Put the string and `outPath` in one list and compare:

```nix
let
  hello-world = derivation {
    name = "hello-world";
    system = "x86_64-linux";
    builder = "/bin/sh";
    args = [ "-c" "echo hello world > $out" ];
  };
in
  [ "${hello-world}" hello-world.outPath ]
```

They’re the same path. `${ }` looks for `outPath` in any attribute set you give it, and a
derivation is an attribute set that has one. So any set with an `outPath`
works, even one you write by hand:

```nix
"${ { outPath = "/home/yurii/notes"; } }"
```

NixOS starts its services the same way. illum is a small daemon for the
screen brightness buttons, and this is its module from nixpkgs, cut down to the
service:

`nixos/modules/services/hardware/illum.nix`:

```nix
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.illum;
in
{
  config = lib.mkIf cfg.enable {
    systemd.services.illum = {
      description = "Backlight Adjustment Service";
      wantedBy = [ "multi-user.target" ];
      serviceConfig.ExecStart = "${pkgs.illum}/bin/illum-d";
      serviceConfig.Restart = "on-failure";
    };
  };
}
```

`${pkgs.illum}` turns into the store path of the illum package, and
`/bin/illum-d` goes after it. So the service always runs the exact illum your
configuration built, by its full path.

But the string also quietly remembers which derivation it came from. Use it
inside another derivation, and Nix makes that derivation an input of the
build, without you listing it anywhere. This second derivation reads the file
`hello-world` built and copies its text:

```nix
let
  hello-world = derivation {
    name = "hello-world";
    system = "x86_64-linux";
    builder = "/bin/sh";
    args = [ "-c" "echo hello world > $out" ];
  };
in
  derivation {
    name = "hello-world-copy";
    system = "x86_64-linux";
    builder = "/bin/sh";
    args = [ "-c" "read text < ${hello-world}; echo $text > $out" ];
  }
```

```console
$ nix-store --query --references /nix/store/kjwi369mnwfm0xblisf5afxnhzh73jig-hello-world-copy.drv
/nix/store/dp5na63mzhc3a2kkiy37b3xq642k7lhy-hello-world.drv
$ nix-build /nix/store/kjwi369mnwfm0xblisf5afxnhzh73jig-hello-world-copy.drv
This derivation will be built:
  /nix/store/kjwi369mnwfm0xblisf5afxnhzh73jig-hello-world-copy.drv
building '/nix/store/kjwi369mnwfm0xblisf5afxnhzh73jig-hello-world-copy.drv'...
/nix/store/7ffhsri1q0qjy6qd2ymy48zs5rra3isg-hello-world-copy
$ cat result
hello world
```

The first command lists what the recipe depends on. There’s the `.drv` of
`hello-world`, even though the script only mentions a path. On a fresh
machine, Nix would build `hello-world` first. This machine had built it
already, so Nix only built the copy.

The builder only gets to read the inputs of its recipe. Now paste the same
path in as plain text, without `${ }`:

```nix
derivation {
  name = "hello-world-copy";
  system = "x86_64-linux";
  builder = "/bin/sh";
  args = [ "-c" "read text < /nix/store/kbh84yclhgn33j34j9i4wxha04v79q5f-hello-world; echo $text > $out" ];
}
```

```console
$ nix-store --query --references /nix/store/yij30cpw5gffkzaicqd3s4ql9xp1yyr6-hello-world-copy.drv
$ nix-build /nix/store/yij30cpw5gffkzaicqd3s4ql9xp1yyr6-hello-world-copy.drv
This derivation will be built:
  /nix/store/yij30cpw5gffkzaicqd3s4ql9xp1yyr6-hello-world-copy.drv
building '/nix/store/yij30cpw5gffkzaicqd3s4ql9xp1yyr6-hello-world-copy.drv'...
sh: can't open /nix/store/kbh84yclhgn33j34j9i4wxha04v79q5f-hello-world: no such file
/nix/store/chyvbdy3gz9vy2hkqa2kq33ayqfhdpql-hello-world-copy
$ cat result
```

The script still reads the exact same path. But the recipe has no
inputs now, so the builder can’t see that file, even though it’s right there
on this machine. The build still finishes, because the script carries on after
`read` fails. So the copy comes out empty. Only `${ }` brings `hello-world`
along.

A path works in `${ }` too. Nix copies the file into the store and puts
the copy’s store path in the string:
notes.txtread only

```nix
buy milk
```

`default.nix`:

`default.nix`:
```nix
"${./notes.txt}"
```

Like `hello-world`, the copy becomes an input of any recipe that uses
the string. This one reads the note:
notes.txtread only

```nix
buy milk
```

`default.nix`:

`default.nix`:
```nix
derivation {
  name = "shopping";
  system = "x86_64-linux";
  builder = "/bin/sh";
  args = [ "-c" "read text < ${./notes.txt}; echo $text > $out" ];
}
```

```console
$ nix-store --query --references /nix/store/b7z6pk3yznrd50mh6w14j0fvc29imqqx-shopping.drv
/nix/store/vp6x1q76f8hv5g6nm26ckzqvy9dmhvq9-notes.txt
```

The note is there, so the builder gets to read it. Your own files can end up
in a package this way.

### Try it

Change the text `hello-world` writes from `hello world` to `hello nix`. The copy's path changes too, because its script holds the path of `hello-world`.

```nix
let
  hello-world = derivation {
    name = "hello-world";
    system = "x86_64-linux";
    builder = "/bin/sh";
    args = [ "-c" "echo hello world > $out" ];
  };
  copy = derivation {
    name = "hello-world-copy";
    system = "x86_64-linux";
    builder = "/bin/sh";
    args = [ "-c" "read text < ${hello-world}; echo $text > $out" ];
  };
in
  copy.outPath
```

## Closures

Copy only hello’s directory to another machine, and it won’t even start. GNU
Hello’s program calls into glibc, the C library. It finds glibc through a store
path written right into its files, and that path isn’t there.

The store paths hello points to are its references. `--references` lists them:

```console
$ nix-store --query --references /nix/store/9lmc8ad19psaj2cpwav6a0yzjqlrn00j-hello-2.12.3
/nix/store/znb3q6g1ik34454j3vcjx824h1871asg-glibc-2.42-84
/nix/store/9lmc8ad19psaj2cpwav6a0yzjqlrn00j-hello-2.12.3
```

Hello mentions its own path too, so it shows up in its own references.

Nobody wrote this list by hand. A Debian package carries a list of
the packages it depends on, and apt trusts that list. Nix doesn’t need one.
After every build, it scans the output for store hashes, and every hash it
finds becomes a reference.

References lead to more references. The closure of a path is the path itself
plus everything it refers to, all the way down. `--requisites` lists the whole
closure:

```console
$ nix-store --query --requisites /nix/store/9lmc8ad19psaj2cpwav6a0yzjqlrn00j-hello-2.12.3
/nix/store/39m23yla3lnw563f4a1sa6hnn0dgjyj1-libunistring-1.4.2
/nix/store/8pf3c5kh87gpzyfm8cc3lym5j14npzyw-libidn2-2.3.8
/nix/store/hna4zsz4rdnl4mdbmwmks7cx3cdkkyqc-xgcc-15.3.0-libgcc
/nix/store/znb3q6g1ik34454j3vcjx824h1871asg-glibc-2.42-84
/nix/store/9lmc8ad19psaj2cpwav6a0yzjqlrn00j-hello-2.12.3
```

Glibc brings three more paths of its own, so hello’s closure is five paths.

Hello’s references don’t list libunistring, so how did it get in?
`nix why-depends` shows the path:

```console
$ nix why-depends /nix/store/9lmc8ad19psaj2cpwav6a0yzjqlrn00j-hello-2.12.3 /nix/store/39m23yla3lnw563f4a1sa6hnn0dgjyj1-libunistring-1.4.2
/nix/store/9lmc8ad19psaj2cpwav6a0yzjqlrn00j-hello-2.12.3
└───/nix/store/znb3q6g1ik34454j3vcjx824h1871asg-glibc-2.42-84
    └───/nix/store/8pf3c5kh87gpzyfm8cc3lym5j14npzyw-libidn2-2.3.8
        └───/nix/store/39m23yla3lnw563f4a1sa6hnn0dgjyj1-libunistring-1.4.2
```

The closure is the unit Nix moves around. `nix copy` sends the whole closure to
another machine. Downloading hello from cache.nixos.org makes sure all five paths are
there. The garbage collector keeps the whole closure of everything you still
use.

Meaning the closure is the size you really pay, and it can be more than you’d
expect:

```console
$ du -shc $(nix-store --query --requisites /nix/store/9lmc8ad19psaj2cpwav6a0yzjqlrn00j-hello-2.12.3)
2.0M	/nix/store/39m23yla3lnw563f4a1sa6hnn0dgjyj1-libunistring-1.4.2
412K	/nix/store/8pf3c5kh87gpzyfm8cc3lym5j14npzyw-libidn2-2.3.8
200K	/nix/store/hna4zsz4rdnl4mdbmwmks7cx3cdkkyqc-xgcc-15.3.0-libgcc
35M	/nix/store/znb3q6g1ik34454j3vcjx824h1871asg-glibc-2.42-84
384K	/nix/store/9lmc8ad19psaj2cpwav6a0yzjqlrn00j-hello-2.12.3
38M	total
```

Hello itself takes 384K on this disk, and almost all of its 38M closure is
glibc. The good news is that programs from the same nixpkgs share it. Here’s
coreutils pointing at the very same glibc path:

```console
$ nix-store --query --references /nix/store/833invqvsk7anqnqrki5hqncrcllj825-coreutils-9.11
/nix/store/znb3q6g1ik34454j3vcjx824h1871asg-glibc-2.42-84
/nix/store/61rm1l19wj94b282fmvmqh1pkr56hydr-gmp-with-cxx-6.3.0
/nix/store/lgzpgvflhykqpw82jar8vrs6albwyjfd-acl-2.4.0
/nix/store/rkninrfbgid0pfbrmy992z77yhp0j2ll-attr-2.6.0
/nix/store/833invqvsk7anqnqrki5hqncrcllj825-coreutils-9.11
```

So your store keeps one copy of glibc for all of them.

Your whole NixOS system is one closure too. Here’s how many paths it holds on
one real machine:

```console
$ nix-store --query --requisites /run/current-system | wc -l
3294
```

All 3294 get built, copied and kept together, as one unit.

## Garbage collection

Removing a package doesn’t delete anything from the store. Uninstalling it,
switching to a configuration without it, or leaving a temporary shell only
stops pointing at its path, and the path stays right where it was. That makes
going back to an older setup cheap, and it’s also why the store keeps growing.

Cleaning up is the garbage collector’s job. It starts from
roots, the paths Nix knows are in
use: your profiles, which hold what you installed
along with every earlier version of it, the `result` links `nix-build` leaves
behind, and whatever running programs are using right now. Everything in the
closure of a root stays. Everything else is garbage.

You can see a root at work with the `nix-store --delete` command. It deletes
one path, but only if that path is garbage. Right after building
a tiny derivation called `hello-world`, its `result` link is still in the directory:

```console
$ nix-store --delete /nix/store/kbh84yclhgn33j34j9i4wxha04v79q5f-hello-world
finding garbage collector roots...
0 store paths deleted, 0.0 KiB freed
error: Cannot delete path '/nix/store/kbh84yclhgn33j34j9i4wxha04v79q5f-hello-world' since it is still alive. To find out why, use: nix-store --query --roots and nix-store --query --referrers
```

Nix refuses, because the path is “still alive”: the `result` link is a root
pointing at it. Remove the link, and the same command deletes the path.

To clean up everything at once, run `nix-collect-garbage`. Add `--dry-run`
first, and it only counts what would go. Here it runs on a store where the only
garbage is `hello-world` and the `.drv` file it was built from:

```console
$ nix-collect-garbage --dry-run
finding garbage collector roots...
determining live/dead paths...
2 store paths would be deleted
$ nix-collect-garbage
finding garbage collector roots...
deleting garbage...
deleting '/nix/store/kbh84yclhgn33j34j9i4wxha04v79q5f-hello-world'
deleting '/nix/store/dp5na63mzhc3a2kkiy37b3xq642k7lhy-hello-world.drv'
deleting unused links...
note: hard linking is currently saving 0.0 KiB
2 store paths deleted, 0.3 KiB freed
```

`nix-collect-garbage -d` goes further. It first deletes the old
generations of your profiles, the earlier versions
you could go back to. So whatever only they used becomes garbage too.

Here a profile has four generations. Firefox was installed in generation 2 and
removed in generation 3:

```console
$ nix-env --list-generations
   1   2026-10-13 19:55:10
   2   2026-10-13 19:57:42
   3   2026-10-13 20:00:12
   4   2026-10-13 20:02:43   (current)
$ nix-collect-garbage -d
removing old generations of profile /home/alice/.local/state/nix/profiles/profile
removing profile version 1
removing profile version 2
removing profile version 3
finding garbage collector roots...
…
deleting garbage...
…
deleting '/nix/store/1i8glb8gw744gwpsj5qwpya9qlck4ing-firefox-157.0'
…
deleting unused links...
note: hard linking is currently saving 0.0 KiB
3364 store paths deleted, 1.3 GiB freed
```

The old generations were still holding 1.3 GiB, mostly Firefox
and the libraries it needs. That’s the price of being able to roll back. Once the old generations are gone, so is the way back to them.

`-d` is all or nothing. `--delete-older-than 30d` is the gentler version. It
keeps the generations from the last 30 days, plus the one you were on 30 days
ago, and deletes the rest.

On NixOS, run these with `sudo` to clean up old system generations.
With `sudo`, they only touch root’s profiles and the system’s, not yours. So run
them once more without `sudo` to clean up your own.

NixOS can also run this for you. Set `nix.gc.automatic = true;` in
`configuration.nix`, and the collector runs every night at 03:15. Want it
weekly? Set `nix.gc.dates = "weekly";`. Want it to drop old generations too?
Set `nix.gc.options = "--delete-older-than 30d";`.

## Binary caches

Installing a package from nixpkgs usually means
downloading it, not compiling it, even though every package there is a build
recipe. That works because the hash in a store path comes from the recipe.
So Nix knows the path before it builds anything.

Before building anything, Nix asks a binary cache whether it already has
that exact path. If it does, Nix downloads it as a
substitute and skips the build. The default cache
is `cache.nixos.org`, where the NixOS build farm uploads what it builds from
nixpkgs.

Here’s GNU Hello being installed on a machine that doesn’t have it yet.
`-v` makes `nix build` say what it fetches and builds:

```console
$ nix build -v github:NixOS/nixpkgs/774debe7a0d1b496e35677ad955a1011c6ff74f3#hello
these 5 paths will be fetched (10.8 MiB download, 36.2 MiB unpacked):
  /nix/store/znb3q6g1ik34454j3vcjx824h1871asg-glibc-2.42-84
  /nix/store/9lmc8ad19psaj2cpwav6a0yzjqlrn00j-hello-2.12.3
  /nix/store/8pf3c5kh87gpzyfm8cc3lym5j14npzyw-libidn2-2.3.8
  /nix/store/39m23yla3lnw563f4a1sa6hnn0dgjyj1-libunistring-1.4.2
  /nix/store/hna4zsz4rdnl4mdbmwmks7cx3cdkkyqc-xgcc-15.3.0-libgcc
copying path '/nix/store/hna4zsz4rdnl4mdbmwmks7cx3cdkkyqc-xgcc-15.3.0-libgcc' from 'https://cache.nixos.org'...
copying path '/nix/store/39m23yla3lnw563f4a1sa6hnn0dgjyj1-libunistring-1.4.2' from 'https://cache.nixos.org'...
copying path '/nix/store/8pf3c5kh87gpzyfm8cc3lym5j14npzyw-libidn2-2.3.8' from 'https://cache.nixos.org'...
copying path '/nix/store/znb3q6g1ik34454j3vcjx824h1871asg-glibc-2.42-84' from 'https://cache.nixos.org'...
copying path '/nix/store/9lmc8ad19psaj2cpwav6a0yzjqlrn00j-hello-2.12.3' from 'https://cache.nixos.org'...
```

Nothing got compiled. Every line is a download from
`cache.nixos.org`. When you see `copying path ... from`, the cache had it.

A binary cache is basically just a remote Nix store. Asking it about a path is
a plain web request. The file is named after the hash part of the path, here
the `9lmc8ad...` of hello:

```console
$ curl https://cache.nixos.org/9lmc8ad19psaj2cpwav6a0yzjqlrn00j.narinfo
StorePath: /nix/store/9lmc8ad19psaj2cpwav6a0yzjqlrn00j-hello-2.12.3
URL: nar/1i2wdg3ps36qw4g0nkkl9kwd52grg5kkyb1dyrl56cy99938pgpg.nar.zst
Compression: zstd
FileHash: sha256:1svff7wjsiiwfr35b04zda3dxrjxl69kaqg6ii1ww3rqqrsdaxa8
FileSize: 75356
NarHash: sha256:1i2wdg3ps36qw4g0nkkl9kwd52grg5kkyb1dyrl56cy99938pgpg
NarSize: 279624
References: 9lmc8ad19psaj2cpwav6a0yzjqlrn00j-hello-2.12.3 znb3q6g1ik34454j3vcjx824h1871asg-glibc-2.42-84
Deriver: 5c6c4dzr5fyk9vcrig229yxr9yidbl0c-hello-2.12.3.drv
Sig: cache.nixos.org-1:dp0LpCz6oDqLqmzfcVgy/dJPZi2T+VlujvfJ2LhTjqcY9OAeZB5xVgdscu+C21O2gJiDIJOU19sRjBAjV8IODQ==
```

`URL` is where the packed up hello sits on the cache. `References` lists what
hello needs at run time. Besides hello itself, that’s just glibc.

The `Sig` line at the end is a signature. Nix only accepts a download that a
key it trusts has signed. Otherwise, anyone who answers that web request could
hand you a different hello under the same path. The key of `cache.nixos.org` is
trusted out of the box.

Now take a tiny derivation nobody else has built, and look at its path:

```nix
let
  hello-world = derivation {
    name = "hello-world";
    system = "x86_64-linux";
    builder = "/bin/sh";
    args = [ "-c" "echo hello world > $out" ];
  };
in
  hello-world.outPath
```

Ask the cache about that hash:

```console
$ curl https://cache.nixos.org/kbh84yclhgn33j34j9i4wxha04v79q5f.narinfo
404
```

Nobody built that recipe for the cache, so Nix builds it on your machine.

The same happens when you change a package. Change one compiler flag, and the
hash changes. Meaning there’s nothing to download.

Your own projects can get the same. A CI server builds every commit and
pushes the results to a cache, just like the build farm does for nixpkgs.
Here’s a model of that. Flip what goes into your build, and see if
the cache still has your path:
nixpkgsthe revision your lockfile pinned`774debe``0d9e9b8`sourcethe commit of your own program`v1.0.0``v1.0.0 + 1 patch`build flagswhat the compiler was told to do`default``-O3`systemthe machine it is being built for`x86_64-linux``aarch64-linux`the path you are asking for`/nix/store/59mbpxyx8v9ng5lv70fgq31cphf0sd78-my-program-1.0.0``sw1fd9c``59mbpxy``xfgr0hj`

The cache CI pushed to has this path. Nothing is compiled.

`cache.nixos.org` only has what the build farm builds from nixpkgs. That’s why
many bigger projects run a cache of their own, and their README tells you how
to add it. nix-community, the GitHub organisation behind Home Manager, keeps one
at `https://nix-community.cachix.org`.

To use a cache, Nix needs two things: its URL in `substituters`, and its
public key in `trusted-public-keys`, so it can check the signatures. On NixOS,
both are options in your configuration:

`configuration.nix`:

```nix
{
  nix.settings.substituters = [ "https://nix-community.cachix.org" ];
  nix.settings.trusted-public-keys = [
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
  ];
}
```

Note that these lists add to the defaults instead of replacing them. Meaning
`cache.nixos.org` and its key stay.

Without NixOS, the same two settings go in `/etc/nix/nix.conf`. There they get
an `extra-` in front, which also adds to the list instead of replacing it:

```console
$ tail -n 2 /etc/nix/nix.conf
extra-substituters = https://nix-community.cachix.org
extra-trusted-public-keys = nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=
```

It has to be that file. By default, only trusted users like `root` may add
caches. Put the same lines in your own `~/.config/nix/nix.conf`, and Nix skips
them with a warning:

```console
$ nix build github:NixOS/nixpkgs/774debe7a0d1b496e35677ad955a1011c6ff74f3#hello
warning: ignoring untrusted substituter 'https://nix-community.cachix.org', you are not a trusted user.
Run `man nix.conf` for more information on the `substituters` configuration option.
warning: ignoring the client-specified setting 'trusted-public-keys', because it is a restricted setting and you are not a trusted user
```

### Try it

Change `echo hello world` to `echo hello nix`, and watch the hash in the path change.

```nix
let
  hello-world = derivation {
    name = "hello-world";
    system = "x86_64-linux";
    builder = "/bin/sh";
    args = [ "-c" "echo hello world > $out" ];
  };
in
  hello-world.outPath
```

## Writers

Not every package needs a source tarball and a build. Sometimes all you want
is a small shell script on your PATH, and nixpkgs has
writers for exactly that: functions in `pkgs` that take a name and some text
and turn them into a package.

`pkgs.writeShellScriptBin "name" "text"` puts your text in `bin/name` under a
Bash shebang. `pkgs.writeShellApplication` goes further, and takes a set: the
`name`, the script as `text`, and `runtimeInputs`, the packages whose commands
the script needs. The text is usually an indented string, so it starts at the
left edge no matter how deep your Nix code is.

`default.nix`:

```nix
let
  pkgs = import <nixpkgs> { };
in
pkgs.writeShellApplication {
  name = "greet";
  runtimeInputs = [ pkgs.cowsay ];
  text = ''
    cowsay "hello, $USER"
  '';
}
```

Build it with `-v`, which makes `nix build` say what it builds, and look at the
script it made:

```console
$ nix build -v --file default.nix
this derivation will be built:
  /nix/store/vv4fpjnlymk6n8np9l35sxxryp8gnpsf-greet.drv
this path will be fetched (1.5 MiB download, 7.5 MiB unpacked):
  /nix/store/pi1h33jq236rysv9s5xx3kxb10qwk6fc-ShellCheck-0.11.0
copying path '/nix/store/pi1h33jq236rysv9s5xx3kxb10qwk6fc-ShellCheck-0.11.0' from 'https://cache.nixos.org'...
building '/nix/store/vv4fpjnlymk6n8np9l35sxxryp8gnpsf-greet.drv'...
$ cat result/bin/greet
#!/nix/store/7n1hai8jk6vgc967drgkqi6k7j6ff28q-bash-5.3p9/bin/bash
set -o errexit
set -o nounset
set -o pipefail
export PATH="/nix/store/z2ckzs031y5ckm3b6divw3rrk51c943b-cowsay-3.8.4/bin:$PATH"
cowsay "hello, $USER"
$ ./result/bin/greet
 ______________
< hello, yurii >
 --------------
        \   ^__^
         \  (oo)\_______
            (__)\       )\/\
                ||----w |
                ||     ||
```

The `PATH` line lets cowsay work inside the script even if it isn’t installed
anywhere else. `set -o errexit` stops the script at the first failing command.

`$USER` reached the script untouched, because only `${ }` means
something to Nix inside the string. Everything else is left for Bash.

`writeShellApplication` also checks the script with ShellCheck while building.
Drop the quotes, as `cowsay hello, $USER`, and the build fails before the
script ever runs:

```console
$ nix build -v --file default.nix
this derivation will be built:
  /nix/store/jprby5llv61yx5b95b2snk30nj9x9isr-greet.drv
building '/nix/store/jprby5llv61yx5b95b2snk30nj9x9isr-greet.drv'...
error: Cannot build '/nix/store/jprby5llv61yx5b95b2snk30nj9x9isr-greet.drv'.
       Reason: builder failed with exit code 1.
       Output paths:
         /nix/store/46yv09g955l115zasijyg2c382y24iq0-greet
       Last 10 log lines:
       >
       > In /nix/store/46yv09g955l115zasijyg2c382y24iq0-greet/bin/greet line 8:
       > cowsay hello, $USER
       >               ^---^ SC2086 (info): Double quote to prevent globbing and word splitting.
       >
       > Did you mean:
       > cowsay hello, "$USER"
       >
       > For more information:
       >   https://www.shellcheck.net/wiki/SC2086 -- Double quote to prevent globbing ...
       For full logs, run:
         nix log /nix/store/jprby5llv61yx5b95b2snk30nj9x9isr-greet.drv
```

Without the quotes, Bash would split the value of `$USER` at spaces and expand
any `*` in it. ShellCheck catches slips like that before anyone runs the
script.

## Wrapping programs

Sometimes a program needs a little push before it starts: an extra flag, or an
environment variable telling it where its files are. A wrapper is exactly that.
It’s a tiny script that sits where the program used to be, sets things up, and
then starts the real program.

nixpkgs does this all the time. gifgen is a small shell script that turns a
video into a GIF with ffmpeg. Without ffmpeg on your PATH, it stops with
“Error: gifgen requires ffmpeg to be installed”. So its recipe wraps it:

`gifgen/package.nix`:

```nix
{
  lib,
  stdenv,
  ffmpeg,
  makeWrapper,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "gifgen";
  version = "1.2.0";

  nativeBuildInputs = [
    makeWrapper
  ];

  installPhase = ''
    runHook preInstall
    install -Dm755 gifgen $out/bin/gifgen
    wrapProgram $out/bin/gifgen \
      --prefix PATH : ${lib.makeBinPath [ ffmpeg ]}
    runHook postInstall
  '';
})
```

`lib.makeBinPath [ ffmpeg ]` is ffmpeg’s `bin` directory in the store. So
gifgen finds ffmpeg even on a machine where nobody installed it.

`makeWrapper` goes in `nativeBuildInputs`, because it only runs during the
build. It gives the build a `wrapProgram` command. That’s the whole trick, and
close to 2,000 files in nixpkgs do it.

`--prefix` is one of several things a wrapper can do:

- `--set NAME VALUE` sets an environment variable.

- `--prefix NAME : VALUE` adds to the front of a list like `PATH`. That’s how gifgen finds ffmpeg.

- `--suffix NAME : VALUE` adds to the end.

- `--add-flags` puts extra flags in front of yours.

## Wrapping any package

Wrapping isn’t only for the people who write a recipe. You can wrap any package
that’s already built, without rebuilding it at all.

The trick is `symlinkJoin`. It makes a new package out of
symlinks to the packages in `paths`, and `postBuild`
runs right after. That’s where the wrapping goes.

Here’s a recipe that gives ripgrep a default flag, `--smart-case`. With it, a
lowercase pattern matches any case:

`package.nix`:

```nix
{ symlinkJoin, ripgrep, makeWrapper }:

symlinkJoin {
  name = "ripgrep";
  paths = [ ripgrep ];
  nativeBuildInputs = [ makeWrapper ];
  postBuild = ''
    wrapProgram $out/bin/rg --add-flags "--smart-case"
  '';
}
```

Build it, and look at what `wrapProgram` left in `bin`:

```console
$ nix build --file default.nix
$ cat result/bin/rg
#! /nix/store/7n1hai8jk6vgc967drgkqi6k7j6ff28q-bash-5.3p9/bin/bash -e
exec -a "$0" "/nix/store/sp83if3jqdyqbxl2ar9rgqr84gdiw8ig-ripgrep/bin/.rg-wrapped"  --smart-case "$@"
$ echo "Hello from Nix" > notes.txt
$ ./result/bin/rg hello notes.txt
1:Hello from Nix
```

`wrapProgram` renamed the original `rg` to `.rg-wrapped` and wrote this script
in its place. It runs the real ripgrep with `--smart-case` first and your own
arguments after it, in `"$@"`. Ripgrep itself came from the binary
cache untouched. The only thing built here is the directory of symlinks and the
two-line script.

## Configs inside a wrapper

Most programs read their settings from a dotfile in your home directory, so a
package alone never carries your setup. But many programs also let an
environment variable point at their whole config file. Put that variable in a
wrapper, and your configuration travels with the package, on every machine,
with nothing to put in `~/.config`.

ripgrep is one of them. It reads its flags from the file named in
`RIPGREP_CONFIG_PATH`, one flag per line. So keep a `ripgreprc` next to the
recipe:

```console
$ cat ripgreprc
--smart-case
--hidden
```

Then point the wrapper at it:

`package.nix`:

```nix
{ symlinkJoin, ripgrep, makeWrapper }:

symlinkJoin {
  name = "ripgrep";
  paths = [ ripgrep ];
  nativeBuildInputs = [ makeWrapper ];
  postBuild = ''
    wrapProgram $out/bin/rg --set RIPGREP_CONFIG_PATH ${./ripgreprc}
  '';
}
```

`--hidden` is new here. It makes ripgrep search hidden files too, the ones
whose name starts with a dot. Build it, and the wrapper now sets the variable
before it starts ripgrep:

```console
$ nix build --file default.nix
$ cat result/bin/rg
#! /nix/store/7n1hai8jk6vgc967drgkqi6k7j6ff28q-bash-5.3p9/bin/bash -e
export RIPGREP_CONFIG_PATH='/nix/store/rq0ld36zvij6l12yw72a363j21308x6d-ripgreprc'
exec -a "$0" "/nix/store/xlpcxc7qyn1wd34wrxdq06x261bzllpm-ripgrep/bin/.rg-wrapped"  "$@"
$ rm notes.txt
$ echo "Hello from Nix" > .notes.txt
$ ./result/bin/rg hello
.notes.txt
1:Hello from Nix
$ nix run nixpkgs#ripgrep -- hello
```

`ripgreprc` got its own place in the store. Nix simply copied it there along
with the package, so the wrapper never depends on the directory you built
it in. Plain ripgrep finds nothing, because the file is hidden and its `Hello`
has a capital H.

Put `(pkgs.callPackage ./package.nix { })` in `environment.systemPackages` or
`home.packages` in place of `pkgs.ripgrep`, and every machine searches the same
way.

## nix-wrapper-modules

A wrapped package carries its own configuration, so it works the same on any
machine without dotfiles. Here’s tmux with Ctrl+A as its prefix key and Vim
keys in copy mode, wrapped by hand:

`package.nix`:

```nix
{ symlinkJoin, tmux, makeWrapper, writeText }:

let
  conf = writeText "tmux.conf" ''
    set -g prefix C-a
    set -g mode-keys vi
    bind-key -T copy-mode-vi 'v' send -X begin-selection
    bind-key -T copy-mode-vi 'y' send -X copy-selection-and-cancel
  '';
in
symlinkJoin {
  name = "tmux";
  paths = [ tmux ];
  nativeBuildInputs = [ makeWrapper ];
  postBuild = ''
    wrapProgram $out/bin/tmux --add-flags "-f ${conf}"
  '';
}
```

`symlinkJoin` makes a new package that links to tmux’s files. `wrapProgram`
then swaps its `bin/tmux` for a small script that starts the real tmux with
`-f` and your config.

It works, but look at how much you had to know. You wrote the config in tmux’s
own format. You had to know that tmux takes its config file with `-f`. And the
next program wants it all told differently. Alacritty wants TOML, and takes
its file with `--config-file`.

nix-wrapper-modules does that part for you. It’s a library that builds wrapped
packages with the module system. You set options, the same way you would in
NixOS or Home Manager, and it writes the config file and the wrapper. It also
comes with ready-made wrapper modules for about 60 programs, like tmux,
WezTerm, Alacritty and Neovim. BirdeeHub maintains it under the
nix-community
organisation on GitHub.

Here’s the same tmux again. A wrapper module looks just like a NixOS module:

`tmux.nix`:

```nix
{ wlib, ... }:
{
  imports = [ wlib.wrapperModules.tmux ];
  prefix = "C-a";
  modeKeys = "vi";
  vimVisualKeys = true;
}
```

`wlib` is the library’s own set of functions and modules, and every wrapper
module gets it. This one imports the ready-made tmux module from it, and sets
three of its options.

To turn the module into a package, add the library to your flake’s inputs, and
hand the module to `wrappers.lib.evalPackage`:

`flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    wrappers.url = "github:nix-community/nix-wrapper-modules";
  };

  outputs = { nixpkgs, wrappers, ... }: {
    packages.x86_64-linux.default = wrappers.lib.evalPackage [
      { pkgs = nixpkgs.legacyPackages.x86_64-linux; }
      ./tmux.nix
    ];
  };
}
```

`evalPackage` takes a list of modules. The first one is a tiny module that
only sets `pkgs`, so the wrapper knows where to take tmux from. Run `nix build`, and look at what it
made:

```console
$ cat result/bin/tmux
#!/nix/store/bp3vb652rrh4jnxpnzy33pgwhv6ihr7i-bash-interactive-5.3p9/bin/bash
exec -a "$0" /nix/store/i1g3zgbcw9c0fdmx59k3wznk52lrnzka-tmux-3.6a/bin/tmux -f /nix/store/mw7gcknrl4hnk5ijhhl7w8v6psnf94xb-tmux-3.6a/tmux.conf "$@"
$ grep "set -g prefix\|mode-keys\|copy-mode-vi" result/tmux.conf
set -g prefix C-a
set -g mode-keys   vi
bind-key -T copy-mode-vi 'v' send -X begin-selection
bind-key -T copy-mode-vi 'y' send -X copy-selection-and-cancel
```

The module turned your three options into lines of a `tmux.conf` in the same
package, and the wrapper starts the real tmux with `-f` pointing at that file.
Every option you didn’t set keeps the default the module picked, so the file
has a lot more in it, like `set -g mouse on`.

The result is a regular package, with its config baked in. Run it
with `nix run`, put it in a dev shell, or install it on a machine that has
never seen your dotfiles. It’s the same tmux everywhere.

You can also install it straight from your NixOS configuration. The library’s
flake has a NixOS module for every wrapper. Add `wrappers.nixosModules.tmux` to
your system’s modules, and the same options appear under `wrappers.tmux`:

`flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    wrappers.url = "github:nix-community/nix-wrapper-modules";
  };

  outputs = { nixpkgs, wrappers, ... }: {
    nixosConfigurations.snowflake = nixpkgs.lib.nixosSystem {
      modules = [
        ./configuration.nix
        wrappers.nixosModules.tmux
        ./terminal.nix
      ];
    };
  };
}
```

`terminal.nix`:

```nix
{
  wrappers.tmux = {
    enable = true;
    prefix = "C-a";
    modeKeys = "vi";
    vimVisualKeys = true;
  };
}
```

`enable = true;` puts the wrapped tmux in your system packages. Home Manager
works the same way, with `wrappers.homeModules.tmux`.

### Try it

The tmux module turns mouse support on by default. Turn it off. In `terminal.nix`, add `mouse = false;` inside `wrappers.tmux`.

- Turn the mouse offterminal.nixNixOS moduleA NixOS module.Project filesA file in the example project.

```nix
{
  wrappers.tmux = {
    enable = true;
    prefix = "C-a";
    modeKeys = "vi";
    vimVisualKeys = true;
  };
}
```

