{
  config,
  pkgs,
  ...
}: {
  programs.zellij = {
    enable = true;
    enableFishIntegration = true;
    
    settings = {
      default_shell = "fish";
      default_mode = "normal";
      mouse_mode = true;
      copy_command = "pbcopy";
      copy_clipboard = "primary";
      
      session_serialization = true;
      pane_viewport_serialization = true;
      scrollback_lines_to_serialize = 1000;
      
      pane_frames = true;
      theme = "catppuccin-mocha";
      
      ui = {
        pane_frames = {
          rounded_corners = true;
          hide_session_name = false;
        };
      };
      
      keybinds = {
        normal = {
          "_children" = [
            {
              bind = {
                "_args" = ["Ctrl b"];
                "_children" = [
                  { SwitchToMode = { "_args" = ["tmux"]; }; }
                ];
              };
            }
          ];
        };
        
        tmux = {
          "_children" = [
            {
              bind = {
                "_args" = ["\""];
                "_children" = [
                  { NewPane = { "_args" = ["Down"]; }; }
                  { SwitchToMode = { "_args" = ["Normal"]; }; }
                ];
              };
            }
            {
              bind = {
                "_args" = ["%"];
                "_children" = [
                  { NewPane = { "_args" = ["Right"]; }; }
                  { SwitchToMode = { "_args" = ["Normal"]; }; }
                ];
              };
            }
            {
              bind = {
                "_args" = ["x"];
                "_children" = [
                  { CloseFocus = {}; }
                  { SwitchToMode = { "_args" = ["Normal"]; }; }
                ];
              };
            }
            {
              bind = {
                "_args" = ["z"];
                "_children" = [
                  { ToggleFocusFullscreen = {}; }
                  { SwitchToMode = { "_args" = ["Normal"]; }; }
                ];
              };
            }
            {
              bind = {
                "_args" = ["c"];
                "_children" = [
                  { NewTab = {}; }
                  { SwitchToMode = { "_args" = ["Normal"]; }; }
                ];
              };
            }
            {
              bind = {
                "_args" = ["&"];
                "_children" = [
                  { CloseTab = {}; }
                  { SwitchToMode = { "_args" = ["Normal"]; }; }
                ];
              };
            }
            {
              bind = {
                "_args" = ["n"];
                "_children" = [
                  { GoToNextTab = {}; }
                  { SwitchToMode = { "_args" = ["Normal"]; }; }
                ];
              };
            }
            {
              bind = {
                "_args" = ["p"];
                "_children" = [
                  { GoToPreviousTab = {}; }
                  { SwitchToMode = { "_args" = ["Normal"]; }; }
                ];
              };
            }
            {
              bind = {
                "_args" = ["h"];
                "_children" = [
                  { MoveFocus = { "_args" = ["Left"]; }; }
                  { SwitchToMode = { "_args" = ["Normal"]; }; }
                ];
              };
            }
            {
              bind = {
                "_args" = ["j"];
                "_children" = [
                  { MoveFocus = { "_args" = ["Down"]; }; }
                  { SwitchToMode = { "_args" = ["Normal"]; }; }
                ];
              };
            }
            {
              bind = {
                "_args" = ["k"];
                "_children" = [
                  { MoveFocus = { "_args" = ["Up"]; }; }
                  { SwitchToMode = { "_args" = ["Normal"]; }; }
                ];
              };
            }
            {
              bind = {
                "_args" = ["l"];
                "_children" = [
                  { MoveFocus = { "_args" = ["Right"]; }; }
                  { SwitchToMode = { "_args" = ["Normal"]; }; }
                ];
              };
            }
            {
              bind = {
                "_args" = ["H"];
                "_children" = [
                  { Resize = { "_args" = ["Increase Left"]; }; }
                ];
              };
            }
            {
              bind = {
                "_args" = ["J"];
                "_children" = [
                  { Resize = { "_args" = ["Increase Down"]; }; }
                ];
              };
            }
            {
              bind = {
                "_args" = ["K"];
                "_children" = [
                  { Resize = { "_args" = ["Increase Up"]; }; }
                ];
              };
            }
            {
              bind = {
                "_args" = ["L"];
                "_children" = [
                  { Resize = { "_args" = ["Increase Right"]; }; }
                ];
              };
            }
            {
              bind = {
                "_args" = ["d"];
                "_children" = [
                  { Detach = {}; }
                ];
              };
            }
            {
              bind = {
                "_args" = ["["];
                "_children" = [
                  { SwitchToMode = { "_args" = ["Scroll"]; }; }
                ];
              };
            }
            {
              bind = {
                "_args" = ["Escape"];
                "_children" = [
                  { SwitchToMode = { "_args" = ["Normal"]; }; }
                ];
              };
            }
            {
              bind = {
                "_args" = ["Ctrl c"];
                "_children" = [
                  { SwitchToMode = { "_args" = ["Normal"]; }; }
                ];
              };
            }
          ];
        };
        
        scroll = {
          "_children" = [
            {
              bind = {
                "_args" = ["j"];
                "_children" = [
                  { ScrollDown = {}; }
                ];
              };
            }
            {
              bind = {
                "_args" = ["k"];
                "_children" = [
                  { ScrollUp = {}; }
                ];
              };
            }
            {
              bind = {
                "_args" = ["d"];
                "_children" = [
                  { HalfPageScrollDown = {}; }
                ];
              };
            }
            {
              bind = {
                "_args" = ["u"];
                "_children" = [
                  { HalfPageScrollUp = {}; }
                ];
              };
            }
            {
              bind = {
                "_args" = ["g"];
                "_children" = [
                  { ScrollToTop = {}; }
                ];
              };
            }
            {
              bind = {
                "_args" = ["G"];
                "_children" = [
                  { ScrollToBottom = {}; }
                ];
              };
            }
            {
              bind = {
                "_args" = ["q"];
                "_children" = [
                  { SwitchToMode = { "_args" = ["Normal"]; }; }
                ];
              };
            }
            {
              bind = {
                "_args" = ["Escape"];
                "_children" = [
                  { SwitchToMode = { "_args" = ["Normal"]; }; }
                ];
              };
            }
          ];
        };
        
        search = {
          "_children" = [
            {
              bind = {
                "_args" = ["j"];
                "_children" = [
                  { Search = { "_args" = ["down"]; }; }
                ];
              };
            }
            {
              bind = {
                "_args" = ["k"];
                "_children" = [
                  { Search = { "_args" = ["up"]; }; }
                ];
              };
            }
            {
              bind = {
                "_args" = ["n"];
                "_children" = [
                  { Search = { "_args" = ["down"]; }; }
                ];
              };
            }
            {
              bind = {
                "_args" = ["N"];
                "_children" = [
                  { Search = { "_args" = ["up"]; }; }
                ];
              };
            }
          ];
        };
      };
    };
  };
  
  home.shellAliases = {
    zj = "zellij";
    zja = "zellij attach";
    zjl = "zellij list-sessions";
    zjk = "zellij kill-session";
  };
}