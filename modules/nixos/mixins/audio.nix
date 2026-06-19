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

    # AirPlay output (RAOP = Remote Audio Output Protocol). This loads the
    # discovery module into the PipeWire daemon, which browses the network via
    # Avahi for `_raop._tcp` services (HomePods, Apple TVs, AirPort Express,
    # shairport-sync receivers, …) and exposes each one as an audio sink. Once
    # rebuilt, the receivers show up as output devices in pavucontrol / the
    # caelestia audio widget and any app's audio can be routed to them.
    extraConfig.pipewire."10-airplay"."context.modules" = [
      { name = "libpipewire-module-raop-discover"; }
    ];
  };

  # mDNS/Bonjour service discovery — required for the RAOP module above to find
  # AirPlay receivers on the local network. openFirewall punches through UDP 5353
  # for the multicast DNS queries.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };
}
