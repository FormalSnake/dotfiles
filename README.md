![image](https://raw.githubusercontent.com/FormalSnake/dotfiles/main/assets/banner-dots.png)
# My dotfiles
This GIT repo contains all of the dotfiles that I mainly use.
(with some AI sprinkled in)

## Screenshot
![image](https://raw.githubusercontent.com/FormalSnake/dotfiles/main/assets/screenshotnew.webp)

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
* Tmux with Tmuxifier 
* Wezterm 
* btop
* zsh 
* nvim
* Aerospace 
* Oh my posh 
