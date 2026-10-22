# Dev shells

## mkShell

Every project needs its own tools. A Node.js app wants `node` and `npm`, a
script wants Python. Install all of them system-wide and your machine slowly
fills up with tools for projects you finished long ago, while a teammate still
has to guess which ones you used. `pkgs.mkShell` lets the project write its
tools down in Nix instead.

It’s a function from nixpkgs that takes one attribute set. `packages` is a
list of packages whose commands end up on your
`PATH` inside the shell. `shellHook` is shell code that
runs every time you enter. And any attribute `mkShell` doesn’t know, like
`PORT` here, becomes an
environment variable with that value.

`shell.nix`:

```nix
let
  pkgs = import <nixpkgs> { };
in
pkgs.mkShell {
  packages = [ pkgs.nodejs pkgs.python3 ];
  PORT = "3000";
  shellHook = "node --version";
}
```

Meaning inside this shell `node`, `npm` and `python3` just work, `$PORT` is
`3000`, and Node.js prints its version as you enter. Run `nix-shell` in the
directory with this file to step inside, and `exit` to leave. A flake puts the
same `mkShell` call in its `devShells` output instead.

```console
$ nix-shell
v24.21.0
[nix-shell:~/my-project]$ echo $PORT
3000
[nix-shell:~/my-project]$ exit
exit
```

You don’t have to step inside a shell to see what it sets. A shell is a
derivation too, so you can import `shell.nix` in
the repl and read its attributes like any other value:
shell.nixread only

```nix
let
  pkgs = import <nixpkgs> { };
in
pkgs.mkShell {
  packages = [ pkgs.nodejs pkgs.python3 ];
  PORT = "3000";
  shellHook = "node --version";
}
```

```nix
let
  shell = import ./shell.nix;
in
  [ shell.name shell.PORT ]
```

The first value is `"nix-shell"`. That’s the name `mkShell` picks when you
don’t give one.

And `PORT` is just an attribute on it, a plain string. Entering the
shell is what turns it into an environment variable.

Plenty of `shell.nix` files on GitHub write `nativeBuildInputs` where this
one writes `packages`. That’s the older way, and it gives the very same shell:

```nix
let
  newWay = pkgs.mkShell { packages = [ pkgs.nodejs ]; };
  oldWay = pkgs.mkShell { nativeBuildInputs = [ pkgs.nodejs ]; };
in
  [ newWay.nativeBuildInputs oldWay.nativeBuildInputs ]
```

So `mkShell` moves `packages` into `nativeBuildInputs` for you.

Say you want to work on cowsay itself. You’d need every tool its build needs,
and you’d rather not look them up. `inputsFrom` does that for you. Hand it
packages, and the shell gets everything they need to build. cowsay is written
in Perl, so its recipe asks for `perl`, and `perl` shows up in the shell:

`shell.nix`:

```nix
let
  pkgs = import <nixpkgs> { };
in
pkgs.mkShell {
  inputsFrom = [ pkgs.cowsay ];
}
```

```console
$ nix-shell
[nix-shell:~/my-project]$ which perl
/nix/store/myzwgd3ylpl3d8zrl7kl3l97i7zl8mw6-perl-5.42.0/bin/perl
[nix-shell:~/my-project]$ exit
exit
```

### Try it

Here `pkgs` is already loaded for you, and the last line lists the names in `nativeBuildInputs`. Your app needs Python too. Add `pkgs.python3` after `pkgs.nodejs` in `packages`.

```nix
let
  shell = pkgs.mkShell {
    packages = [ pkgs.nodejs ];
  };
in
  map (p: p.pname) shell.nativeBuildInputs
```

## devShells

A project often needs its own tools, like a certain version of Node.js or
Rust. A flake can describe a shell that has them, in
its `devShells` output. `nix develop` is the command that opens it.

Meaning you don’t install anything to work on a project like that. You run
`nix develop`, and the tools are there. nh, a helper for rebuilding NixOS, is
written in Rust. Its flake has a shell with cargo and the rest of its tools.
You can even open it straight from GitHub:

```console
$ nix develop github:nix-community/nh/v4.4.2
$ cargo --version
cargo 1.97.0 (c980f4866 2026-06-30)
```

Every teammate gets this exact cargo. The project’s
flake.lock pins the nixpkgs it comes from.

Your own shell is just a few lines:

`flake.nix`:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in
    {
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = [ pkgs.nodejs ];
      };
    };
}
```

Each shell is a `pkgs.mkShell` call, and `packages` lists what goes in it.
`pkgs` comes from the flake’s `nixpkgs` input.

In this example, the flake offers one shell with Node.js. Look at the path
`devShells.x86_64-linux.default`. First comes the system the shell is for,
here ordinary 64-bit Linux PCs. Then comes the shell’s name, `default`.

`x86_64-linux` appears twice, once in
`legacyPackages.x86_64-linux` and once in `devShells.x86_64-linux`. The
shell’s packages have to be built for the same kind of machine the shell is
for. So a teammate on an Apple Silicon Mac finds no shell here until someone adds one under `aarch64-darwin`.

`nix flake show` lists what a flake offers. This one has a single shell,
`default`, for `x86_64-linux`:

```console
$ nix flake show
warning: Git tree '/tmp/my-app' is dirty
warning: creating lock file "/tmp/my-app/flake.lock":
• Added input 'nixpkgs':
    'github:NixOS/nixpkgs/774debe7a0d1b496e35677ad955a1011c6ff74f3?narHash=sha256-nQyFkMR78WP6PiXKkDW2SjqzLf/spQqjRuxRGSbcV8k%3D' (2026-10-02)
git+file:///tmp/my-app
└───devShells
    └───x86_64-linux
        └───default: development environment 'nix-shell'
```

Run `nix develop` in the flake’s directory, and you’re in that shell:

```console
$ nix develop
warning: Git tree '/tmp/my-app' is dirty
$ node --version
v24.21.0
```

The name `default` is special. It’s the shell `nix develop` picks when you
don’t ask for one by name. A project can offer more next to it, say a second
shell with only the tools its Python scripts need.

### Try it

Copy the three lines of the `default` shell and paste them right below it. In the copy, change `default` to `scripts` and `pkgs.nodejs` to `pkgs.python3`.

- Offer a shell named `scripts`

- Put `pkgs.python3` in itflake.nixFlakeA flake with inputs and outputs.

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in
    {
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = [ pkgs.nodejs ];
      };
    };
}
```

Now `nix flake show` lists both shells:

```console
$ nix flake show
warning: Git tree '/tmp/my-app' is dirty
git+file:///tmp/my-app
└───devShells
    └───x86_64-linux
        ├───default: development environment 'nix-shell'
        └───scripts: development environment 'nix-shell'
```

Plain `nix develop` still gives you Node.js. To pick the other one, add
`.#scripts`. The `.` means this directory, and after `#` comes the shell’s name:

```console
$ nix develop .#scripts
warning: Git tree '/tmp/my-app' is dirty
$ python3 --version
Python 3.13.15
```

## nix develop

`nix develop` puts you in a project’s development shell: a Bash shell with the
tools the project needs on your `PATH`, without
installing any of them system-wide. The project describes that shell in the
`devShells` output of its `flake.nix`, like this one:

`flake.nix`:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in
    {
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = [ pkgs.nodejs ];
        PORT = "3000";
        shellHook = "node --version";
      };

      devShells.x86_64-linux.scripts = pkgs.mkShell {
        packages = [ pkgs.python3 ];
      };
    };
}
```

Here, the `default` shell asks for Node.js, sets `PORT` to `3000`, and runs
`node --version` as its `shellHook` when you enter. The `scripts` shell only
has Python.

Plenty of projects on GitHub ship a `devShells` output like this. You don’t
even have to clone them. Here’s the shell of nh, a helper for NixOS rebuilds,
straight from GitHub:

```console
$ nix develop github:nix-community/nh/v4.4.2
$ cargo --version
cargo 1.97.0 (c980f4866 2026-06-30)
$ exit
exit
```

Inside that shell, you have the same Rust tools nh’s authors build with.

For your own project, run `nix develop` in the project directory. Nix downloads
or builds everything the shell needs, then starts Bash inside it:

```console
$ nix develop
v24.21.0
$ echo $PORT
3000
$ touch notes.txt
$ exit
exit
$ node --version
bash: node: command not found
$ ls
flake.lock  flake.nix  notes.txt
```

The `shellHook` printed the version, and `PORT` is set. After `exit`, you’re
back in your usual shell, and `node` is gone.

And `notes.txt` is still there. The shell isn’t a container. It
only changes your packages and environment variables, so everything you do to
your files stays.

These three open the same shell:

- `nix develop`

- `nix develop .`

- `nix develop .#default`

The `.` is the flake in this directory. The name after `#` picks the shell. With
no name, you get `default`. So to enter `scripts`, put its name after `.#`:

```console
$ nix develop .#scripts
$ python3 --version
Python 3.13.15
$ exit
exit
```

The shell is always Bash. If you live in zsh or fish, run
`nix develop --command zsh`. You get your own shell with the project’s tools.

`--command` works with any command. It runs it inside the shell and comes
straight back:

```console
$ nix develop --command node --version
v24.21.0
v24.21.0
```

The version shows up twice, because `shellHook` runs before your
command too.

When a package fails to build, it helps to run the build one step at a time.
`nix develop` gives you that for any package: the shell its build runs in, with
its compiler and libraries, where each build step is a command:

```console
$ nix develop nixpkgs#hello
$ unpackPhase
unpacking source archive /nix/store/wj7phsmi7ncidl8k00p489krqss7n9sd-hello-2.12.3.tar.gz
source root is hello-2.12.3
setting SOURCE_DATE_EPOCH to timestamp 1773804383 of file "hello-2.12.3/ChangeLog"
$ cd hello-2.12.3
$ configurePhase
…
$ buildPhase
…
$ ./hello
Hello, world!
```

Between any two steps, you can look at the files and see where it goes wrong.

## direnv

Every project has its own tools. You don’t want to type a command to get them
each time you open a terminal there. direnv loads them for you when you `cd`
into the directory.

It hooks into your shell. Whenever you enter a directory
with an `.envrc` file, it loads that directory’s environment into the shell you
already have. Leave the directory, and it unloads it again.

Editors with a direnv plugin, like VS Code and Neovim, load the same
environment. So your language server and formatter come from the project too.

Say a project’s flake offers a shell with Node.js:

`flake.nix`:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in
    {
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = [ pkgs.nodejs ];
      };
    };
}
```

For a flake project, the whole `.envrc` is one line:

```console
$ cat .envrc
use flake
```

`use flake` loads the flake’s `devShells.x86_64-linux.default`, the shell above
with Node.js in it. It also watches `flake.nix` and `flake.lock`. Edit one of
them, and the shell reloads on your next command.

On its own, `use flake` evaluates the flake again every time you enter the
directory. nix-direnv fixes that. It caches the shell and only evaluates the
flake again after you change it.

The easy way to get both is your configuration. On NixOS, one line installs
direnv, hooks it into your shells and turns nix-direnv on as well:

`configuration.nix`:

```nix
{
  programs.direnv.enable = true;
}
```

Home Manager leaves nix-direnv off by default, so there you turn on both:

`home.nix`:

```nix
{
  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;
}
```

Anywhere else, you add the hook yourself. For Bash, that’s the line
`eval "$(direnv hook bash)"` at the end of `~/.bashrc`. `direnv hook zsh` and
`direnv hook fish` print the versions for those shells. Here it runs by hand:

```console
$ eval "$(direnv hook bash)"
$ node --version
bash: node: command not found
$ cd /tmp/my-app
direnv: error /tmp/my-app/.envrc is blocked. Run `direnv allow` to approve its content
$ cat .envrc
use flake
$ direnv allow
direnv: loading /tmp/my-app/.envrc
direnv: using flake
direnv: export +AR +AS +CC +CONFIG_SHELL +CXX +HOST_PATH +IN_NIX_SHELL +LD +NIX_BINTOOLS +NIX_BINTOOLS_WRAPPER_TARGET_HOST_x86_64_unknown_linux_gnu +NIX_BUILD_CORES +NIX_BUILD_TOP +NIX_CC +NIX_CC_WRAPPER_TARGET_HOST_x86_64_unknown_linux_gnu +NIX_CFLAGS_COMPILE +NIX_ENFORCE_NO_NATIVE +NIX_HARDENING_ENABLE +NIX_LDFLAGS +NIX_STORE +NM +OBJCOPY +OBJDUMP +RANLIB +READELF +SIZE +SOURCE_DATE_EPOCH +STRINGS +STRIP +TEMP +TEMPDIR +TMP +TMPDIR +__structuredAttrs +buildInputs +buildPhase +builder +cmakeFlags +configureFlags +depsBuildBuild +depsBuildBuildPropagated +depsBuildTarget +depsBuildTargetPropagated +depsHostHost +depsHostHostPropagated +depsTargetTarget +depsTargetTargetPropagated +doCheck +doInstallCheck +dontAddDisableDepTrack +mesonFlags +name +nativeBuildInputs +out +outputs +patches +phases +preferLocalBuild +propagatedBuildInputs +propagatedNativeBuildInputs +shell +shellHook +stdenv +strictDeps +system ~PATH ~XDG_DATA_DIRS
$ node --version
v24.21.0
$ cd ..
direnv: unloading
$ node --version
bash: node: command not found
```

The long `export` line lists every variable the shell set. Only the `~PATH`
near the end matters here. The `~` means your `PATH` changed.

That’s the whole trick. `node` is there inside the directory and gone outside
it.

Notice how direnv refused the file at first. An `.envrc` can run any command,
and it could come from a repository you just cloned. So you approve it once
with `direnv allow`, and again after every change to it.

## devenv

A `mkShell` gives you the tools, but setting them up is on you. And that often
means knowing how your language works inside.

Take Python. Put `pkgs.python3` in a `mkShell`, and you can’t even install a
library:

```console
$ nix develop
$ pip install requests
bash: pip: command not found
$ python3 -m pip install requests
/nix/store/9r02ykx9y35lf4gk6gc30gnag1y8ncp7-python3-3.13.15/bin/python3: No module named pip
```

To fix it, you need to know how Python finds its libraries. Either you list
them in Nix with `python3.withPackages`, or you make a virtual environment, a
folder in your project that `pip` installs into. That one also needs a
`shellHook` that creates it the first time and turns it on every time you
enter.

Every language has its own quirks like that. devenv knows them for you. Its
Python support alone is about 950 lines of Nix, and it covers over 50
languages. You turn a language on in a file called `devenv.nix`:

devenv.nixdevenvA devenv module.

```nix
{
  languages.python.enable = true;
  languages.python.venv.enable = true;
}
```

`devenv init` starts you off. It writes a `devenv.nix` full of examples, plus
`devenv.yaml` and a `.gitignore`. Put the lines above in `devenv.nix`, and
`devenv shell` takes you inside:

```console
$ devenv shell
✓ Validating lock 5 files                                         785ms
✓ Evaluating bash 392 files                                       435ms
✓ ▸ Configuring shell 2 steps                                     329ms
✓ Loading tasks                                                     2ms
  └ ✓ Evaluating devenv.config.task.config                          1ms
✓ Running tasks                                                    2.0s
  └ ✓ devenv:enterShell                                            16ms
    ├ ✓ devenv:python:virtualenv 4 lines → /tmp/my-site            2.0s
    └ ✓ devenv:files:cleanup                                       11ms
✓ ▸ Configuring shell 1 step                                        1ms
$ pip install requests
Collecting requests
…
Successfully installed certifi-2026.7.22 charset_normalizer-3.5.2 idna-3.20 requests-2.34.2 urllib3-2.8.0
```

The `devenv:python:virtualenv` line is devenv making the virtual environment
for you, in `.devenv/state/venv`.

`devenv.yaml` lists the inputs, like the `inputs` of a flake. The first
`devenv shell` also writes `devenv.lock`, which pins them like a
flake.lock. Commit `devenv.nix`, `devenv.yaml` and `devenv.lock`, and your
teammates get the same shell.

devenv can also run what your project talks to, like a database. PostgreSQL is
one more line:

devenv.nixdevenvA devenv module.

```nix
{
  languages.python.enable = true;
  languages.python.venv.enable = true;
  services.postgres.enable = true;
}
```

`devenv up` starts it and shows how it’s doing. Press Ctrl+C twice to stop it:

```console
$ devenv up
…
✓ Running processes                                               12.1s
  …
  └ ● postgres ready                                              43.6s
      …
      2026-10-13 18:45:06.164 GMT [3012844] LOG:  database system is ready to accept connections
      Exec probe succeeded - process ready
```

The database lives in `.devenv/state/postgres`, inside your project. So every
project keeps its own data.

Leave it running and open the shell in a second terminal. `psql` is there,
and it already knows where the database is:

```console
$ devenv shell
…
$ psql -c "select 1 + 1"
 ?column?
----------
        2
(1 row)
```

### Try it

Your app keeps its sessions in Redis. Turn on `services.redis.enable` below PostgreSQL.

- Turn on Redisdevenv.nixdevenvA devenv module.

```nix
{
  languages.python.enable = true;
  languages.python.venv.enable = true;
  services.postgres.enable = true;
}
```

## Create a devshell for your project

Give a small Node.js project its own tools, without installing Node.js on
the machine.

Takes about 25 minutes.

You’ll:

- try `npm test` and see it fail, because there’s no Node.js

- write a devshell with Node.js in the project’s `flake.nix`

- step in with `nix develop` and get the tests passing

- open a second terminal and see Node.js isn’t there outside the shell

Continues from Put it in Git.

Everything happens in your browser. Nothing gets installed on your computer.

