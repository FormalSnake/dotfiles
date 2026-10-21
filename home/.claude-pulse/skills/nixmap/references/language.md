# Nix language

## Expressions

An expression is a piece of Nix code that gives back a
value. `1 + 2` is an expression, and its value is `3`:

```nix
1 + 2
```

Nix code is made of nothing but expressions. A number, a string, a list, and
even a whole NixOS configuration file are each one expression. Some are just a
lot bigger than others.

Bigger expressions are built from smaller ones. In `1 + 2 * 3`, the `2 * 3` is
an expression of its own. Nix works it out first, and then adds it to `1`:

```nix
1 + 2 * 3
```

## Numbers

Numbers in Nix look the way you’d write them anywhere. Type one, and you get it
right back:

```nix
42
```

Whole numbers like `42` are called integers. A number with a dot, like `0.5`,
is called a float:

```nix
0.5
```

Numbers can be negative too. Put a minus in front:

```nix
-3
```

### Try it

Put a minus in front of `42`.

```nix
42
```

## Arithmetic

Math in Nix works just like it did in school. We have `+`, `-`, `*` and `/`,
and `*` and `/` go first:

```nix
10 - 4 * 2
```

Want a different order? Wrap a part in parentheses,
and Nix works it out first:

```nix
(10 - 4) * 2
```

Dividing two integers gives back an integer, so the fraction is
simply dropped. Make either number a float, and it stays:

Change `7` to `7.0`, so the result keeps its fraction.

```nix
7 / 2
```

Also put spaces around `/`. Without them, Nix thinks `6/3` is a path to a file,
and gives you that path instead of `2`:

```nix
6/3
```

### Try it

Put spaces around `/`, so Nix divides `6` by `3`.

```nix
6/3
```

## Strings

Some text in double quotes is a staple in any modern programming language.
Strings in Nix for the most part work exactly as you would expect them to:

```nix
"hello"
```

To join strings together, simply put a `+` between them:

```nix
"nix" + "os"
```

Notice that `+` doesn’t add a space for you. If you want one, join it in as a
string of its own:

```nix
"nix" + " " + "os"
```

But what if your text has a double quote inside? Nix thinks the string ends
right before `hi`, so it has no idea what `hi` is:

```nix
"say "hi""
```

To fix that, put a backslash in front of each quote inside. It tells Nix that
this quote is just part of the text:

```nix
"say \"hi\""
```

### Try it

Put escaped quotes around `hi`, so it says `"say \"hi\""`.

```nix
"say hi"
```

## Indented strings

Plenty of Nix code is really text in another language, like a shell script or a
config file. Writing that in a normal string gets messy
fast. To keep your code indented, you end up writing every line break as `\n`:

```nix
"line one\nline two\n"
```

So instead, Nix gives us indented strings. Simply wrap the text in two single
quotes on each end, and the line breaks stay just as you typed them:

```nix
''
  line one
  line two
''
```

That’s the exact same string as above.

And the spaces in front of each line aren’t part of the text. Nix
removes the indentation all the lines share, so you can indent the text along
with your code.

Double quotes need no backslash in there either, which is very handy for
scripts:

```nix
''
  echo "Hello, $USER"
''
```

The repl prints every result as a normal string, so the backslashes come back
in its output.

You’ll see indented strings all over nixpkgs, in pretty much every build script
and config file a package writes.

### Try it

Indent `line two` by two more spaces than `line one`, and see those two spaces stay in the result.

```nix
''
  line one
  line two
''
```

## Booleans

A boolean is simply a yes or a no. Nix writes them as
`true` and `false`, and that’s all there is to it:

```nix
true
```

You’ll see them all over Nix, because almost anything you can switch on or off
takes one. Your NixOS configuration will be full of lines like `enable = true;`.

Notice that both words are lowercase. With a capital letter, Nix doesn’t see a
boolean at all, and goes looking for something called `True` instead:

```nix
True
```

And they go without quotes, because `"true"` is just a string that happens to
spell the word.

### Try it

Switch this `false` to the other boolean.

```nix
false
```

## Comparisons

Is 22 smaller than 1024? Nix answers questions like that with a comparison, and
the answer is always a boolean:

```nix
22 < 1024
```

Nix has all the usual ones: `<`, `<=`, `>`, `>=`, `==` for equal, and `!=` for
not equal. Each side can be any expression, so you can even check your math:

```nix
2 + 2 == 4
```

Numbers compare by their amount, so an integer and a float can be equal:

```nix
1 == 1.0
```

Comparisons don’t chain though. `1 < 2 < 3` looks fine, but Nix stops right at
the second `<`:

```nix
1 < 2 < 3
```

Each comparison takes exactly two sides. To check both, write two comparisons
and join them with `&&`, which means “and”:

```nix
1 < 2 && 2 < 3
```

You’ll mostly use comparisons to make decisions, like picking one setting when a
port is low and another when it’s high.

### Try it

Change `8080` to `80`, so the comparison becomes `true`.

```nix
8080 < 1024
```

## Boolean operators

Sometimes one yes or no isn’t enough. You may want something only when two
switches are both on, or when at least one of them is. For that, Nix has `&&`,
`||` and `!`.

`&&` is “and”, so both sides have to be `true`:

```nix
true && false
```

With `||`, which is “or”, one `true` side is already enough:

```nix
true || false
```

And `!` simply flips the boolean right after it:

```nix
!true
```

Just like `*` goes before `+`, `&&` goes before `||`. So here, Nix works out
`true && false` first, and only then the `||`:

```nix
true || true && false
```

Reading it left to right would have given `false`. So when in doubt, simply
use parentheses.

### Try it

`&&` goes first here, so this is `true`. Add parentheses around `false || true` to make the or go first.

```nix
false && false || true
```

## if … then … else

Unlike most programming languages, you won’t find an `if` statement in Nix. What
it has instead is a similar mechanism, an `if ... then ... else`
expression. It picks one of two values: the one after `then` when the
condition is `true`, and the one after `else` when it’s `false`. Here’s how we
could use it to tell whether a port needs root, since on Linux one below 1024
does by default:

```nix
if 22 < 1024 then "needs root" else "anyone can open it"
```

Remember, the `else` is not optional, because `if` is an expression and has to
give back a value either way. Leave it out, and Nix won’t even read the code:

```nix
if 22 < 1024 then "needs root"
```

And since `if` gives back a value, the `else` can hold another `if`. That’s how
you pick from more than two values, like a battery that’s critical, low or
fine:

```nix
if 15 < 10 then "critical" else if 15 < 30 then "low" else "fine"
```

Nix checks the conditions in order, and stops at the first one that’s `true`.

It’s an expression like any other, so an `if` can sit right inside a
set:

```nix
{
  level = 15;
  status = if 15 < 30 then "low" else "fine";
}
```

### Try it

Change both `15`s to `50`, so neither condition is `true` and Nix falls through to the last `else`.

```nix
if 15 < 10 then "critical" else if 15 < 30 then "low" else "fine"
```

## null

`null` means “nothing here”. It isn’t `0`, an empty string or `false`. It’s
its own thing:

```nix
null
```

You’ll mostly see it in settings nobody has set yet. That’s handy whenever “not
picked yet” has to be different from every real answer. A setting that takes
`true` or `false` can start out as `null`, and Nix knows you simply haven’t
decided.

## Lists

A list in Nix is a bunch of
expressions wrapped in square brackets. Unlike
most languages though, they are separated by spaces, not commas:

```nix
[ 1 2 3 ]
```

A list can hold any value, from numbers and strings to even other lists:

```nix
[ 1 "two" [ 3 4 ] ]
```

You’ll see lists everywhere in Nix, from the packages installed on your system
to the files your configuration pulls in.

Since spaces separate the items, something like `1 + 2` can’t just sit inside a
list:

```nix
[ 1 + 2 ]
```

Simply wrap it in parentheses, and Nix treats it as a single item:

```nix
[ (1 + 2) 4 ]
```

This rule also applies to a whole lot of other expressions, like
function calls,
`if` expressions and even a negative number. So `-3` goes in as `(-3)`:

```nix
[ 1 (-3) ]
```

So when an item is a calculation, a function call, an `if` or a negative number,
wrap it in parentheses.

### Try it

Add `(2 + 2)` to the end of the list, so it counts up to 4.

```nix
[ 1 2 3 ]
```

## Joining lists with ++

Sometimes one list isn’t enough, and you want to glue two of them together.
That’s exactly what `++` is for:

```nix
[ 1 2 ] ++ [ 3 ]
```

The left list comes first, and the right one goes on the
end. You’ll see this a lot when a list is built from a few parts, like the
packages on a machine. Here, their names stand in for them:

```nix
[ "git" "vim" ] ++ [ "steam" ]
```

Both sides have to be lists, even when you only want to add one
item:

```nix
[ 1 2 ] ++ 3
```

So simply wrap that one item in square brackets first, like `[ 3 ]`.

### Try it

The right side is a list holding another list, so `[ 3 ]` lands inside as one item. Remove the inner brackets, so it reads `++ [ 3 ]`.

```nix
[ 1 2 ] ++ [ [ 3 ] ]
```

## Attribute sets

An attribute set is one of the most important
kinds of value in Nix. It holds names and values similar to dictionaries or
hashmaps in other languages and generally looks like
JSON. Each `name = value` pair inside is called an
attribute.

```nix
{ name = "vimjoyer"; age = 22; }
```

Every attribute ends with a semicolon, the last one included. And
when Nix prints a set, it sorts the names, so `age` comes before `name` here even
though we wrote it second.

A value can be anything Nix has, even another set. Here `editor` is a set of
its own, with its own names inside:

```nix
{
  name = "vimjoyer";
  age = 22;
  editor = { name = "neovim"; plugins = 12; };
}
```

Both sets have a `name`, and they don’t clash. Each set keeps its own names.

You’ll meet attribute sets everywhere in Nix. Every `flake.nix` is one, and so
is every package in nixpkgs and many NixOS modules. This set could go straight
into a NixOS configuration. It names the machine and sets its time zone:

```nix
{
  networking = { hostName = "laptop"; };
  time = { timeZone = "Europe/Kyiv"; };
}
```

Sets inside sets can also be written with dots. This is the exact same set as
above, except it got a little more readable:

```nix
{
  networking.hostName = "laptop";
  time.timeZone = "Europe/Kyiv";
}
```

Names can also be written as strings. That comes in handy when a name has a dot
or a space in it:

```nix
{ "hello.txt" = "hi there"; "my laptop" = "yurii"; }
```

### Try it

Add `editor = "neovim";` after `age = 22;`, inside the braces. Then look where Nix puts it in the result.

```nix
{ name = "vimjoyer"; age = 22; }
```

## Selecting attributes

To get a value out of an attribute set, we
simply put a dot and the name after it, just like getting a field from an object
in other programming languages:

```nix
{ name = "laptop"; cores = 8; }.cores
```

And if a set holds another set, just keep adding dots:

```nix
let
  machine = {
    name = "laptop";
    cpu = { cores = 8; };
  };
in
  machine.cpu.cores
```

A name written as a string, like a file name with a dot in it, needs its quotes
here too. Without them, Nix reads `files.hello.txt` as two
steps, and looks for `hello` first:

```nix
let
  files = { "hello.txt" = "hi there"; };
in
  files.hello.txt
```

Wrap the name in quotes, and Nix reads it as one name:

```nix
let
  files = { "hello.txt" = "hi there"; };
in
  files."hello.txt"
```

And no matter how you write it, the name has to match exactly. One letter off, and Nix stops:

```nix
let
  machine = {
    name = "laptop";
    cpu = { cores = 8; };
  };
in
  machine.cpu.cors
```

### Try it

Change the last line to read the GPU's `vendor`.

```nix
let
  machine = {
    name = "laptop";
    cpu = { cores = 8; threads = 16; };
    gpu = { vendor = "amd"; memory = 8; };
  };
in
  machine.name
```

## Fallbacks with or

Selecting an attribute that isn’t there is an error. This laptop has a name,
but nobody wrote down its cores:

```nix
let
  machine = { name = "laptop"; };
in
  machine.cores
```

So instead, put `or` and a fallback after the selection, and Nix simply uses the
fallback:

```nix
let
  machine = { name = "laptop"; };
in
  machine.cores or 4
```

It even works on a longer path. This laptop has no `gpu` at all, and one `or`
still covers the whole thing:

```nix
let
  machine = { name = "laptop"; };
in
  machine.gpu.vendor or "none"
```

You’ll see this all over nixpkgs, wherever a setting may be left out.

Note that `or` only covers a missing attribute. One that’s set to `null` is
still there, so you get `null`:

```nix
let
  machine = { name = "laptop"; cores = null; };
in
  machine.cores or 4
```

### Try it

Add `cores = 8;` after `name = "laptop";`, inside the braces, and the fallback is no longer needed.

```nix
let
  machine = { name = "laptop"; };
in
  machine.cores or 4
```

## Checking with ?

Asking a set for a name it doesn’t have is an error. This `machine` has a
`name`, but no `cores`:

```nix
let
  machine = { name = "laptop"; };
in
  machine.cores
```

`?` lets you ask first. Write the set, a `?` and a name, and you get a
boolean instead of an error:

```nix
let
  machine = { name = "laptop"; };
in
  machine ? cores
```

It follows dots too, so you can check deep inside a set:

```nix
let
  machine = { cpu = { cores = 8; }; };
in
  machine ? cpu.cores
```

You’ll see this check a lot in nixpkgs, whenever a setting can come in two
shapes, like a socket file or a network address.

Note that `?` only checks that the name is there, not what it holds. Even a
name set to `null` still counts.

### Try it

Add `cores = null;` to the set, after `name = "laptop";`.

```nix
let
  machine = { name = "laptop"; };
in
  machine ? cores
```

## Merging sets with //

Sometimes you want a set that’s just like another one, with a small change.
That’s what `//` is for. It merges two
attribute sets into one, and when a name is in
both, the right side wins:

```nix
{ name = "laptop"; cores = 4; } // { cores = 8; }
```

But it only merges the top level. When both sides have a set under the
same name, the right one replaces the left one whole, and `threads` is gone:

```nix
{
  cpu = { cores = 4; threads = 8; };
} // {
  cpu = { cores = 8; };
}
```

In a real `nix repl`, a set inside a set shows up as `{ ... }`. Put `:p` in front
to see all of it.

You’ll meet `//` all over nixpkgs. AppArmor, for example, is split into several
packages. Its PAM package takes the info of the main library and swaps only
the description:

```nix
{
  homepage = "https://apparmor.net/";
  description = "Mandatory access control system - core library";
} // {
  description = "Mandatory access control system - PAM service";
}
```

The homepage comes through untouched, so the other packages never have to
repeat it.

### Try it

The merge drops `threads`. Bring it back: add `threads = 8;` to the `cpu` on the right side, after `cores = 8;`.

```nix
{
  cpu = { cores = 4; threads = 8; };
} // {
  cpu = { cores = 8; };
}
```

## rec

In a normal attribute set, the values cannot reference
each other. `version` exists as an attribute of the set, but not as a
name you can use inside it:

```nix
{
  version = "2.12.3";
  name = "hello-" + version;
}
```

Put `rec` in front of the braces, short for recursive, and every value in the
set can use the other names in it. And just like in `let`, the order doesn’t
matter:

```nix
rec {
  pname = "hello";
  version = "2.12.3";
  name = pname + "-" + version;
}
```

You’ll see exactly this in package files. Plenty of them in nixpkgs still
start with `stdenv.mkDerivation rec {`, so the version is written once and
reused further down.

### Try it

Add `url = "mirror://gnu/hello/" + name + ".tar.gz";` on a new line under the `name` line.

```nix
rec {
  pname = "hello";
  version = "2.12.3";
  name = pname + "-" + version;
}
```

## let … in

Sooner or later, the same value starts showing up in several places. Here the
version of GNU Hello is typed twice:

```nix
{
  name = "hello-2.12.3";
  url = "mirror://gnu/hello/hello-2.12.3.tar.gz";
}
```

Update one and forget the other, and the name no longer matches the download.
So instead, Nix gives us a very convenient
`let ... in` expression. Between `let` and
`in`, we can create as many bindings as we want. It’s like
naming some variables, except these are immutable, so they never change. The
expression after `in` can then use them:

Change `"2.12.3"` to `"2.12.2"`, an older release. Both the name and the address follow.

```nix
let
  version = "2.12.3";
in
{
  name = "hello-" + version;
  url = "mirror://gnu/hello/hello-" + version + ".tar.gz";
}
```

The version is written once now, and the result is the exact same set as
before.

Every binding ends with a semicolon, just like attributes in a set,
but the expression after `in` does not.

Bindings can even use each other, and their order doesn’t matter. Here `name`
is built from two bindings that only come after it:

```nix
let
  name = pname + "-" + version;
  pname = "hello";
  version = "2.12.3";
in
  name
```

And since the bindings only exist inside their own `let`, nothing leaks out
into the rest of your file. Here `tag` tries to use `version` from outside it:

```nix
{
  name = let version = "2.12.3"; in "hello-" + version;
  tag = "v" + version;
}
```

### Try it

Add `file = name + ".tar.gz";` as the first binding. Then change the last line from `name` to `file`.

```nix
let
  name = pname + "-" + version;
  pname = "hello";
  version = "2.12.3";
in
  name
```

## String interpolation

Joining strings with `+` gets noisy as soon as there are a few pieces:

```nix
let
  version = "2.12.3";
in
  "mirror://gnu/hello/hello-" + version + ".tar.gz"
```

So instead, Nix lets us drop a value straight into a string with `${ }`. This is
called interpolation, and the same address now
reads just like the result you want:

```nix
let
  version = "2.12.3";
in
  "mirror://gnu/hello/hello-${version}.tar.gz"
```

That’s the exact same string. GNU Hello’s own recipe in nixpkgs builds
its download link the same way.

Anything inside the braces is an expression, not
just a name:

```nix
"Hello, ${"nix" + "os"}!"
```

But a number can’t go in there as it is:

```nix
let
  port = 8080;
in
  "port ${port}"
```

That’s why you’ll so often see `${toString port}`. `toString` is a function
built into Nix, and it turns the number into a string first:

```nix
let
  port = 8080;
in
  "port ${toString port}"
```

Shell scripts write their variables as `${HOME}` too. To keep a literal `${`
in a string, put a backslash in front of it:

```nix
"\${HOME}"
```

In an indented string, you put `''` in front
of it instead. You’ll see this a lot in nixpkgs, because so much of the code in
there is shell scripts:

```nix
''
  echo ''${HOME}
''
```

The repl prints both with a backslash, because that’s how a normal string
writes it. The text inside is just `${HOME}`.

### Try it

Add `${user}` right after `/home/`, inside the quotes.

```nix
let
  user = "yurii";
in
  "/home/"
```

Add `:${port}` right after `localhost`, inside the quotes, and read the error. Then fix it by changing `port` to `toString port`.

```nix
let
  port = 8080;
in
  "localhost"
```

## with

Typing the same set name over and over gets old fast. Here every port in the
list starts with `ports.`:

```nix
let
  ports = { ssh = 22; http = 80; https = 443; };
in
  [ ports.ssh ports.https ]
```

So instead, `with` lets you skip it. Put `with ports;` in front, and after it `ssh` and
`https` mean `ports.ssh` and `ports.https`:

```nix
let
  ports = { ssh = 22; http = 80; https = 443; };
in
  with ports; [ ssh https ]
```

Same list, less typing. You’ll see it all the time in package lists, where
`with pkgs; [ git htop ]` is just a shorter way to write
`[ pkgs.git pkgs.htop ]`.

`with` never hides a name you already have. Here `let` defines
`ssh` too, so the list starts with `2222`, not `22`:

```nix
let
  ssh = 2222;
  ports = { ssh = 22; http = 80; };
in
  with ports; [ ssh http ]
```

Meaning a name you defined yourself always wins. `with` only fills in the names
that aren’t defined yet.

### Try it

Change `[ ssh https ]` to `[ ssh http https ]`.

```nix
let
  ports = { ssh = 22; http = 80; https = 443; };
in
  with ports; [ ssh https ]
```

Make the list use the `ssh` from `ports`. Delete the line `ssh = 2222;`.

```nix
let
  ssh = 2222;
  ports = { ssh = 22; http = 80; };
in
  with ports; [ ssh http ]
```

## inherit

When you build a set out of values you already named, you end up writing each
name twice:

```nix
let
  pname = "hello";
  version = "2.12.3";
in
{
  pname = pname;
  version = version;
}
```

So instead, `inherit` writes those lines for you. List the names after it, and each one
becomes `name = name;`:

```nix
let
  pname = "hello";
  version = "2.12.3";
in
{
  inherit pname version;
}
```

Same set, written shorter. So if you ever see `inherit inputs;` in a flake, it’s
just `inputs = inputs;`.

You’ll see it all over nixpkgs, very often passing a package’s `pname` and
`version` along to the code that downloads it.

Often the value you want sits inside another set. Put that set in parentheses,
and `inherit` takes the names from there. These two give the same set:

```nix
let
  hello = { pname = "hello"; version = "2.12.3"; };
in
{
  version = hello.version;
}
```

```nix
let
  hello = { pname = "hello"; version = "2.12.3"; };
in
{
  inherit (hello) version;
}
```

`inherit` works in a `let` too. Many NixOS modules pull the
helpers they need out of `lib` with a line like `inherit (lib) mkOption types;`.
Meaning the rest of the module can write `mkOption` instead of `lib.mkOption`.

### Try it

Replace `pname = pname;` with `inherit pname version;`.

```nix
let
  pname = "hello";
  version = "2.12.3";
in
{
  pname = pname;
}
```

Change `inherit (hello) pname;` to `inherit (hello) pname version;`.

```nix
let
  hello = { pname = "hello"; version = "2.12.3"; license = "GPL-3.0-or-later"; };
in
{
  inherit (hello) pname;
}
```

## Functions

Nix is a functional programming language, so functions are at the core of
anything you do with it.

A function is a little machine. Give it a
value, and it gives you a new value.

In most languages, a function has a name, a list of parameters and a body. But
every Nix function is a lambda, just like the ones you may know from other
languages. It has no name and exactly one parameter.
Just write the parameter, a colon, and the body:

```nix
mynumber: 10 + mynumber
```

That lambda thing in the result is how Nix shows a function. The machine exists, but we haven’t
put anything into it yet.

To use it, put a value after it, separated by a space. The
parentheses keep the `5` from becoming part of
the body:

```nix
(mynumber: 10 + mynumber) 5
```

`mynumber` receives `5`, so the body works out to `15`.

But typing the whole function every time would get old quickly. A function is
a value like any other, so we can give our little machine a name with
`let ... in`, then use it as often as we like:

Add `second = addTen 7;` under `first`.

```nix
let
  addTen = mynumber: 10 + mynumber;
in
{
  first = addTen 5;
}
```

Now, about that one parameter. It may sound limiting, but a function can still
take as many inputs as you want. The trick is a function that gives back
another function. `name: version:` may look like two parameters, but what Nix sees is a function with a `name`
parameter, which returns another function with a `version` parameter. So we
simply pass the inputs one after another:

```nix
let
  pkgName = name: version: name + "-" + version;
in
  pkgName "hello" "2.12.3"
```

This trick is called currying, and you’ll see it all
over Nix code.

### Try it

This `double` machine gives back exactly what it gets. Change its body from `x` to `x * 2`, so it lives up to its name.

```nix
let
  double = x: x;
in
  double 21
```

## Multiple arguments

`name: version:` looks like two parameters, but it’s really a function that gives
back another function. That means `pkgName "hello" "2.12.3"` is just
`(pkgName "hello") "2.12.3"`. The first call fills in `name` and hands back a
function, and the second one fills in `version`:

```nix
let
  pkgName = name: version: name + "-" + version;
in
  (pkgName "hello") "2.12.3"
```

So you don’t have to pass every input at once. You can stop early, and
`pkgName "hello"` on its own is a perfectly good value. It’s a function still
waiting for its `version`:

```nix
let
  pkgName = name: version: name + "-" + version;
  hello = pkgName "hello";
in
  [ (hello "2.12.2") (hello "2.12.3") ]
```

This is called partial application. `hello` is simply `pkgName` with the name
already filled in, which lets us reuse a part of our logic without writing a
new function.

You’ll see this shape all over Nix. An overlay, for example, starts with
`final: prev:`, which is exactly this kind of function. So if you ever see a call
that seems to be missing an argument, this is why.

### Try it

This `git` has the wrong name filled in. Change `pkgName "hello"` to `pkgName "git"`.

```nix
let
  pkgName = name: version: name + "-" + version;
  git = pkgName "hello";
in
  git "2.54.0"
```

## Set arguments

A function can take a whole attribute set as its
argument. Here `pkgName` takes a set called `package`, and reads `pname` and
`version` out of it:

```nix
let
  pkgName = package: package.pname + "-" + package.version;
in
  pkgName { pname = "hello"; version = "2.12.3"; }
```

This works, but the problem is that now we have to keep writing `package.`
throughout the body. Worse, anyone who wants to use this function has to read
all of it just to know which names the set needs.

So instead, Nix lets us unpack the set right in the parameter. Write the names
you want in braces, like `{ pname, version }:`, and they’re ready to use in the
body:

```nix
let
  pkgName = { pname, version }: pname + "-" + version;
in
  pkgName { pname = "hello"; version = "2.12.3"; }
```

Same set in, same result out. But now the body is shorter, and anyone who sees
this function for the first time knows exactly how to use it.

Every listed name has to be there. Leave one out, and Nix stops with
`function 'pkgName' called without required argument 'version'`.

The order of the names in the call doesn’t matter, because Nix finds each value
by its name. These two calls give the same result:

```nix
let
  pkgName = { pname, version }: pname + "-" + version;
in
  [
    (pkgName { pname = "git"; version = "2.54.0"; })
    (pkgName { version = "2.54.0"; pname = "git"; })
  ]
```

You’ll see set arguments a lot. Most NixOS modules start with one, and so do
package files in nixpkgs, where the set names everything the package depends
on, like `stdenv` and `fetchurl`.

### Try it

This call leaves out `version`, so Nix stops. Add `version = "2.12.3";` to the set in the call, after `pname = "hello";`.

```nix
let
  pkgName = { pname, version }: pname + "-" + version;
in
  pkgName { pname = "hello"; }
```

## Default arguments

Sometimes a name in a set argument should be optional. Simply write `?` and a
value after it, like `user ? "root"`, and the function uses that value whenever
the call leaves `user` out:

```nix
let
  sshTarget = { host, user ? "root" }: user + "@" + host;
in
  sshTarget { host = "server"; }
```

A name without a default is still required. Leave out `host`, and Nix stops:

```nix
let
  sshTarget = { host, user ? "root" }: user + "@" + host;
in
  sshTarget { user = "yurii"; }
```

Package recipes in nixpkgs use this all the time for optional features.
htop’s recipe, for example, has `withVimKeys ? false`. Meaning htop keeps its
normal keys, unless someone turns the Vim ones on.

### Try it

Add `user = "yurii";` to the set in the call, after `host = "server";`.

```nix
let
  sshTarget = { host, user ? "root" }: user + "@" + host;
in
  sshTarget { host = "server"; }
```

When every name has a default, an empty set is enough. Change `host` in the function to `host ? "localhost"`, then change the call to `sshTarget { }`.

```nix
let
  sshTarget = { host, user ? "root" }: user + "@" + host;
in
  sshTarget { host = "server"; }
```

## Extra arguments with ...

A function with a set argument only accepts the names it lists. Pass it anything
extra, and Nix stops:

```nix
let
  pkgName = { pname, version }: pname + "-" + version;
in
  pkgName {
    pname = "hello";
    version = "2.12.3";
    homepage = "https://www.gnu.org/software/hello/manual/";
  }
```

So instead, add `...` at the end of the list, and the function simply takes any
extra names and ignores them:

```nix
let
  pkgName = { pname, version, ... }: pname + "-" + version;
in
  pkgName {
    pname = "hello";
    version = "2.12.3";
    homepage = "https://www.gnu.org/software/hello/manual/";
  }
```

You’ll see these dots all the time in NixOS. The `configuration.nix` the
graphical installer writes uses `{ config, pkgs, ... }:`, because NixOS calls it
with way more names than it needs.

## Naming arguments with @

In Nix, functions come in two shapes:

A plain single parameter function:

`default.nix`:

```nix
package: package.pname
```

And an unpacked set parameter function:

`default.nix`:

```nix
{ pname, ... }: pname
```

So what if you want both? That’s what the `@`-pattern is for. It unpacks
the argument so you can grab its attributes
quickly, and also gives you the entire set to
pass around:

`default.nix`:

```nix
{ pname, ... }@package: [ pname package ]
```

In this example, `{ pname, ... }` and `package` represent the exact same thing.
`package` is the name of the function parameter,
and `{ pname, ... }` is also that exact same parameter, but destructured so we
can access its attributes.

You’ll see it often with flakes, where `outputs` usually unpacks the inputs to
grab `nixpkgs`, but also names the whole set `inputs@` to pass it on, to
`specialArgs` for example:

`flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs = inputs@{ self, nixpkgs, ... }: {
    nixosConfigurations.snowflake = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [ ./configuration.nix ];
    };
  };
}
```

Interestingly enough, the order in which the parameter and its destructured
version come does not matter, so you could be writing `param@{ attr1 }` or
`{ attr1 }@param`, with any amount of spaces in between.

```nix
(param @ { attr1 }: attr1) { attr1 = "hello"; }
```

### Try it

`package` holds the whole set. Change the body from `pname` to `package.homepage`.

```nix
({ pname, ... }@package: pname) {
  pname = "hello";
  homepage = "https://www.gnu.org/software/hello/manual/";
}
```

Now use both at once. Change the body from `pname` to `[ pname package.homepage ]`.

```nix
(package@{ pname, ... }: pname) {
  pname = "hello";
  homepage = "https://www.gnu.org/software/hello/manual/";
}
```

## builtins

The Nix language itself is tiny. It has no keyword for counting a list or
reading a file. Instead, those jobs are done by functions built right into Nix,
and they all live in one attribute set called
`builtins`.

You reach them just like any other attribute. `builtins.length` counts the
items in a list:

```nix
builtins.length [ "git" "vim" "htop" ]
```

A few of the most common ones, like `toString`, `map` and `import`, are also
there under their short name. Most builtins have no short name though, so
`length` on its own is not found:

```nix
length [ "git" "vim" "htop" ]
```

Sets have their own builtins too. `builtins.attrNames` gives you all the names
in a set as a list:

```nix
builtins.attrNames {
  ssh = 22;
  http = 80;
  https = 443;
}
```

And some builtins do things the language could never do on its own.
`builtins.fromJSON` turns JSON text into a Nix set:

```nix
builtins.fromJSON "{ \"name\": \"my-app\", \"version\": \"1.2.0\" }"
```

nixpkgs uses this all the time, like for reading a package’s download links out
of a `sources.json` file.

Nix comes with over a hundred builtins, so don’t try to learn the list. Just
look one up when you need it. In `nix repl`, type `builtins.` and press Tab to
see them all, or search them on noogle.dev.

### Try it

Swap `builtins.attrNames` for `builtins.attrValues`, which gives the values instead, in the same order.

```nix
builtins.attrNames {
  ssh = 22;
  http = 80;
  https = 443;
}
```

## Types

Every value in Nix has a type. You never write the types
down, Nix simply works them out from the values themselves. `builtins.typeOf`
tells you which one you’ve got:

```nix
[
  (builtins.typeOf 22)
  (builtins.typeOf 2.5)
  (builtins.typeOf "hi")
  (builtins.typeOf true)
  (builtins.typeOf null)
  (builtins.typeOf [ ])
  (builtins.typeOf { })
  (builtins.typeOf (x: x))
]
```

Even functions have a type, and it’s called `"lambda"`. Paths have one
too, `"path"`.

Types still matter, because Nix checks them as it goes. Add a number to a
string, and it stops:

```nix
1 + "a"
```

When you need to check a value yourself, there are yes-or-no versions like
`builtins.isString` and `builtins.isList`.

### Try it

Remove the quotes around `"22"`, so the port becomes a number.

```nix
builtins.isString "22"
```

## map

Nix has no loops. So to do the same thing to every item in a list, we use `map`.
Give it a function and a list, and you get back a new list with the function
applied to each item:

```nix
map (user: "/home/" + user) [ "yurii" "guest" ]
```

The function can be written right there, or have a name. These two give the
exact same list:

```nix
map (x: x * 2) [ 1 2 3 ]
```

```nix
let
  double = x: x * 2;
in
  map double [ 1 2 3 ]
```

The function written in place needs
parentheses. They show Nix where the function ends
and the list begins.

You’ll meet `map` all over NixOS, whenever one setting has to be repeated for a
whole list of things, like users, devices or ports.

### Try it

Put `map toString` in front of the list, so every port turns into a string.

```nix
[ 22 80 443 ]
```

Pull just the names out of these sets. Put `map (user: user.name)` in front of the list.

```nix
[
  { name = "yurii"; shell = "fish"; }
  { name = "guest"; shell = "bash"; }
]
```

## Laziness

Nix is lazy. It doesn’t work out a value when you write
it down, only when something actually asks for it. An expression nothing uses is
never evaluated, so even a broken one, like `1 / 0`, does no harm.

This is what makes nixpkgs usable at all. Its package set is one attribute set
with tens of thousands of names at the top level, and when you ask for `hello`, Nix works
out `hello` and what `hello` needs, not the other packages.

You can see it when `nix eval` or `nix repl` prints a list or a set. Each value
is worked out on its own, so one that fails shows up as `«error: ...»` in its
place, and everything around it still prints.

```nix
let
  hello = "hello-2.12.3";
  broken = 1 / 0;
in
  hello
```

`broken` would fail, but the last line never asks for it.

### Try it

The list asks for `broken`, so it prints an error in its place. Remove `broken` from the list, and leave its binding alone.

```nix
let
  hello = "hello-2.12.3";
  broken = 1 / 0;
in
  [ hello broken ]
```

## throw and assert

Sometimes code should refuse to go on. That’s what `throw` is for. Put it where
a value would go, and when Nix reaches it, it stops right there with your
message:

```nix
throw "port must be at most 65535"
```

Usually it sits in the branch of an `if` that should never be taken. And like
everything in Nix, it only runs once it’s reached. `8080` passes the check, so
the `throw` is never touched:

```nix
let
  port = 8080;
in
  if port > 65535
  then throw "port must be at most 65535"
  else port
```

Make it `70000`, and it is:

```nix
let
  port = 70000;
in
  if port > 65535
  then throw "port must be at most 65535"
  else port
```

nixpkgs uses this for common typos. Write `pkgs.fetchFromGithub` with a small
h, and evaluation stops with `You meant fetchFromGitHub, with a capital H`.

`assert` is a shorter way to write the same check. Instead of the bad case, you
write what has to be true, and you get the value after the `;` when it is:

```nix
let
  port = 8080;
in
  assert port <= 65535; port
```

When it’s not, Nix stops:

```nix
let
  port = 70000;
in
  assert port <= 65535; port
```

With `assert`, you don’t get to write the message. Nix prints the condition the
way it reads it inside, which isn’t very friendly. Meaning `assert` is great for
checks that should never fail, and `throw` is better when a person will read the
message. You’ll see `assert` at the top of package files in nixpkgs, checking
the arguments before anything gets built.

A `throw` can even sit inside a set. Nothing happens until someone asks for
that one name:

```nix
let
  server = {
    port = 8080;
    certificate = throw "no certificate yet";
  };
in
  server.port
```

You still got the port, even though the set has a `throw` in it. That’s
how `aliases.nix` can be full of throws, and the rest of nixpkgs still works.

### Try it

Ask for the certificate instead: change `server.port` to `server.certificate`. It hits the `throw`, so replace `throw "no certificate yet"` with `"cert.pem"`.

```nix
let
  server = {
    port = 8080;
    certificate = throw "no certificate yet";
  };
in
  server.port
```

## Infinite recursion

Laziness lets values refer to each other in any order. The one thing Nix cannot
do is work out a value that needs itself.

The plainest one is a value built from itself. To know `x`, Nix first needs
`x + 1`, and for that it needs `x` again:

```nix
let x = x + 1; in x
```

A circle can also go through two values. `a` needs `b`, and `b` needs `a`
again:

```nix
let a = b; b = a; in a
```

The classic way to get one is `version = version;` inside a `rec` set. It looks
like it copies `version` from the `let` outside, but inside `rec`, the set’s own
names come first. So what Nix sees is a value defined as itself:

```nix
let
  version = "2.12.3";
in
  rec { version = version; }.version
```

Nothing in this set actually needs `rec`. Drop it, and `version` comes from the
`let` outside again:

```nix
let
  version = "2.12.3";
in
  { version = version; }.version
```

You’ll most likely meet this error in NixOS, when a module decides which files
to import based on its own settings. To know its settings, NixOS has to read
every module, but to know which modules to read, it first needs the settings.
Conditional imports and infinite recursion
shows the fix step by step.

### Try it

Keeping `rec` works too, if the outer value gets its own name. Rename the outer `version` in the `let` to `v`. Then change the line in the set to `version = v;`.

```nix
let
  version = "2.12.3";
in
rec {
  pname = "hello";
  version = version;
}
```

## Paths

Files and directories are everywhere in Nix, so it has a separate kind of value
just for them, called paths. A path always has a slash in
it, and goes without quotes:
`default.nix`:

`default.nix`:
```nix
./modules/ssh.nix
```

A path starting with `./` or `../` is relative to the directory of the file it’s
written in. This file lives in `/lesson`, so that’s where `./` starts. Meaning
the path follows the file, not your terminal.

Nix also works out `..` right away, so `modules/..` simply cancels out:
`default.nix`:

`default.nix`:
```nix
./modules/../hosts/laptop.nix
```

Adding a string to a path gives you a longer path:
`default.nix`:

`default.nix`:
```nix
./modules + "/ssh.nix"
```

Note that a path cannot end with a slash. Write `./modules`, not
`./modules/`, or Nix stops:
`default.nix`:

`default.nix`:
```nix
./modules/
```

You’ll meet paths all over NixOS, like the
`imports = [ ./hardware-configuration.nix ];` near the top of your
`configuration.nix`.

### Try it

This file lives in `/lesson`. Change `./` to `../`, so the path starts one directory up.default.nixProject filesA file in the example project.

`default.nix`:
```nix
./hosts/laptop.nix
```

This joins two strings. Remove the quotes around `"/home/yurii"` to make the left side a path, and the result turns into a path too.

```nix
"/home/yurii" + "/nixos-config"
```

## import

One Nix file gets long fast. So you split it into several, and `import` pulls
a file back in.

Every Nix file holds exactly one expression. `import` takes a
path to a file and gives you that expression’s value.
Here `import ./settings.nix` gives back whatever `settings.nix` evaluates to:
settings.nixread only

```nix
{
  port = 3000;
  greeting = "hello";
}
```

`default.nix`:

`default.nix`:
```nix
import ./settings.nix
```

Import a directory, and Nix uses the `default.nix` inside it. These two are the
same thing:
settings/default.nixread only

```nix
{
  port = 3000;
  greeting = "hello";
}
```

`default.nix`:

`default.nix`:
```nix
import ./settings == import ./settings/default.nix
```

An imported file starts fresh. It can’t see the `let` names of
the file that imports it. Here `default.nix` has an `editor`, but
`settings.nix` can’t use it:
settings.nixread only

```nix
{
  tools = [ "git" editor ];
}
```

`default.nix`:

`default.nix`:
```nix
let
  editor = "helix";
in
import ./settings.nix
```

That’s on purpose. A file means the same thing no matter who imports it.

So a file that needs something from outside is usually a
function. It takes what it needs as an argument,
and you call it right after importing it:
settings.nixread only

```nix
editor: {
  tools = [ "git" editor ];
}
```

`default.nix`:

`default.nix`:
```nix
let
  editor = "helix";
in
import ./settings.nix editor
```

Don’t mix it up with `imports`, the list you’ll see in NixOS configs. `imports`
lists modules for NixOS to merge in, while `import` just reads one file and
gives back its value.

nixpkgs is a directory too, and `<nixpkgs>` is the path to the nixpkgs on your
machine. So you can import it like any other file. What comes back is a function
that takes a set of settings, and `{ }` means you want the defaults. Out comes
every package:

```nix
let
  pkgs = import <nixpkgs> { };
in
[ pkgs.hello pkgs.cowsay ]
```

You’ll see this line at the top of countless Nix files.

### Try it

`tools.nix` is a function, and each machine calls it with its own editor. Add a third machine under the server: `desktop = tools "emacs";`.tools.nixread only

```nix
editor: [ "git" editor ]
```

`default.nix`:

`default.nix`:
```nix
let
  tools = import ./tools.nix;
in
{
  laptop = tools "neovim";
  server = tools "vim";
}
```

All three machines share one file. Each call fills in its own editor.

