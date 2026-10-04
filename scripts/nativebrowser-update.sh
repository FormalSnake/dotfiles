#!/usr/bin/env bash
# Pins a NativeBrowser image from `nd package linux` (dist/linux/*.AppImage)
# for modules/nixos/mixins/nativebrowser.nix: adds it to the store and
# rewrites nativebrowser.json. Then rebuild.
set -euo pipefail
img="$(realpath "$1")"
name="$(basename "$img")"
version="$(sed -n 's/^.*-\([0-9][0-9.]*\)\.AppImage$/\1/p' <<<"$name")"
[ -n "$version" ] || { echo "expected <Name>-<version>.AppImage, got $name" >&2; exit 1; }
nix-store --add-fixed sha256 "$img" >/dev/null
hash="$(nix hash file --type sha256 --sri "$img")"
jq -n --arg name "$name" --arg version "$version" --arg hash "$hash" \
  '{name: $name, version: $version, hash: $hash}' \
  >"$(dirname "$0")/../modules/nixos/mixins/nativebrowser.json"
echo "pinned $name $hash"
