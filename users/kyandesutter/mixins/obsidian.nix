{ pkgs, ... }:
{
  # Obsidian (unfree — allowUnfree is global in modules/shared/mixins/nix.nix).
  # Vault lives at ~/Notes, synced via Self-hosted LiveSync (CouchDB on the
  # macbook over Tailscale) — see docs/superpowers/specs/2026-07-15-obsidian-livesync-design.md.
  home.packages = [ pkgs.obsidian ];
}
