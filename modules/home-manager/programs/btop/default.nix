{
  config,
  pkgs,
  ...
}: let
  currentTheme = config.themes.available.${config.themes.current or "catppuccin"} or {};
  btopTheme = currentTheme.btop.theme or "";
in {
  programs.btop = {
    enable = false;
  };

  # Create btop theme file based on current theme
  # home.file.".config/btop/themes/current.theme".text = btopTheme;
  #
  # # Configure btop to use the current theme
  # home.file.".config/btop/btop.conf".text = ''
  #   color_theme = "current"
  #   theme_background = false
  #   truecolor = true
  #   vim_keys = true
  #   rounded_corners = true
  #   graph_symbol = "braille"
  #   shown_boxes = "cpu mem net proc"
  #   update_ms = 2000
  #   proc_sorting = "cpu lazy"
  #   proc_reversed = false
  #   proc_tree = false
  #   proc_colors = true
  #   proc_gradient = true
  #   proc_per_core = false
  #   proc_mem_bytes = true
  #   cpu_graph_upper = "total"
  #   cpu_graph_lower = "total"
  #   cpu_invert_lower = true
  #   cpu_single_graph = false
  #   cpu_bottom = false
  #   show_uptime = true
  #   check_temp = true
  #   show_coretemp = true
  #   show_cpu_freq = true
  #   background_update = true
  #   custom_cpu_name = ""
  #   disks_filter = ""
  #   mem_graphs = true
  #   show_swap = true
  #   swap_disk = true
  #   show_disks = true
  #   only_physical = true
  #   use_fstab = false
  #   show_io_stat = true
  #   io_mode = false
  #   io_graph_combined = false
  #   io_graph_speeds = ""
  #   net_download = 100
  #   net_upload = 100
  #   net_auto = true
  #   net_sync = false
  #   net_color_fixed = false
  #   net_iface = ""
  #   show_battery = true
  #   show_init = false
  #   log_level = "WARNING"
  # '';
}
