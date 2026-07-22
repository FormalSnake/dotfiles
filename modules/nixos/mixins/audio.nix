{ pkgs, ... }:
let
  # Follow-the-newest-device daemon. WirePlumber on this chassis intermittently
  # leaves a freshly-connected Bluetooth card parked at profile "off" (its flaky
  # BR/EDR link loses the A2DP transport during setup), so no sink node is ever
  # created and there is nothing for audio to switch to — the "AirPods connected
  # but sound stayed on the speakers" bug. This reconcile loop fixes both halves:
  #   1. any connected bluez card sitting at profile "off" is kicked onto its
  #      generic a2dp-sink profile (retried every tick, so a transport that only
  #      comes up on the third attempt still recovers);
  #   2. whenever a new *device-backed* sink appears (BT card, HDMI hotplug,
  #      redocked USB DAC) it becomes the default — EasyEffects and every
  #      untargeted stream follow the default automatically, so the whole chain
  #      moves with one set-default and links are left untouched.
  # Virtual sinks (easyeffects_sink, null sinks) carry no device.id and are
  # skipped, so the EQ sink is never selected as an output. On disconnect
  # WirePlumber's own priority fallback picks the next sink (built-in speakers),
  # which this loop leaves alone since that sink was already seen.
  audio-autoswitch = pkgs.writeShellApplication {
    name = "audio-autoswitch";
    runtimeInputs = [ pkgs.wireplumber pkgs.pipewire pkgs.jq pkgs.coreutils ];
    text = ''
      declare -A seen
      primed=0

      reconcile() {
        local dump
        dump=$(pw-dump 2>/dev/null) || return 0

        # 1. Kick connected BT cards stuck at profile "off" onto A2DP.
        local id idx
        while read -r id idx; do
          [ -n "$id" ] && wpctl set-profile "$id" "$idx" 2>/dev/null || true
        done < <(printf '%s' "$dump" | jq -r '
          .[] | select(.type=="PipeWire:Interface:Device")
              | select(.info.props["device.api"]=="bluez5")
              | select((.info.params.Profile[0].index // -1) == 0)
              | (.info.params.EnumProfile[]?
                 | select(.name=="a2dp-sink" and .available=="yes") | .index) as $a2dp
              | "\(.id) \($a2dp)"
        ')

        # 2. Make any newly-appeared device-backed sink the default.
        local newest_serial=-1 newest_id="" serial sid
        local -a current=()
        while read -r serial sid; do
          [ -n "$sid" ] || continue
          current+=("$sid")
          if [ -z "''${seen[$sid]:-}" ] && [ "$serial" -gt "$newest_serial" ]; then
            newest_serial=$serial
            newest_id=$sid
          fi
        done < <(printf '%s' "$dump" | jq -r '
          .[] | select(.type=="PipeWire:Interface:Node")
              | select(.info.props["media.class"]=="Audio/Sink")
              | select(.info.props["device.id"] != null)
              | select(.info.props["object.serial"] != null)
              | "\(.info.props["object.serial"]) \(.id)"
        ')

        [ "$primed" -eq 1 ] && [ -n "$newest_id" ] && wpctl set-default "$newest_id" 2>/dev/null || true

        seen=()
        for sid in "''${current[@]}"; do seen[$sid]=1; done
        primed=1
      }

      while true; do
        reconcile
        sleep 2
      done
    '';
  };
in
{
  # PipeWire audio stack (replaces PulseAudio).
  security.rtkit.enable = true;

  # pactl client: DMS shells out to it for codec/output handling. PipeWire ships
  # the pulse *server* (pulse.enable) but not the CLI client, and the user
  # service PATH sees the system profile, not the home one — so install it here.
  environment.systemPackages = [ pkgs.pulseaudio ];

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;

    # Floor the graph quantum at 1024 frames (~21ms). Games (e.g. Cities2)
    # otherwise negotiate the whole graph down to 256 frames (~5.3ms); under
    # gaming CPU load the EasyEffects DSP chain misses that deadline and xruns,
    # which are audible as pops/crackle. A larger buffer absorbs the jitter.
    extraConfig.pipewire."92-min-quantum"."context.properties"."default.clock.min-quantum" = 1024;

    # Never auto-switch Bluetooth headsets to the HFP/headset profile. This
    # chassis's BT adapter can't hold an SCO voice link (kernel: "SCO packet for
    # unknown connection handle"), so the AirPods mic only ever captures silence
    # anyway. Left on, WirePlumber flips A2DP→headset whenever an app opens that
    # dead mic, which swaps the high-quality stereo sink for a separate HFP sink
    # whose volume collapses toward 0 — the media volume "randomly" dropping.
    # Off: AirPods stay A2DP (full stereo, stable volume); calls use the laptop
    # mic, which WirePlumber then picks as the default source on its own.
    wireplumber.extraConfig."51-airpods-a2dp-only"."wireplumber.settings"."bluetooth.autoswitch-to-headset-profile" = false;

    # Device-specific output priorities (headphone MACs, this chassis's PCI
    # audio addresses) live in systems/g815/default.nix — they are hardware
    # facts, not portable audio-stack config.
  };

  systemd.user.services.audio-autoswitch = {
    description = "Switch default output to newly-connected audio devices";
    after = [ "wireplumber.service" ];
    wantedBy = [ "pipewire.service" ];
    serviceConfig = {
      ExecStart = "${audio-autoswitch}/bin/audio-autoswitch";
      Restart = "always";
      RestartSec = 3;
    };
  };
}
