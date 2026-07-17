{ lib, ... }:
let
  # Each app launches at login via a per-user LaunchAgent.
  # NOTE: these do NOT show up in System Settings → Login Items.
  # After first activation, manually clear any duplicates from
  # System Settings → General → Login Items to avoid double-launching.
  #
  # Launched with `open -g -j`: -g keeps the app out of the foreground and
  # -j launches it hidden, so menu-bar utilities start silently instead of
  # bombarding you with windows on login.
  apps = [
    # aerospace is launched via programs.aerospace.launchd (currently disabled — see users/kyandesutter/mixins/aerospace.nix)
    { id = "omniwm";        path = "/Applications/OmniWM.app"; }
    { id = "nordvpn";       path = "/Applications/NordVPN.app"; }
    { id = "raycast-beta";  path = "/Applications/Raycast Beta.app"; }
    { id = "aldente";       path = "/Applications/AlDente.app"; }
    { id = "orbstack";      path = "/Applications/OrbStack.app"; }
    { id = "betterdisplay"; path = "/Applications/BetterDisplay.app"; }
  ];

  mkLoginAgent = { id, path }:
    lib.nameValuePair "kyan-login-${id}" {
      serviceConfig = {
        Label = "kyan.login.${id}";
        ProgramArguments = [ "/usr/bin/open" "-g" "-j" "-a" path ];
        RunAtLoad = true;
        KeepAlive = false;
      };
    };
in
{
  launchd.user.agents = lib.listToAttrs (map mkLoginAgent apps);
}
