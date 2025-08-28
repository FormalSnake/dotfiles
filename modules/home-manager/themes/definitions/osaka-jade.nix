{pkgs, ...}: {
  name = "Omarchy Osaka Jade";
  
  colors = {
    # Base colors from the actual Omarchy Osaka Jade theme (alacritty.toml)
    background = "#111c18";
    foreground = "#C1C497";
    surface0 = "#23372B";
    surface1 = "#53685B";
    surface2 = "#549e6a";
    overlay0 = "#459451";
    overlay1 = "#509475";
    overlay2 = "#2DD5B7";
    text = "#F6F5DD";
    subtext0 = "#C1C497";
    subtext1 = "#9eebb3";
    
    # Accent colors from alacritty.toml
    red = "#FF5345";
    green = "#549e6a";
    blue = "#509475";
    yellow = "#E5C736";
    orange = "#db9f9c";
    pink = "#D2689C";
    purple = "#75bbb3";
    teal = "#2DD5B7";
    sky = "#ACD4CF";
    sapphire = "#8CD3CB";
    lavender = "#143614";
    mauve = "#D2689C";
  };

  neovim = {
    plugin = pkgs.vimPlugins.bamboo-nvim;
    colorscheme = "bamboo";
  };

  ghostty = {
    isCustom = true;
    theme = ''
      # Omarchy Osaka Jade Theme for Ghostty
      # Based on the original alacritty configuration
      
      background = #111c18
      foreground = #C1C497
      
      cursor-color = #D7C995
      
      selection-foreground = #000000
      selection-background = #C1C497
      
      # Palette colors (16 color terminal)
      palette = 0=#23372B
      palette = 1=#FF5345
      palette = 2=#549e6a
      palette = 3=#459451
      palette = 4=#509475
      palette = 5=#D2689C
      palette = 6=#2DD5B7
      palette = 7=#F6F5DD
      palette = 8=#53685B
      palette = 9=#db9f9c
      palette = 10=#143614
      palette = 11=#E5C736
      palette = 12=#ACD4CF
      palette = 13=#75bbb3
      palette = 14=#8CD3CB
      palette = 15=#9eebb3
    '';
  };

  btop = {
    theme = ''
      theme[main_bg]="#111c18"
      theme[main_fg]="#C1C497"
      theme[title]="#F6F5DD"
      theme[hi_fg]="#2DD5B7"
      theme[selected_bg]="#23372B"
      theme[selected_fg]="#2DD5B7"
      theme[inactive_fg]="#53685B"
      theme[graph_text]="#C1C497"
      theme[meter_bg]="#23372B"
      theme[proc_misc]="#C1C497"
      theme[cpu_box]="#D2689C"
      theme[mem_box]="#549e6a"
      theme[net_box]="#FF5345"
      theme[proc_box]="#509475"
      theme[div_line]="#53685B"
      theme[temp_start]="#549e6a"
      theme[temp_mid]="#E5C736"
      theme[temp_end]="#FF5345"
      theme[cpu_start]="#2DD5B7"
      theme[cpu_mid]="#ACD4CF"
      theme[cpu_end]="#75bbb3"
    '';
  };

  tmux = {
    config = ''
      # Omarchy Osaka Jade tmux theme
      set -g status-bg "#111c18"
      set -g status-fg "#C1C497"
      set -g status-left-style "fg=#111c18,bg=#2DD5B7"
      set -g status-right-style "fg=#F6F5DD,bg=#23372B"
      set -g window-status-current-style "fg=#111c18,bg=#2DD5B7"
      set -g window-status-style "fg=#53685B,bg=#23372B"
      set -g pane-border-style "fg=#23372B"
      set -g pane-active-border-style "fg=#2DD5B7"
      set -g message-style "fg=#111c18,bg=#E5C736"
      set -g message-command-style "fg=#111c18,bg=#2DD5B7"
    '';
  };
}