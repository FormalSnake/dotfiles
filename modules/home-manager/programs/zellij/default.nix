{
  config,
  pkgs,
  ...
}: {
  programs.zellij = {
    enable = true;
    settings = {
      # Default mode and keybindings
      default_mode = "normal";
      mouse_mode = true;
      copy_command = "pbcopy"; # macOS clipboard
      copy_clipboard = "primary";
      
      # Session options similar to tmux
      session_serialization = true;
      pane_viewport_serialization = true;
      scrollback_lines_to_serialize = 1000;
      
      # UI configuration
      default_layout = "default";
      default_shell = "fish";
      pane_frames = true;
      theme = "catppuccin-mocha";
      
      # Simplified status bar
      ui = {
        pane_frames = {
          rounded_corners = true;
          hide_session_name = false;
        };
      };
      
      # Keybindings similar to tmux
      keybinds = {
        normal = {
          # Session management
          "bind \"Ctrl b\"" = { SwitchToMode = "tmux"; };
        };
        tmux = {
          # Pane management (similar to tmux)
          "bind \"\\\"\"" = { NewPane = "Down"; SwitchToMode = "Normal"; };
          "bind \"%\"" = { NewPane = "Right"; SwitchToMode = "Normal"; };
          "bind \"x\"" = { CloseFocus = true; SwitchToMode = "Normal"; };
          "bind \"z\"" = { ToggleFocusFullscreen = true; SwitchToMode = "Normal"; };
          
          # Window/Tab management
          "bind \"c\"" = { NewTab = {}; SwitchToMode = "Normal"; };
          "bind \"&\"" = { CloseTab = true; SwitchToMode = "Normal"; };
          "bind \"n\"" = { GoToNextTab = {}; SwitchToMode = "Normal"; };
          "bind \"p\"" = { GoToPreviousTab = {}; SwitchToMode = "Normal"; };
          
          # Vim-like pane navigation
          "bind \"h\"" = { MoveFocus = "Left"; SwitchToMode = "Normal"; };
          "bind \"j\"" = { MoveFocus = "Down"; SwitchToMode = "Normal"; };
          "bind \"k\"" = { MoveFocus = "Up"; SwitchToMode = "Normal"; };
          "bind \"l\"" = { MoveFocus = "Right"; SwitchToMode = "Normal"; };
          
          # Pane resizing
          "bind \"H\"" = { Resize = "Increase Left"; };
          "bind \"J\"" = { Resize = "Increase Down"; };
          "bind \"K\"" = { Resize = "Increase Up"; };
          "bind \"L\"" = { Resize = "Increase Right"; };
          
          # Session management
          "bind \"d\"" = { Detach = {}; };
          "bind \"s\"" = { LaunchOrFocusPlugin = { _args = ["session-manager"]; floating = true; }; SwitchToMode = "Normal"; };
          
          # Copy mode (vi-like)
          "bind \"[\"" = { SwitchToMode = "EnterSearch"; SearchDirection = "Up"; };
          
          # Exit tmux mode
          "bind \"Escape\"" = { SwitchToMode = "Normal"; };
          "bind \"Ctrl c\"" = { SwitchToMode = "Normal"; };
        };
        
        # Enhanced search mode with vi keybindings
        search = {
          "bind \"j\"" = { Search = "down"; };
          "bind \"k\"" = { Search = "up"; };
          "bind \"n\"" = { Search = "down"; };
          "bind \"N\"" = { Search = "up"; };
        };
        
        # Enhanced scroll mode
        scroll = {
          "bind \"j\"" = { ScrollDown = {}; };
          "bind \"k\"" = { ScrollUp = {}; };
          "bind \"d\"" = { HalfPageScrollDown = {}; };
          "bind \"u\"" = { HalfPageScrollUp = {}; };
          "bind \"g\"" = { ScrollToTop = {}; };
          "bind \"G\"" = { ScrollToBottom = {}; };
        };
      };
      
      # Plugins similar to tmux functionality
      plugins = {
        "session-manager" = {
          path = "session-manager";
        };
      };
    };
  };
  
  # Add zellij to shell aliases for easy access
  home.shellAliases = {
    zj = "zellij";
    zja = "zellij attach";
    zjl = "zellij list-sessions";
    zjk = "zellij kill-session";
  };
}