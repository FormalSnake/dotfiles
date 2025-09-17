{
  config,
  pkgs,
  ...
}: {
  programs.kitty = {
    enable = false;
    font = {
      name = "GeistMono Nerd Font";
      size = 12;
    };
    settings = {
      scrollback_lines = 10000;
      enable_audio_bell = false;
      background_opacity = "0.95";
      window_padding_width = 4;
      confirm_os_window_close = 0;
    };
    themeFile = "Catppuccin-Mocha";
  };
}
