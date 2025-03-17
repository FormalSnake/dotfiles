{
  config,
  pkgs,
  ...
}: {
  home.file.".config/matugen/config.toml".source = ./matugen/config.toml;
  home.file.".config/matugen/templates/config".source = ./matugen/templates/config;
  home.file.".config/matugen/templates/neovim.template".source = ./matugen/templates/neovim.template;
}
