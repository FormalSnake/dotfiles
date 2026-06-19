{ inputs, ... }:
{
  imports = [ inputs.catppuccin.homeModules.catppuccin ];

  # Catppuccin is demoted to a static fallback. autoEnable = false stops it from
  # blanket-theming every supported app, so it no longer fights Noctalia's
  # wallpaper-derived dynamic palette (see mixins/noctalia.nix and
  # docs/superpowers/specs/2026-06-19-noctalia-dynamic-theming-design.md). It now
  # only feeds the consumers that explicitly reference `config.catppuccin.*` and
  # genuinely can't be dynamic: SDDM (pre-login), Herdr (build-time theme name),
  # the Neovim pre-palette fallback colourscheme, and macOS jankyborders.
  catppuccin = {
    enable = true;
    autoEnable = false;
    flavor = "mocha";

    # Re-enable Catppuccin explicitly for the terminal/CLI tools that aren't
    # reachable by Noctalia's wallpaper-derived templates (they have no dynamic
    # path), so they keep their Mocha theme instead of silently reverting to
    # uncoloured defaults when autoEnable went false. Ghostty is intentionally
    # absent — it's driven by Noctalia's dynamic "Matugen" theme on Linux and a
    # manual Catppuccin theme on macOS (see mixins/ghostty.nix). Neovim's
    # Catppuccin comes from the catppuccin/nvim plugin in mixins/neovim.nix, not
    # this module.
    bat.enable = true;
    btop.enable = true;
    fzf.enable = true;
    lazygit.enable = true;
    yazi.enable = true;
    fish.enable = true;
    tmux.enable = true;
  };
}
