{ inputs, pkgs, lib, config, ... }:
let
  # Absolute (no ~) — spicetify config and our chmod both need the real path, and
  # ~ does not expand inside config-xpui.ini values.
  # host is x86_64-only
  spotifyPath = "${config.home.homeDirectory}/.local/share/flatpak/app/com.spotify.Client/x86_64/stable/active/files/extra/share/spotify";
  prefsPath = "${config.home.homeDirectory}/.var/app/com.spotify.Client/config/spotify/prefs";

  # Base theme: the official "text" TUI-style theme. Only its user.css is
  # linked — color.ini is rendered per-host by matugen from that machine's own
  # wallpaper palette (the `spicetify` template in mixins/dms.nix), so the
  # layout is shared while the colours stay wallpaper-derived.
  spicetifyThemes = pkgs.fetchFromGitHub {
    owner = "spicetify";
    repo = "spicetify-themes";
    rev = "3508edd96a2adebd6daa78d1f2c9e7367ef693f8";
    hash = "sha256-+yMXfVghkq7qExTioCHvwQ/SRAPhMxci/KQ54pukC10=";
  };
in
{
  # Spotify is installed as a **user** Flatpak (not spicetify-nix, not pkgs.spotify)
  # so spicetify-cli can patch it at runtime for wallpaper-derived dynamic colours.
  # Both pkgs.spotify (Nix store) and a system Flatpak (/var/lib/flatpak) are
  # read-only; a --user Flatpak lives under $HOME so we can chmod its (still
  # read-only OSTree) app tree writable without sudo. DMS's `spicetify` user
  # template (mixins/dms.nix) regenerates Themes/text/color.ini and its
  # post_hook re-applies it. See docs/superpowers/specs/
  # 2026-06-19-noctalia-dynamic-theming-design.md §5 for the full rationale and the
  # known maintenance tax (every Spotify update wipes the injection → re-run
  # `spicetify backup apply`).
  imports = [ inputs.nix-flatpak.homeManagerModules.nix-flatpak ];

  # Per-user Flatpak install. Independent of the NixOS-level services.flatpak
  # (modules/nixos/.../sober.nix) — system and user Flatpak installations coexist,
  # but the flathub remote is a per-registry thing so it's declared again at user
  # level here.
  services.flatpak = {
    enable = true;
    remotes = [
      {
        name = "flathub";
        location = "https://flathub.org/repo/flathub.flatpakrepo";
      }
    ];
    packages = [ "com.spotify.Client" ];
  };

  # spicetify-cli — the CLI patcher (ships bin/spicetify). NOT the spicetify-nix
  # flake (that did build-time injection into the read-only store, which is what
  # we're moving away from to get runtime recolour).
  home.packages = [ pkgs.spicetify-cli ];

  xdg.configFile."spicetify/Themes/text/user.css".source = "${spicetifyThemes}/text/user.css";

  # Defensive: re-assert writability of the OSTree app tree after each rebuild.
  # Flatpak re-deploys a fresh read-only tree on every Spotify update (repointing
  # `active`), which strips this and the injection — so this runs on each
  # activation. Guarded: no-ops cleanly until the Flatpak is installed and Spotify
  # has been launched once (the tree doesn't exist before then). The recurring
  # `spicetify backup apply` after an update still has to be run by hand (it needs
  # Spotify closed) — see the spec.
  home.activation.spicetifyChmod = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -d "${spotifyPath}/Apps" ]; then
      run chmod a+wr "${spotifyPath}" || true
      run chmod a+wr -R "${spotifyPath}/Apps" || true
    fi
  '';

  # Enforce the spicetify settings on every activation. config-xpui.ini can't
  # be a home-manager file — spicetify rewrites it (the [Backup] section) — so
  # it's converged with idempotent `spicetify config` writes instead. This is
  # what makes a fresh host work without hand-editing the ini: absolute paths
  # (a literal `~`/`$HOME` in the ini is NOT expanded by spicetify), the text
  # base theme, and the matugen-rendered colour scheme. The one remaining
  # manual step on a new machine (and after every Spotify update) is
  # `spicetify backup apply` with Spotify closed.
  home.activation.spicetifyConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run env SPICETIFY_CONFIG="${config.xdg.configHome}/spicetify" ${pkgs.spicetify-cli}/bin/spicetify config \
      spotify_path "${spotifyPath}" \
      prefs_path "${prefsPath}" \
      current_theme text \
      color_scheme Matugen \
      inject_css 1 replace_colors 1 overwrite_assets 1
  '';
}
