{
  # Polls every drive's SMART / NVMe health log every 30 minutes and alerts on
  # a critical warning, spare capacity under threshold, new media errors or a
  # failed self-assessment. The module's default alert is `wall`, which nothing
  # in a Hyprland session displays; systembus-notify relays it to the shell's
  # notification daemon instead.
  services.smartd = {
    enable = true;
    notifications.systembus-notify.enable = true;
  };
}
