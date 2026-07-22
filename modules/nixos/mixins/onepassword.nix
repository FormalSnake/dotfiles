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

  # The NixOS module creates the `onepassword` / `onepassword-cli` groups (which
  # own the setgid BrowserSupport helper and the `op` wrapper) but does NOT add
  # anyone to them. Without `onepassword` membership the browser-integration
  # helper can't verify the browser — so Helium isn't trusted and the unlocked
  # session can't be held, making 1Password appear to lock itself at random.
  # `onepassword-cli` is the matching membership for biometric `op` unlock.
  users.users.kyandesutter.extraGroups = [
    "onepassword"
    "onepassword-cli"
  ];

  # Trust Helium (a Chromium fork) and Zen (a Firefox fork) for the
  # browser-unlock native-messaging integration. 1Password only talks to
  # browsers whose binary name is in its built-in allowlist or this file.
  # Helium's Nix wrapper execs .../opt/helium/helium, so its process name is
  # "helium"; Zen's beta wrapper (mixins/zen.nix) execs the hidden
  # .zen-beta-wrapped binary (verified via /proc/<pid>/comm).
  environment.etc."1password/custom_allowed_browsers" = {
    text = ''
      helium
      .zen-beta-wrapped
    '';
    mode = "0755";
  };
}
