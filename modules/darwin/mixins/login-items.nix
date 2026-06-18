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
  # Several entries below are commented out to lighten this dev host. Each is
  # kept in place — uncomment to restore that app's launch-at-login behavior.
  apps = [
    # { id = "thaw";          path = "/Applications/Thaw.app"; }
    # { id = "alcove";        path = "/Applications/Alcove.app"; }
    # aerospace is launched via programs.aerospace.launchd (currently disabled — see users/kyandesutter/mixins/aerospace.nix)
    # { id = "notify";        path = "/Applications/Notify.app"; }
    { id = "linearmouse";   path = "/Applications/LinearMouse.app"; }
    # { id = "eqmac";         path = "/Applications/eqMac.app"; }
    { id = "nordvpn";       path = "/Applications/NordVPN.app"; }
    # { id = "wallper";       path = "/Applications/Wallper.app"; }
    { id = "raycast-beta";  path = "/Applications/Raycast Beta.app"; }
    { id = "aldente";       path = "/Applications/AlDente.app"; }
    # { id = "launchos";      path = "/Applications/LaunchOS.app"; }
    { id = "orbstack";      path = "/Applications/OrbStack.app"; }
    # { id = "clop";          path = "/Applications/Clop.app"; }
    # { id = "figma-agent";   path = "/Users/kyandesutter/Library/Application Support/Figma/FigmaAgent.app"; }
    # { id = "klack";         path = "/Applications/Klack.app"; }
    { id = "betterdisplay"; path = "/Applications/BetterDisplay.app"; }
    { id = "mos";           path = "/Applications/Mos.app"; }
    # { id = "wispr-flow";    path = "/Applications/Wispr Flow.app"; }
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
