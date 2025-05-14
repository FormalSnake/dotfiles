{
  config,
  pkgs,
  ...
}: {
  home.file.".config/matugen/config.toml".source = ./matugen/config.toml;
  home.file.".config/matugen/templates/config".source = ./matugen/templates/config;
  home.file.".config/matugen/templates/neovim.template".source = ./matugen/templates/neovim.template;
  home.file.".config/matugen/templates/spotify-colors.ini".source = ./matugen/templates/spotify-colors.ini;
  home.file.".config/matugen/templates/midnight-discord.css".source = ./matugen/templates/midnight-discord.css;
  home.file.".config/matugen/templates/tmux-colors.conf".source = ./matugen/templates/tmux-colors.conf;
}
