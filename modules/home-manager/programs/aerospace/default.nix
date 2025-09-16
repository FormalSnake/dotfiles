{
  config,
  pkgs,
  ...
}: {
  programs.aerospace = {
    enable = true;
    userSettings = {
      # Start AeroSpace at login
      start-at-login = true;

      # Normalization settings
      enable-normalization-flatten-containers = true;
      enable-normalization-opposite-orientation-for-nested-containers = true;

      # Accordion layout settings
      accordion-padding = 30;

      # Default root container settings
      default-root-container-layout = "tiles";
      default-root-container-orientation = "auto";

      # Mouse follows focus settings
      on-focused-monitor-changed = ["move-mouse monitor-lazy-center"];
      on-focus-changed = ["move-mouse window-lazy-center"];

      # Automatically unhide macOS hidden apps
      automatically-unhide-macos-hidden-apps = true;

      # Key mapping preset
      key-mapping.preset = "qwerty";

      # Gaps settings
      gaps = {
        inner.horizontal = 16;
        inner.vertical = 16;
        outer.left = 16;
        outer.bottom = 16;
        outer.top = 16;
        outer.right = 16;
      };

      # Main mode bindings
      mode.main.binding = {
        # Window management
        alt-q = "close";
        alt-shift-f = "fullscreen";
        alt-t = "layout tiles horizontal vertical";

        # Focus movement
        alt-h = "focus left";
        alt-j = "focus down";
        alt-k = "focus up";
        alt-l = "focus right";

        # Window movement
        alt-shift-h = "move left";
        alt-shift-j = "move down";
        alt-shift-k = "move up";
        alt-shift-l = "move right";

        # Resize windows
        alt-shift-minus = "resize smart -50";
        alt-shift-equal = "resize smart +50";

        # Workspace management
        ctrl-alt-cmd-1 = "workspace web";
        ctrl-alt-cmd-2 = "workspace terminal";
        ctrl-alt-cmd-3 = "workspace code";
        ctrl-alt-cmd-4 = "workspace communication";
        ctrl-alt-cmd-5 = "workspace productivity";
        ctrl-alt-cmd-6 = "workspace design";
        ctrl-alt-cmd-7 = "workspace ai";
        ctrl-alt-cmd-8 = "workspace media";
        ctrl-alt-cmd-9 = "workspace gaming";

        # Move windows to workspaces
        ctrl-alt-cmd-shift-1 = "move-node-to-workspace web";
        ctrl-alt-cmd-shift-2 = "move-node-to-workspace terminal";
        ctrl-alt-cmd-shift-3 = "move-node-to-workspace code";
        ctrl-alt-cmd-shift-4 = "move-node-to-workspace communication";
        ctrl-alt-cmd-shift-5 = "move-node-to-workspace productivity";
        ctrl-alt-cmd-shift-6 = "move-node-to-workspace design";
        ctrl-alt-cmd-shift-7 = "move-node-to-workspace ai";
        ctrl-alt-cmd-shift-8 = "move-node-to-workspace media";
        ctrl-alt-cmd-shift-9 = "move-node-to-workspace gaming";

        # Workspace navigation
        alt-tab = "workspace-back-and-forth";
        alt-shift-tab = "move-workspace-to-monitor --wrap-around next";

        # Enter service mode
        alt-shift-s = "mode service";
      };

      workspace-to-monitor-force-assignment = {
        "web" = "main";
        "terminal" = "main";
        "code" = "main";
        "productivity" = "main";
        "design" = "main";
        "ai" = "main";
        "media" = ["secondary" "main"];
        "gaming" = ["secondary" "main"];
        "communication" = ["secondary" "main"];
      };

      # Service mode bindings
      mode.service.binding = {
        # Reload config and exit service mode
        esc = ["reload-config" "mode main"];

        # Reset layout
        r = ["flatten-workspace-tree" "mode main"];

        # Toggle floating/tiling layout
        f = ["layout floating tiling" "mode main"];

        # Close all windows but current
        backspace = ["close-all-windows-but-current" "mode main"];

        # Join with adjacent windows
        alt-shift-h = ["join-with left" "mode main"];
        alt-shift-j = ["join-with down" "mode main"];
        alt-shift-k = ["join-with up" "mode main"];
        alt-shift-l = ["join-with right" "mode main"];
      };

      # Window detection rules
      on-window-detected = [
        {
          "if".app-id = "com.brave.Browser";
          run = "move-node-to-workspace web";
        }
        {
          "if".app-id = "com.mitchellh.ghostty";
          run = "move-node-to-workspace terminal";
        }
        {
          "if".app-id = "dev.zed.Zed";
          run = "move-node-to-workspace code";
        }
        {
          "if".app-id = "com.tinyspeck.slackmacgui";
          run = "move-node-to-workspace communication";
        }
        {
          "if".app-id = "net.whatsapp.WhatsApp";
          run = "move-node-to-workspace communication";
        }
        {
          "if".app-id = "com.apple.MobileSMS";
          run = "move-node-to-workspace communication";
        }
        {
          "if".app-id = "notion.id";
          run = "move-node-to-workspace productivity";
        }
        {
          "if".app-id = "com.cron.electron";
          run = "move-node-to-workspace productivity";
        }
        {
          "if".app-id = "com.figma.Desktop";
          run = "move-node-to-workspace design";
        }
        {
          "if".app-id = "com.anthropic.Claude";
          run = "move-node-to-workspace ai";
        }
        {
          "if".app-id = "ai.perplexity.comet";
          run = "move-node-to-workspace web";
        }
        {
          "if".app-id = "com.apple.Music";
          run = "move-node-to-workspace media";
        }
        {
          "if".app-id = "sh.cider.genten.mac";
          run = "move-node-to-workspace media";
        }
        {
          "if".app-id = "com.spotify.client";
          run = "move-node-to-workspace media";
        }
        {
          "if".app-id = "com.valvesoftware.steam";
          run = "move-node-to-workspace gaming";
        }
        {
          "if".app-id = "com.hnc.Discord";
          run = "move-node-to-workspace gaming";
        }
        {
          "if".app-id = "com.nordvpn.macos";
          run = "move-node-to-workspace productivity";
        }
      ];
    };
  };
}
