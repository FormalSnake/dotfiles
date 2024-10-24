#!/bin/bash

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "Homebrew is not installed. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH if it's a fresh install
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    echo "Homebrew is already installed."
fi

# Update Homebrew to make sure we're getting the latest packages
brew update

# Install desired packages
PACKAGES=("neovim" "stow" "wezterm" "jandedobbeleer/oh-my-posh/oh-my-posh" "tmux")

for PACKAGE in "${PACKAGES[@]}"; do
    if brew ls --versions "$PACKAGE" >/dev/null; then
        echo "$PACKAGE is already installed."
    else
        echo "Installing $PACKAGE..."
        brew install "$PACKAGE"
    fi
done

# Execute "stow ." in the script's directory
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR"

echo "Running 'stow .' in $SCRIPT_DIR"
stow .

echo "Script finished."
