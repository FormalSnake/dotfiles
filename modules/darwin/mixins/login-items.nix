{ lib, ... }:
let
  # Each app launches at login via a per-user LaunchAgent.
  # NOTE: these do NOT show up in System Settings → Login Items.
  # After first activation, manually clear any duplicates from
  # System Settings → General → Login Items to avoid double-launching.
  apps = [
    { id = "thaw";          path = "/Applications/Thaw.app"; }
    { id = "alcove";        path = "/Applications/Alcove.app"; }
    # aerospace is launched via programs.aerospace.launchd (see users/kyandesutter/mixins/aerospace.nix)
    { id = "notify";        path = "/Applications/Notify.app"; }
    { id = "linearmouse";   path = "/Applications/LinearMouse.app"; }
    { id = "eqmac";         path = "/Applications/eqMac.app"; }
    { id = "nordvpn";       path = "/Applications/NordVPN.app"; }
    { id = "wallper";       path = "/Applications/Wallper.app"; }
    { id = "raycast-beta";  path = "/Applications/Raycast Beta.app"; }
    { id = "aldente";       path = "/Applications/AlDente.app"; }
    { id = "launchos";      path = "/Applications/LaunchOS.app"; }
    { id = "orbstack";      path = "/Applications/OrbStack.app"; }
    { id = "clop";          path = "/Applications/Clop.app"; }
    { id = "figma-agent";   path = "/Users/kyandesutter/Library/Application Support/Figma/FigmaAgent.app"; }
    { id = "klack";         path = "/Applications/Klack.app"; }
    { id = "betterdisplay"; path = "/Applications/BetterDisplay.app"; }
    { id = "mos";           path = "/Applications/Mos.app"; }
  ];

  mkLoginAgent = { id, path }:
    lib.nameValuePair "kyan-login-${id}" {
      serviceConfig = {
        Label = "kyan.login.${id}";
        ProgramArguments = [ "/usr/bin/open" "-a" path ];
        RunAtLoad = true;
        KeepAlive = false;
      };
    };
in
{
  launchd.user.agents = lib.listToAttrs (map mkLoginAgent apps);
}
