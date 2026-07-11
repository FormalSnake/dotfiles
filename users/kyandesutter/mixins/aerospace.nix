{ pkgs, ... }:
let
  aerospaceBin = "${pkgs.aerospace}/bin/aerospace";

  workspaceFor = app: ws: {
    "if".app-id = app;
    run = "move-node-to-workspace ${ws}";
  };
in
{
  programs.aerospace = {
    enable = true;
    package = pkgs.aerospace;
    launchd.enable = true;

    settings = {
      accordion-padding = 30;
      after-startup-command = [ ];
      automatically-unhide-macos-hidden-apps = true;
      default-root-container-layout = "tiles";
      default-root-container-orientation = "auto";
      enable-normalization-flatten-containers = true;
      enable-normalization-opposite-orientation-for-nested-containers = true;

      # Keep floating Helium PiP and the Wispr Flow pill on the focused workspace
      exec-on-workspace-change = [
        "/bin/bash"
        "-c"
        ''
          for bundle in net.imput.helium com.electron.wispr-flow; do
            ${aerospaceBin} list-windows --monitor all --app-bundle-id "$bundle" --format '%{window-id} %{window-layout}' | awk '$2 == "floating" { print $1 }' | xargs -I{} ${aerospaceBin} move-node-to-workspace --window-id {} "$AEROSPACE_FOCUSED_WORKSPACE"
          done
        ''
      ];

      on-focus-changed = [ "move-mouse window-lazy-center" ];
      on-focused-monitor-changed = [ "move-mouse monitor-lazy-center" ];

      gaps = {
        inner = { horizontal = 8; vertical = 8; };
        outer = { bottom = 8; left = 8; right = 8; top = 8; };
      };

      key-mapping.preset = "qwerty";

      mode.main.binding = {
        # Vim-style focus (matches the g815 niri SUPER+hjkl)
        alt-h = "focus left";
        alt-j = "focus down";
        alt-k = "focus up";
        alt-l = "focus right";

        # Window management
        alt-q = "close";
        alt-shift-f = "fullscreen";
        alt-v = "layout floating tiling";

        # Vim-style move (matches the g815 niri SUPER+SHIFT+hjkl)
        alt-shift-h = "move left";
        alt-shift-j = "move down";
        alt-shift-k = "move up";
        alt-shift-l = "move right";

        # Resize (matches the g815 niri column-width binds)
        alt-shift-equal = "resize smart +50";
        alt-shift-minus = "resize smart -50";

        # Layout and modes
        alt-shift-s = "mode service";
        alt-shift-tab = "move-workspace-to-monitor --wrap-around next";
        alt-t = "layout tiles horizontal vertical";
        alt-tab = "workspace-back-and-forth";

        shift-alt-cmd-1 = "workspace web";
        shift-alt-cmd-2 = "workspace terminal";
        shift-alt-cmd-3 = "workspace development";
        shift-alt-cmd-4 = "workspace communication";
        shift-alt-cmd-5 = "workspace productivity";
        shift-alt-cmd-6 = "workspace print";
        shift-alt-cmd-7 = "workspace ai";
        shift-alt-cmd-8 = "workspace media";
        shift-alt-cmd-9 = "workspace gaming";

        shift-alt-1 = "move-node-to-workspace web";
        shift-alt-2 = "move-node-to-workspace terminal";
        shift-alt-3 = "move-node-to-workspace development";
        shift-alt-4 = "move-node-to-workspace communication";
        shift-alt-5 = "move-node-to-workspace productivity";
        shift-alt-6 = "move-node-to-workspace print";
        shift-alt-7 = "move-node-to-workspace ai";
        shift-alt-8 = "move-node-to-workspace media";
        shift-alt-9 = "move-node-to-workspace gaming";
      };

      mode.service.binding = {
        alt-shift-h = [ "join-with left" "mode main" ];
        alt-shift-j = [ "join-with down" "mode main" ];
        alt-shift-k = [ "join-with up" "mode main" ];
        alt-shift-l = [ "join-with right" "mode main" ];
        backspace = [ "close-all-windows-but-current" "mode main" ];
        esc = [ "reload-config" "mode main" ];
        f = [ "layout floating tiling" "mode main" ];
        r = [ "flatten-workspace-tree" "mode main" ];
      };

      on-window-detected = [
        (workspaceFor "com.brave.Browser" "web")
        (workspaceFor "com.formalsnake.lynk" "web")
        (workspaceFor "com.mitchellh.ghostty" "terminal")
        (workspaceFor "dev.zed.Zed" "development")
        (workspaceFor "com.tinyspeck.slackmacgui" "communication")
        (workspaceFor "net.whatsapp.WhatsApp" "communication")
        { "if".app-id = "com.apple.MobileSMS"; run = [ "move-node-to-workspace communication" ]; }
        (workspaceFor "notion.id" "productivity")
        (workspaceFor "com.cron.electron" "productivity")
        (workspaceFor "com.figma.Desktop" "productivity")
        (workspaceFor "co.ambercreative.nucleo" "productivity")
        (workspaceFor "es.canarycoders.canarybrowser" "productivity")
        (workspaceFor "com.bambulab.bambu-studio" "print")
        (workspaceFor "com.google.Chrome" "development")
        (workspaceFor "com.google.chrome.for.testing" "development")
        (workspaceFor "com.anthropic.Claude" "ai")
        (workspaceFor "com.anthropic.claudefordesktop" "ai")
        (workspaceFor "ai.perplexity.comet" "ai")
        (workspaceFor "com.apple.Music" "media")
        (workspaceFor "com.apple.TV" "media")
        (workspaceFor "sh.cider.genten.mac" "media")
        (workspaceFor "com.spotify.client" "media")
        (workspaceFor "com.valvesoftware.steam" "gaming")
        (workspaceFor "dev.vencord.vesktop" "gaming")
        (workspaceFor "com.hnc.Discord" "gaming")
        (workspaceFor "org.equicord.equibop" "gaming")
        (workspaceFor "com.nordvpn.macos" "productivity")
        (workspaceFor "com.apple.Notes" "productivity")
        (workspaceFor "com.apple.iCal" "productivity")
        (workspaceFor "dev.warp.Warp-stable" "terminal")
        { "if".app-id = "com.apple.Stickies"; run = [ "layout floating" ]; }
        {
          "if" = {
            app-id = "app.zen-browser.zen";
            window-title-regex-substring = "Picture-in-Picture";
          };
          run = [ "layout floating" ];
        }
        # Helium Picture-in-Picture: always float (kept on the focused workspace by exec-on-workspace-change)
        {
          "if" = {
            app-id = "net.imput.helium";
            window-title-regex-substring = "Scherm-in-scherm|Picture.?in.?Picture";
          };
          run = [ "layout floating" ];
        }
        # Wispr Flow pill: always float, kept on the focused workspace by exec-on-workspace-change
        { "if".app-id = "com.electron.wispr-flow"; run = [ "layout floating" ]; }
        (workspaceFor "net.imput.helium" "web")
        (workspaceFor "md.obsidian" "productivity")
        (workspaceFor "com.automattic.beeper.desktop" "communication")
        (workspaceFor "com.electron.dockerdesktop" "development")
        (workspaceFor "com.github.Electron" "development")
      ];

      workspace-to-monitor-force-assignment = {
        ai = "main";
        development = "main";
        communication = [ "Built-in Retina Display" "main" ];
        print = "main";
        gaming = [ "yam" "MB16QHG" "Built-in Retina Display" ];
        media = [ "Built-in Retina Display" "main" ];
        productivity = "main";
        terminal = "main";
        web = "main";
      };
    };
  };
}
