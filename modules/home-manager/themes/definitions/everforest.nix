{pkgs, ...}: {
  name = "Everforest Dark";
  
  colors = {
    background = "#2d353b";
    foreground = "#d3c6aa";
    surface0 = "#343f44";
    surface1 = "#3d484d";
    surface2 = "#475258";
    overlay0 = "#543a48";
    overlay1 = "#5d4037";
    overlay2 = "#68422e";
    text = "#d3c6aa";
    subtext0 = "#859289";
    subtext1 = "#9da9a0";
    red = "#e67e80";
    green = "#a7c080";
    blue = "#7fbbb3";
    yellow = "#dbbc7f";
    orange = "#e69875";
    pink = "#d699b6";
    purple = "#d699b6";
    teal = "#83c092";
    sky = "#7fbbb3";
    sapphire = "#7fbbb3";
    lavender = "#d699b6";
    mauve = "#d699b6";
  };

  neovim = {
    plugin = pkgs.vimPlugins.everforest;
    colorscheme = "everforest";
  };

  ghostty = {
    theme = "Everforest Dark - Hard";
  };

  btop = {
    theme = ''
      theme[main_bg]="#2d353b"
      theme[main_fg]="#d3c6aa"
      theme[title]="#d3c6aa"
      theme[hi_fg]="#a7c080"
      theme[selected_bg]="#343f44"
      theme[selected_fg]="#a7c080"
      theme[inactive_fg]="#859289"
      theme[graph_text]="#d3c6aa"
      theme[meter_bg]="#343f44"
      theme[proc_misc]="#d3c6aa"
      theme[cpu_box]="#d699b6"
      theme[mem_box]="#a7c080"
      theme[net_box]="#e67e80"
      theme[proc_box]="#7fbbb3"
      theme[div_line]="#475258"
      theme[temp_start]="#a7c080"
      theme[temp_mid]="#dbbc7f"
      theme[temp_end]="#e67e80"
      theme[cpu_start]="#83c092"
      theme[cpu_mid]="#7fbbb3"
      theme[cpu_end]="#d699b6"
    '';
  };

  fish = {
    colors = {
      fish_color_normal = "#d3c6aa";
      fish_color_command = "#7fbbb3";
      fish_color_param = "#d3c6aa";
      fish_color_keyword = "#d699b6";
      fish_color_quote = "#a7c080";
      fish_color_redirection = "#e69875";
      fish_color_end = "#e69875";
      fish_color_error = "#e67e80";
      fish_color_gray = "#859289";
      fish_color_selection = "#343f44";
      fish_color_search_match = "#dbbc7f";
      fish_color_operator = "#e69875";
      fish_color_escape = "#83c092";
      fish_color_autosuggestion = "#859289";
      fish_color_cancel = "#e67e80";
      fish_pager_color_progress = "#859289";
      fish_pager_color_prefix = "#7fbbb3";
      fish_pager_color_completion = "#d3c6aa";
      fish_pager_color_description = "#859289";
    };
  };
}