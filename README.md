![image](https://github.com/FormalSnake/dotfiles/assets/banner-dots.png)
# My dotfiles
This GIT repo contains all of the dotfiles that I mainly use.

## Screenshot
![image](https://github.com/FormalSnake/dotfiles/assets/screenshot.png)

## Requirements
Ensure you have the following installed on your system:

### Brew
```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```
### Git
```sh
brew install git
```
### Stow
```sh
brew install stow
```

## Installation
First, check out the dotfiles repo in your $HOME directory using git
```sh
> git clone https://github.com/FormalSnake/dotfiles/tree/main
> cd dotfiles
```
Then use GNU stow to create the symlinks
```sh
> stow .
```
Yes, it's as easy as that ;)

## What software does this provide configuration for?
Note: this can all be installed using brew!
* TMUX
* Alacritty
* Base16-shell by tinted-theming
* btop
* fish
* nvim
* neofetch
* sketchybar
* skhd
* spicetify (this cannot be installed using brew, check out their [documentation](https://spicetify.app/))
* yabai
* starship prompt
* base16 fuzzy finder also by tinted-theming
