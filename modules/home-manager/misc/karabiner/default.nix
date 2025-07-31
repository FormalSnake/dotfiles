{
  config,
  pkgs,
  ...
}: {
  home.file.".config/karabiner/karabiner.json".source = ./karabiner.json;
}
