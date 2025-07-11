{
  config,
  pkgs,
  ...
}: {
  programs.nixcord = {
    enable = true; # Enable Nixcord (It also installs Discord)
    vesktop.enable = true; # Vesktop
    # dorion.enable = true; # Dorion
    # quickCss = "some CSS"; # quickCSS file
    config = {
      # useQuickCss = true; # use out quickCSS
      themeLinks = [
        "https://catppuccin.github.io/discord/dist/catppuccin-mocha.theme.css"
      ];
      # frameless = true; # Set some Vencord options
      plugins = {
        USRBG = {
          enable = true;
          nitroFirst = true;
          voiceBackground = true;
        };
        alwaysTrust.enable = true;
        favoriteGifSearch.enable = true;
        gifPaste.enable = true;
        fakeNitro.enable = true;
      };
    };
    # dorion = {
    #   theme = "dark";
    #   blur = "none"; # "none", "blur", or "acrylic"
    #   sysTray = true;
    #   openOnStartup = true;
    #   autoClearCache = true;
    #   disableHardwareAccel = false;
    #   rpcServer = true;
    #   rpcProcessScanner = true;
    #   pushToTalk = true;
    #   pushToTalkKeys = ["RControl"];
    #   desktopNotifications = true;
    #   unreadBadge = true;
    # };
    extraConfig = {
      # Some extra JSON config here
      # ...
    };
  };
}
