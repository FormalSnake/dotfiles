{ inputs, ... }:
{
  # Messages (github:FormalSnake/messages), the Rust/GPUI iMessage client; the
  # Mac still runs the BlueBubbles server (systems/macbook/homebrew.nix). The
  # module installs the package with its desktop entry and icon. Login autostart
  # stays in mixins/desktop/autostart.nix for the RefuseManualStart pair, and matugen
  # owns ~/.config/messages/theme.json (mixins/desktop/dms.nix), so `theme` stays empty.
  imports = [ inputs.messages.homeModules.default ];

  programs.messages.enable = true;
}
