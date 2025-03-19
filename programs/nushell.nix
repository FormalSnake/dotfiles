{
  config,
  pkgs,
  ...
}: {
  programs.nushell = {
    enable = true;
    configFile.source = ./nushell/config.nu;
  };
  programs.carapace.enable = true;
  programs.carapace.enableNushellIntegration = true;

  # copy the zoxide.nu to the root
  home.file.".zoxide.nu".source = ./nushell/zoxide.nu;
}
