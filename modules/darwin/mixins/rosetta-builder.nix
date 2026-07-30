{
  config,
  lib,
  inputs,
  ...
}:
let
  cfg = config.kyan.rosettaBuilder;

  # /root/.ssh/nix-builder on the e1504g — the same key the g815 force-commands
  # to `nix-daemon --stdio` (systems/g815/default.nix). Reused here so no
  # private key has to travel between hosts: the e1504g authenticates the jump
  # into this Mac and the hop into the VM with one identity.
  e1504gBuilderKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE68KT/5PWD5x1vVv2GiXcT2KlDdnl1WPH1JTEPnGpZO nix-builder@e1504g";

  # Loopback port the VM's sshd is published on (nix-rosetta-builder's default).
  # The e1504g's ssh config and this Mac's permitopen both hardcode it, so keep
  # the three in step.
  port = 31122;
in
{
  imports = [ inputs.nix-rosetta-builder.darwinModules.default ];

  options.kyan.rosettaBuilder.enable =
    lib.mkEnableOption "Rosetta-backed Linux builder VM for x86_64-linux and aarch64-linux";

  config = lib.mkIf cfg.enable {
    # Apple Silicon cannot build Linux at all, and QEMU-emulating x86_64 would
    # land slower than the e1504g's own i3-N305. Rosetta 2 inside an aarch64
    # Linux VM runs x86_64 at near-native speed, which is the only arrangement
    # where this Mac is worth offloading to. Needs `softwareupdate
    # --install-rosetta` on the host (already done).
    #
    # Building this VM's image is itself a Linux build, so it needs a Linux
    # builder to bootstrap. Determinate ships one (aarch64-linux, 1 job, over
    # macOS's Virtualization framework) and leaves it on by default, which is
    # what covers the first switch — so `determinateNix.determinateNixd.builder`
    # is deliberately left alone rather than turned off as redundant. It is also
    # the fallback whenever a change to the VM's shape recreates it.
    nix-rosetta-builder = {
      enable = true;
      inherit port;

      # 6 of the M1 Pro's 10 cores; this is still the primary dev host.
      cores = 6;
      memory = "8GiB";

      # Deliberately small: only ~26 GiB is free on this Mac. The VM's own Nix
      # settings auto-GC at min-free 5G, so it trims itself rather than filling
      # the image and taking macOS down with it. Raise this once the host has
      # room to spare.
      diskSize = "16GiB";

      # Idle-poweroff so the VM costs nothing between rebuilds. launchd
      # socket-activates it on the first connection to `port`, including the
      # e1504g's tunnelled one, at the cost of a few seconds of boot on a cold
      # build.
      onDemand = true;

      # Below the g815's 4 in the e1504g's build machine list: Rosetta is fast
      # but not native, and every byte crosses an SSH tunnel.
      speedFactor = 3;

      # Let the e1504g's root log into the VM as `builder`. This cannot go
      # through `users.users.builder.openssh.authorizedKeys.keys`: that writes
      # /etc/ssh/authorized_keys.d/builder, the exact file the VM's own
      # sshd-keys unit creates at boot from the virtiofs-mounted host keys, and
      # whose absence is its ConditionPathExists. A second authorized-keys path
      # stays clear of it. mode 0444 makes it a real file rather than a
      # /nix/store symlink, which sshd's StrictModes requires.
      potentiallyInsecureExtraNixosModule = {
        environment.etc."ssh/authorized_keys.d.remote/builder" = {
          mode = "0444";
          text = "${e1504gBuilderKey}\n";
        };
        services.openssh.authorizedKeysFiles = [ "/etc/ssh/authorized_keys.d.remote/%u" ];
      };
    };

    # The e1504g's root jumps through this account to reach the VM on loopback.
    # Merged with, not replacing, the machine keys in mixins/remote-access.nix —
    # and deliberately NOT added to that file's `machineKeys` list, which also
    # feeds pam_ssh_agent_auth and would hand this key passwordless sudo.
    # `restrict` kills everything, `port-forwarding` + `permitopen` hand back
    # exactly one destination: no shell, no agent, no other port.
    users.users.kyandesutter.openssh.authorizedKeys.keys = [
      ''restrict,port-forwarding,permitopen="127.0.0.1:${toString port}" ${e1504gBuilderKey}''
    ];

    # nix-rosetta-builder registers the VM via `nix.buildMachines`, which
    # Determinate's module force-disables along with the rest of nix-darwin's
    # Nix management (mixins/determinate.nix). Without this mirror the VM would
    # exist but this Mac would never use it. `rosetta-builder` is the ssh alias
    # the module drops in /etc/ssh/ssh_config.d/, carrying the user, port,
    # identity and pinned host key.
    determinateNix = {
      distributedBuilds = true;
      buildMachines = [
        {
          hostName = "rosetta-builder";
          protocol = "ssh-ng";
          systems = [
            "aarch64-linux"
            "x86_64-linux"
          ];
          maxJobs = 6;
          speedFactor = 3;
          # No kvm/nixos-test: the guest is aarch64, so nested x86 VMs can't run
          # there and advertising it would only attract builds that then fail.
          supportedFeatures = [
            "benchmark"
            "big-parallel"
          ];
        }
      ];
      customSettings.builders-use-substitutes = true;
    };
  };
}
