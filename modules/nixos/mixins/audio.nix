{
  # PipeWire audio stack (replaces PulseAudio).
  security.rtkit.enable = true;

  services.pulseaudio.enable = false;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # The "Shit Mic" (Jschlatt-style blown-out lo-fi mic) is no longer a
  # hand-rolled PipeWire filter-chain — that approach never reliably latched
  # onto the real mic (passive/dont-reconnect capture) and produced no audio.
  # It now lives in EasyEffects as a user-level input preset, configured in
  # users/kyandesutter/mixins/easyeffects.nix, with the SUPER+M toggle in
  # users/kyandesutter/mixins/hyprland.nix. EasyEffects' `processAllInputs`
  # auto-routes every app's mic through its virtual source, so apps need no
  # per-app setup. `programs.dconf.enable` (required by the EasyEffects daemon)
  # is already set in modules/nixos/mixins/hyprland.nix.
}
