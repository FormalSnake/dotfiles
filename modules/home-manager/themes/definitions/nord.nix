{pkgs, ...}: {
  name = "Nord";
  
  colors = {
    background = "#2e3440";
    foreground = "#d8dee9";
    surface0 = "#3b4252";
    surface1 = "#434c5e";
    surface2 = "#4c566a";
    overlay0 = "#5e81ac";
    overlay1 = "#81a1c1";
    overlay2 = "#88c0d0";
    text = "#eceff4";
    subtext0 = "#e5e9f0";
    subtext1 = "#d8dee9";
    red = "#bf616a";
    green = "#a3be8c";
    blue = "#5e81ac";
    yellow = "#ebcb8b";
    orange = "#d08770";
    pink = "#b48ead";
    purple = "#b48ead";
    teal = "#88c0d0";
    sky = "#8fbcbb";
    sapphire = "#88c0d0";
    lavender = "#b48ead";
    mauve = "#b48ead";
  };

  neovim = {
    plugin = pkgs.vimPlugins.nord-nvim;
    colorscheme = "nord";
  };

  ghostty = {
    theme = "nord";
  };

  btop = {
    theme = ''
      theme[main_bg]="#2e3440"
      theme[main_fg]="#d8dee9"
      theme[title]="#eceff4"
      theme[hi_fg]="#5e81ac"
      theme[selected_bg]="#3b4252"
      theme[selected_fg]="#88c0d0"
      theme[inactive_fg]="#4c566a"
      theme[graph_text]="#e5e9f0"
      theme[meter_bg]="#3b4252"
      theme[proc_misc]="#e5e9f0"
      theme[cpu_box]="#5e81ac"
      theme[mem_box]="#a3be8c"
      theme[net_box]="#bf616a"
      theme[proc_box]="#81a1c1"
      theme[div_line]="#434c5e"
      theme[temp_start]="#a3be8c"
      theme[temp_mid]="#ebcb8b"
      theme[temp_end]="#bf616a"
      theme[cpu_start]="#88c0d0"
      theme[cpu_mid]="#8fbcbb"
      theme[cpu_end]="#b48ead"
    '';
  };

  fish = {
    colors = {
      fish_color_normal = "#d8dee9";
      fish_color_command = "#81a1c1";
      fish_color_param = "#eceff4";
      fish_color_keyword = "#b48ead";
      fish_color_quote = "#a3be8c";
      fish_color_redirection = "#d08770";
      fish_color_end = "#88c0d0";
      fish_color_error = "#bf616a";
      fish_color_gray = "#4c566a";
      fish_color_selection = "#3b4252";
      fish_color_search_match = "#ebcb8b";
      fish_color_operator = "#5e81ac";
      fish_color_escape = "#8fbcbb";
      fish_color_autosuggestion = "#4c566a";
      fish_color_cancel = "#bf616a";
      fish_pager_color_progress = "#4c566a";
      fish_pager_color_prefix = "#88c0d0";
      fish_pager_color_completion = "#eceff4";
      fish_pager_color_description = "#4c566a";
    };
  };
}