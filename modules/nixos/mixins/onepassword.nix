{ ... }:
{
  # 1Password on the laptop. The NixOS modules are the correct path: the GUI
  # needs the setuid helper + polkit for system/browser unlock, and the
  # integrated `op` CLI (programs._1password) talks to the desktop app for
  # biometric unlock. Both packages are unfree (allowUnfree already true).
  #
  # NOTE: keep `_1password-cli` OUT of the home profile on Linux — a user-profile
  # `op` would shadow this setuid wrapper and break the GUI integration. It is
  # kept Darwin-only in users/kyandesutter/programs.nix.
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "kyandesutter" ];
  };

  # Trust Helium (a Chromium fork) for the browser-unlock native-messaging
  # integration. 1Password only talks to browsers whose binary name is in its
  # built-in allowlist or this file; Helium isn't recognized, so add it.
  # The Nix wrapper execs .../opt/helium/helium, so the process name is "helium".
  environment.etc."1password/custom_allowed_browsers" = {
    text = "helium";
    mode = "0755";
  };
}
