{
  config,
  pkgs,
  ...
}: {
  programs.fzf = {
    enable = true;
    enableFishIntegration = true;
  };
}
