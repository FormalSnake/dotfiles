{
  config,
  spicePkgs,
  ...
}: {
  # Spicetify integration.
  programs.spicetify = {
    enable = true;
    enabledExtensions = with spicePkgs.extensions; [
      # beautifulLyrics
      # hidePodcasts
      shuffle
    ];
    enabledCustomApps = with spicePkgs.apps; [
      newReleases
    ];
    enabledSnippets = with spicePkgs.snippets; [
      # smooth-progress-bar
      smoothProgressBar
      autoHideFriends
      # roundedNowPlayingBar
      roundedImages
      roundedButtons
    ];
    theme = spicePkgs.themes.catppuccin;
    colorScheme = "mocha";
  };
}
