# Nix basics

## Nix

Nix builds things from a description. You write down what you want, and Nix
makes exactly that.

That’s not how we usually work with a computer. Normally, you perform actions
one by one: install a browser, name the machine, turn on a service. It works
fine, until you get a second machine and have to remember every command you ran.
$$$$` `` `` `Set up

With Nix, you write the result down instead. Here’s that same setup on
NixOS:

`configuration.nix`:

```nix
{
  programs.firefox.enable = true;
  networking.hostName = "workstation";
  services.openssh.enable = true;
}
```

Now the file remembers it all for you. Copy it to a new machine, and you get
the same setup back.
`configuration.nix`` `` `` `Set up

That’s what declarative means. You describe the
result, and Nix works out how to get there.

And it’s not just operating systems. With devenv, you
can set up a development environment for your project the same way:

devenv.nixdevenvA devenv module.

```nix
{
  languages.python.enable = true;
  languages.javascript.enable = true;
  services.postgres.enable = true;
}
```

And with Home Manager, your
dotfiles:

`home.nix`:

```nix
{
  wayland.windowManager.hyprland = {
    enable = true;
    settings.config = {
      general.gaps_out = 20;
      decoration.rounding = 10;
    };
  };
}
```

Different tools, same language. That’s why most roads on this map start with
it.

