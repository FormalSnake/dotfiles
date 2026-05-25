alias r := rebuild
alias b := build
alias u := update
alias ui := update-input
alias c := check

default:
    @just --choose

# Apply the darwin configuration for this host
rebuild *args="":
    sudo darwin-rebuild switch \
      --flake "{{ justfile_directory() }}#macbook" \
      {{ args }}

# Build without activating
build *args="":
    darwin-rebuild build \
      --flake "{{ justfile_directory() }}#macbook" \
      {{ args }}

# First-time bootstrap (when darwin-rebuild isn't on PATH yet)
bootstrap:
    sudo nix run github:nix-darwin/nix-darwin -- switch \
      --flake "{{ justfile_directory() }}#macbook"

# Update all flake inputs
update:
    nix flake update --flake "{{ justfile_directory() }}"

# Update a single flake input
update-input input:
    nix flake update {{ input }} --flake "{{ justfile_directory() }}"

# Sanity-check the flake
check:
    nix flake check "{{ justfile_directory() }}" --no-build

# Show flake outputs
show:
    nix flake show "{{ justfile_directory() }}"

# Garbage-collect older generations
gc:
    sudo nix-collect-garbage --delete-older-than 7d
    nix-collect-garbage --delete-older-than 7d

# Rollback to the previous generation
rollback:
    sudo darwin-rebuild rollback
