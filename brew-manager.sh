#!/bin/bash
#
# Homebrew Package Manager
# This script manages your Homebrew packages according to a configuration file,
# while being careful not to remove dependencies of other packages.
#

set -e  # Exit on error

# Configuration
CONFIG_DIR="$HOME/.config/brew-manager"
BREW_LIST="$CONFIG_DIR/brews.txt"
CASK_LIST="$CONFIG_DIR/casks.txt"
DEPENDENCY_CACHE="$CONFIG_DIR/dependency_cache.json"
LAST_PACKAGES_STATE="$CONFIG_DIR/last_packages_state.txt"

# Create option for automatic mode
AUTO_REMOVE=false

# Display usage information
display_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -a, --auto      Automatically remove packages not in list without asking"
    echo "  -h, --help      Display this help message"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -a|--auto)
            AUTO_REMOVE=true
            shift
            ;;
        -h|--help)
            display_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            display_usage
            exit 1
            ;;
    esac
done

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Function to update dependency cache
update_dependency_cache() {
    print_header "Updating Dependency Cache"

    # Create an empty JSON object to store dependencies
    echo "{}" > "$DEPENDENCY_CACHE"

    # Get all installed packages
    local ALL_PACKAGES=$(brew list --formula)

    # For each package, check what depends on it and cache the result
    for package in $ALL_PACKAGES; do
        local REQUIRED_BY=$(brew uses --installed --recursive "$package" 2>/dev/null | tr '\n' ',' | sed 's/,$//')

        # Add to cache
        jq --arg pkg "$package" --arg deps "$REQUIRED_BY" \
            '.[$pkg] = $deps' "$DEPENDENCY_CACHE" > "$DEPENDENCY_CACHE.tmp" && \
            mv "$DEPENDENCY_CACHE.tmp" "$DEPENDENCY_CACHE"
    done

    # Do the same for casks
    local ALL_CASKS=$(brew list --cask)

    for cask in $ALL_CASKS; do
        local REQUIRED_BY=$(brew uses --installed --recursive --cask "$cask" 2>/dev/null | tr '\n' ',' | sed 's/,$//')

        # Add to cache
        jq --arg pkg "$cask" --arg deps "$REQUIRED_BY" \
            '.[$pkg] = $deps' "$DEPENDENCY_CACHE" > "$DEPENDENCY_CACHE.tmp" && \
            mv "$DEPENDENCY_CACHE.tmp" "$DEPENDENCY_CACHE"
    done

    print_success "Dependency cache updated"
}

# Function to save current packages state
save_packages_state() {
    # Save current list of installed packages to compare later
    {
        echo "# Brews"
        brew list --formula
        echo "# Casks"
        brew list --cask
    } > "$LAST_PACKAGES_STATE"
}

# Function to check if packages have changed since last run
packages_changed() {
    if [ ! -f "$LAST_PACKAGES_STATE" ]; then
        return 0
    fi

    local current_state=$(mktemp)
    {
        echo "# Brews"
        brew list --formula
        echo "# Casks"
        brew list --cask
    } > "$current_state"

    diff -q "$LAST_PACKAGES_STATE" "$current_state" > /dev/null
    local result=$?
    rm "$current_state"

    return $result # 0 means no difference, 1 means difference
}

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    print_error "Homebrew is not installed! Please install it first."
    echo "Run this command to install Homebrew:"
    echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    print_warning "jq is not installed, which is required for dependency caching"
    echo -n "Would you like to install jq now? [Y/n] "
    read -r answer
    if [[ "$answer" =~ ^[Nn]$ ]]; then
        print_error "Cannot continue without jq. Exiting."
        exit 1
    else
        print_header "Installing jq"
        brew install jq
        print_success "jq installed"
    fi
fi

# Create config directory if it doesn't exist
if [ ! -d "$CONFIG_DIR" ]; then
    mkdir -p "$CONFIG_DIR"
    print_success "Created config directory: $CONFIG_DIR"
fi

# Create example lists if they don't exist
if [ ! -f "$BREW_LIST" ]; then
    echo "# Add your brew packages here (one per line)" > "$BREW_LIST"
    echo "# Lines starting with # are comments" >> "$BREW_LIST"
    echo "git" >> "$BREW_LIST"
    echo "neovim" >> "$BREW_LIST"
    print_success "Created example brew list at: $BREW_LIST"
fi

if [ ! -f "$CASK_LIST" ]; then
    echo "# Add your cask packages here (one per line)" > "$CASK_LIST"
    echo "# Lines starting with # are comments" >> "$CASK_LIST"
    echo "firefox" >> "$CASK_LIST"
    echo "visual-studio-code" >> "$CASK_LIST"
    print_success "Created example cask list at: $CASK_LIST"
fi

# Update Homebrew
print_header "Updating Homebrew"
export HOMEBREW_NO_AUTO_UPDATE=1  # Prevent auto-update during our script
export HOMEBREW_NO_ENV_HINTS=1    # Hide environment hints
brew update
print_success "Homebrew updated"

# Check if dependency cache needs updating
if [ ! -f "$DEPENDENCY_CACHE" ] || packages_changed; then
    update_dependency_cache
else
    print_success "Using existing dependency cache"
fi

# Save current packages state for next run
save_packages_state

# Process brew packages
process_brews() {
    print_header "Processing Brew Packages"

    # Get actual installed packages
    INSTALLED_BREWS=$(brew list --formula | sort)

    # Get desired packages from config file (removing comments and empty lines)
    DESIRED_BREWS=$(grep -v '^#' "$BREW_LIST" | grep -v '^$' | sort)

    # Install missing packages
    for package in $DESIRED_BREWS; do
        # Extract the actual package name if it's from a tap
        if [[ "$package" == *"/"*"/"* ]]; then
            # Format: owner/tap/package
            PACKAGE_NAME=$(echo "$package" | awk -F'/' '{print $3}')
            TAP_PATH=$(echo "$package" | awk -F'/' '{print $1"/"$2}')

            # Make sure the tap is installed
            if ! brew tap | grep -q "^${TAP_PATH}$"; then
                echo "Tapping $TAP_PATH..."
                brew tap "$TAP_PATH"
            fi

            # Check if the package is installed
            if ! brew list --formula | grep -q "^${PACKAGE_NAME}$"; then
                echo "Installing brew: $package"
                brew install "$package" || print_warning "Failed to install $package"
            else
                echo "Already installed: $PACKAGE_NAME (from $TAP_PATH)"
            fi
        else
            # Regular package (not from a tap)
            if ! brew list --formula | grep -q "^${package}$"; then
                echo "Installing brew: $package"
                brew install "$package" || print_warning "Failed to install $package"
            else
                echo "Already installed: $package"
            fi
        fi
    done

    # Check for packages to remove
    for package in $INSTALLED_BREWS; do
        # For installed packages, we need to check if they're in the desired list
        # which might include tap paths, so we need to check if the package name appears at the end of any entry
        if ! echo "$DESIRED_BREWS" | grep -q "/${package}$" && ! echo "$DESIRED_BREWS" | grep -q "^${package}$"; then
            # Check if it's a dependency using our cache
            local REQUIRED_BY=""
            if [ -f "$DEPENDENCY_CACHE" ]; then
                REQUIRED_BY=$(jq -r --arg pkg "$package" '.[$pkg]' "$DEPENDENCY_CACHE")
            fi

            if [[ -n "$REQUIRED_BY" ]]; then
                echo "Skipping $package as it is required by: $REQUIRED_BY"
            else
                if [ "$AUTO_REMOVE" = true ]; then
                    echo "Automatically removing brew: $package"
                    brew uninstall "$package" || print_warning "Failed to remove $package"
                    # Flag that we need to update dependency cache next time
                    touch "$DEPENDENCY_CACHE.needs_update"
                else
                    echo -n "Package $package is installed but not in your list. Remove? [y/N] "
                    read -r answer
                    if [[ "$answer" =~ ^[Yy]$ ]]; then
                        echo "Removing brew: $package"
                        brew uninstall "$package" || print_warning "Failed to remove $package"
                        # Flag that we need to update dependency cache next time
                        touch "$DEPENDENCY_CACHE.needs_update"
                    fi
                fi
            fi
        fi
    done

    # Upgrade all packages that are in the list
    echo "Upgrading brew packages..."
    for package in $DESIRED_BREWS; do
        # Extract the actual package name if it's from a tap
        if [[ "$package" == *"/"*"/"* ]]; then
            PACKAGE_NAME=$(echo "$package" | awk -F'/' '{print $3}')
            if brew list --formula | grep -q "^${PACKAGE_NAME}$"; then
                brew upgrade "$package" 2>/dev/null || echo "No updates available for $PACKAGE_NAME"
            fi
        else
            if brew list --formula | grep -q "^${package}$"; then
                brew upgrade "$package" 2>/dev/null || echo "No updates available for $package"
            fi
        fi
    done
}

# Process cask packages
process_casks() {
    print_header "Processing Cask Packages"

    # Get actual installed casks
    INSTALLED_CASKS=$(brew list --cask | sort)

    # Get desired casks from config file (removing comments and empty lines)
    DESIRED_CASKS=$(grep -v '^#' "$CASK_LIST" | grep -v '^$' | sort)

    # Install missing casks
    for cask in $DESIRED_CASKS; do
        if ! brew list --cask | grep -q "^${cask}$"; then
            echo "Installing cask: $cask"
            brew install --cask "$cask" || print_warning "Failed to install $cask"
        else
            echo "Already installed: $cask"
        fi
    done

    # Check for casks to remove
    for cask in $INSTALLED_CASKS; do
        if ! echo "$DESIRED_CASKS" | grep -q "^${cask}$"; then
            # Check if it's a dependency using our cache
            local REQUIRED_BY=""
            if [ -f "$DEPENDENCY_CACHE" ]; then
                REQUIRED_BY=$(jq -r --arg pkg "$cask" '.[$pkg]' "$DEPENDENCY_CACHE")
            fi

            if [[ -n "$REQUIRED_BY" ]]; then
                echo "Skipping $cask as it is required by: $REQUIRED_BY"
            else
                if [ "$AUTO_REMOVE" = true ]; then
                    echo "Automatically removing cask: $cask"
                    brew uninstall --cask "$cask" || print_warning "Failed to remove $cask"
                    # Flag that we need to update dependency cache next time
                    touch "$DEPENDENCY_CACHE.needs_update"
                else
                    echo -n "Cask $cask is installed but not in your list. Remove? [y/N] "
                    read -r answer
                    if [[ "$answer" =~ ^[Yy]$ ]]; then
                        echo "Removing cask: $cask"
                        brew uninstall --cask "$cask" || print_warning "Failed to remove $cask"
                        # Flag that we need to update dependency cache next time
                        touch "$DEPENDENCY_CACHE.needs_update"
                    fi
                fi
            fi
        fi
    done

    # Upgrade all casks that are in the list
    echo "Upgrading cask packages..."
    for cask in $DESIRED_CASKS; do
        if brew list --cask | grep -q "^${cask}$"; then
            brew upgrade --cask "$cask" 2>/dev/null || echo "No updates available for $cask"
        fi
    done
}

# Cleanup
cleanup() {
    print_header "Cleaning Up"
    brew cleanup

    # Check if we need to update the dependency cache for next run
    if [ -f "$DEPENDENCY_CACHE.needs_update" ]; then
        rm "$DEPENDENCY_CACHE.needs_update"
        update_dependency_cache
    fi

    print_success "Cleanup completed"
}

# Run everything
process_brews
process_casks
cleanup

print_header "All Done!"
echo "Your Homebrew packages have been managed according to your configuration"
echo "Configuration files location:"
echo "- Brews: $BREW_LIST"
echo "- Casks: $CASK_LIST"
