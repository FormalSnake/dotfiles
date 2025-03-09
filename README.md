# Dotfiles
This is my personal dotfiles repository, managed using stow and nix.
It is made for macOS, but because of the nix package manager, it should work on Linux as well.
If you are having any problems, please open an issue.

## Screenshot
![image](https://raw.githubusercontent.com/FormalSnake/dotfiles/main/assets/screenshot.png)

## Requirements
Ensure you have the following installed on your system:

### Nix
```sh
curl -L https://nixos.org/nix/install | sh
```

## Installation
First, check out the dotfiles repo in your $HOME directory using git
```sh
> git clone https://github.com/FormalSnake/dotfiles/tree/main
> cd dotfiles
```
Then, edit these line in flake.nix
```nix
> username = "kyandesutter";

> darwinConfigurations."FormalBook" = nix-darwin.lib.darwinSystem { 
```
Then, edit these lines in home.nix
```nix
> home.username = "kyandesutter";
> home.homeDirectory = "/Users/kyandesutter";

> programs.git = {
>   enable = true;
>   userName = "FormalSnake";
>   userEmail = "kyaniserni@gmail.com";
> };
```
Then rebuild the system using nix-darwin
```sh
> darwin-rebuild switch --flake .
```
Yes, it's as easy as that ;)

## Updating Flakes

To update all flake inputs to their latest versions:

```sh
nix flake update
```

## What software does this provide configuration for?
Note: this can all be installed using brew!
* Tmux 
* Ghostty
* zsh 
* nvim
* Aerospace 
* Spotify using spicetify

## Contributing

Contributions are welcome! If you have improvements or suggestions, please open an issue or submit a pull request.

## License

This repository is licensed under MIT License. Feel free to use, modify, and distribute according to the license terms.
