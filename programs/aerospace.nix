{...}: {
  programs.aerospace = {
    enable = true;
    userSettings = {
      # Start AeroSpace at login
      start-at-login = true;

      # Commands after login and startup
      after-login-command = [];
      # Uncommented the after-startup-command
      after-startup-command = [
        # "exec-and-forget $HOME/Developer/arrpc/arrpc"
      ];

      # Normalizations
      enable-normalization-flatten-containers = true;
      enable-normalization-opposite-orientation-for-nested-containers = true;

      # Layout settings
      accordion-padding = 30;
      default-root-container-layout = "tiles";
      default-root-container-orientation = "auto";

      # Key mapping preset
      key-mapping.preset = "qwerty";

      # Focus behavior
      on-focused-monitor-changed = ["move-mouse monitor-lazy-center"];
      on-focus-changed = [
        "exec-and-forget osascript -e 'tell application id \"tracesOf.Uebersicht\" to refresh widget id \"simple-bar-index-jsx\"'"
        "move-mouse window-lazy-center"
      ];

      exec-on-workspace-change = [
        "/bin/zsh"
        "-c"
        "/usr/bin/osascript -e \"tell application id \\\"tracesOf.Uebersicht\\\" to refresh widget id \\\"simple-bar-index-jsx\\\"\""
      ];

      # Gaps configuration
      gaps = {
        inner = {
          horizontal = 12;
          vertical = 12;
        };
        outer = {
          left = 12;
          bottom = 12 + 32;
          top = 12;
          right = 12;
        };
      };

      # Key bindings
      mode = {
        main = {
          binding = {
            "alt-period" = "layout tiles horizontal vertical";
            "alt-comma" = "layout accordion horizontal vertical";

            # Focus
            "alt-h" = "focus left";
            "alt-j" = "focus down";
            "alt-k" = "focus up";
            "alt-l" = "focus right";

            # Move
            "alt-shift-h" = "move left";
            "alt-shift-j" = "move down";
            "alt-shift-k" = "move up";
            "alt-shift-l" = "move right";

            # Workspace
            "alt-b" = "workspace B";
            "alt-e" = "workspace E";
            "alt-m" = "workspace M";
            "alt-n" = "workspace N";
            "alt-p" = "workspace P";
            "alt-t" = "workspace T";
            "alt-v" = "workspace V";

            # Move to workspace
            "alt-shift-b" = "move-node-to-workspace B";
            "alt-shift-e" = "move-node-to-workspace E";
            "alt-shift-m" = "move-node-to-workspace M";
            "alt-shift-n" = "move-node-to-workspace N";
            "alt-shift-p" = "move-node-to-workspace P";
            "alt-shift-t" = "move-node-to-workspace T";
            "alt-shift-v" = "move-node-to-workspace V";

            "alt-shift-f" = "fullscreen";

            "alt-tab" = "workspace-back-and-forth";
            "alt-shift-tab" = "move-workspace-to-monitor --wrap-around next";

            "alt-shift-comma" = "mode service";
            "alt-shift-r" = "mode resize";
            #
            # # Resize
            # "minus" = "resize smart -50";
            # "equal" = "resize smart +50";
          };
        };

        resize = {
          binding = {
            "h" = "resize width +50";
            "j" = "resize height -50";
            "k" = "resize height -50";
            "l" = "resize width +50";
            "b" = "balance-sizes";

            "enter" = "mode main";
            "esc" = "mode main";
          };
        };

        service = {
          binding = {
            "esc" = ["reload-config" "mode main"];
            "r" = ["flatten-workspace-tree" "mode main"];
            "f" = ["layout floating tiling" "mode main"];
            "backspace" = ["close-all-windows-but-current" "mode main"];

            "alt-shift-h" = ["join-with left" "mode main"];
            "alt-shift-j" = ["join-with down" "mode main"];
            "alt-shift-k" = ["join-with up" "mode main"];
            "alt-shift-l" = ["join-with right" "mode main"];
          };
        };
      };

      # Window detection rules
      on-window-detected = [
        {
          "if" = {
            app-id = "com.mitchellh.ghostty";
          };
          run = "move-node-to-workspace T";
        }
        {
          "if" = {
            app-id = "dev.zed.Zed";
          };
          run = "move-node-to-workspace T";
        }
        {
          "if" = {
            app-id = "company.thebrowser.Browser";
          };
          run = "move-node-to-workspace B";
        }
        {
          "if" = {
            app-id = "app.zen-browser.zen";
            window-title-regex-substring = "Picture-in-Picture";
          };
          run = ["layout floating"];
        }
        {
          "if" = {
            app-id = "app.zen-browser.zen";
            window-title-regex-substring = "Zen";
          };
          run = "move-node-to-workspace B";
        }
        {
          "if" = {
            app-id = "ea.browser.deta.surf";
          };
          run = "move-node-to-workspace B";
        }
        {
          "if" = {
            app-id = "com.formalsnake.formalsurf";
          };
          run = "move-node-to-workspace B";
        }
        {
          "if" = {
            app-id = "com.github.th-ch.youtube-music";
          };
          run = "move-node-to-workspace M";
        }
        {
          "if" = {
            app-id = "dev.vencord.vesktop";
          };
          run = "move-node-to-workspace M";
        }
        {
          "if" = {
            app-id = "com.apple.iphonesimulator";
          };
          run = "layout floating";
        }
        {
          "if" = {
            app-id = "com.spotify.client";
          };
          run = "move-node-to-workspace M";
        }
        {
          "if" = {
            app-id = "notion.id";
          };
          run = "move-node-to-workspace N";
        }
        {
          "if" = {
            app-id = "com.google.Chrome";
            window-title-regex-substring = "Picture in Picture";
          };
          run = "layout floating";
          check-further-callbacks = true;
        }
        {
          "if" = {
            app-id = "com.brave.Browser";
          };
          run = "move-node-to-workspace B";
        }
        {
          "if" = {
            app-id = "com.google.Chrome";
          };
          run = "move-node-to-workspace B";
        }
        {
          "if" = {
            app-id = "app.legcord.Legcord";
          };
          run = "move-node-to-workspace V";
        }
      ];

      # Monitor assignments
      workspace-to-monitor-force-assignment = {
        B = "main";
        E = "main";
        M = ["secondary" "main"];
        N = "main";
        P = "main";
        T = "main";
        V = ["secondary" "main"];
      };
    };
  };
}
