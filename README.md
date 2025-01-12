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
Then run the install script
```sh
> ./install.sh
```
Then go to the .config/nix directory
```sh
> cd .config/nix
> darwin-rebuild switch --flake .
```
Yes, it's as easy as that ;)

## What software does this provide configuration for?
Note: this can all be installed using brew!
* Tmux with Tmuxifier 
* Ghostty
* btop
* zsh 
* nvim
* Aerospace 
