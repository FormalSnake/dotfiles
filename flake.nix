{
  description = "Kyan's nix-darwin + home-manager configuration";

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];

      imports = [
        ./flake
        ./modules
        ./systems
      ];
    };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mac-app-util.url = "github:hraban/mac-app-util";

    # No `inputs.nixpkgs.follows`: nix-homebrew is a pure nix-darwin module with
    # no nixpkgs input of its own to override, so pinning it would be a no-op.
    nix-homebrew = {
      url = "github:zhaofengli/nix-homebrew";
    };

    # No `inputs.nixpkgs.follows`: the pinned FlakeHub release ships prebuilt
    # binaries and declares no nixpkgs input of its own to override.
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lazyvim = {
      url = "github:pfassina/lazyvim-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    herdr = {
      url = "github:ogulcancelik/herdr";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # areofyl/fetch — animated 3D terminal fetch tool. Linux-only; ships a flake
    # with a home-manager module (programs.fetch). Not in nixpkgs.
    fetch = {
      url = "github:areofyl/fetch";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # CanaryCode — our own fast, minimal terminal coding agent (Bun/TypeScript).
    # Ships a flake whose package is the prebuilt per-system release binary
    # (autoPatchelf'd on Linux) plus a home-manager module (programs.canarycode).
    # Cross-platform: the release covers all four darwin/linux systems.
    canarycode = {
      url = "github:CanaryCoders/CanaryCodeCli";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # — NixOS (g815 gaming laptop) inputs —

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    # NordVPN — laptop VPN exit only (the device mesh is Tailscale). No
    # first-party nixpkgs module exists; this community flake provides the
    # package + a NixOS module (services.nordvpn). No `inputs.nixpkgs.follows`:
    # its package is built (with a vendored .deb FOD) against its own pinned
    # nixpkgs — leave it self-contained rather than risk a mismatch.
    #
    # The flake consumes the NordVPN .deb as `flake = false` inputs pinned to
    # 4.2.0, which NordVPN has since removed from their repo (404). Override
    # both arch debs to a version still hosted so the FOD resolves.
    nordvpn-flake = {
      url = "github:connerohnesorge/nordvpn-flake";
      inputs.nordvpn-amd64-deb.url = "file+https://repo.nordvpn.com/deb/nordvpn/debian/pool/main/n/nordvpn/nordvpn_5.1.0_amd64.deb";
      inputs.nordvpn-arm64-deb.url = "file+https://repo.nordvpn.com/deb/nordvpn/debian/pool/main/n/nordvpn/nordvpn_5.1.0_arm64.deb";
    };

    # CachyOS kernel + scx schedulers. nyxpkgs-unstable tracks nixpkgs-unstable.
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";

    # Declarative Flatpak management (used for Sober, the Roblox client, which
    # is only distributed as a Flatpak — not packaged in nixpkgs). No
    # `inputs.nixpkgs.follows`: it's a pure NixOS/home-manager module with no
    # nixpkgs input of its own to override.
    nix-flatpak.url = "github:gmodena/nix-flatpak";

    # Dank Material Shell (DMS) desktop shell — Quickshell/QML, official flake
    # (home-manager module under homeModules.dank-material-shell). Pinned to the
    # `stable` branch rather than main. Build from source following our nixpkgs
    # (no cachix substituter).
    dank-material-shell = {
      url = "github:AvengeMedia/DankMaterialShell/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # DankCalendar (dcal) — the calendar daemon behind DMS's native "dankcal"
    # backend (unifies Local/Google/Microsoft/CalDAV/iCloud accounts, stores
    # OAuth tokens in the keyring). Its home-manager module installs `dcal` and
    # runs `dcal run --session --hidden`; DMS's calendarBackend defaults to
    # "auto" and picks up the running daemon over IPC. See mixins/dankcal.nix.
    dankcalendar = {
      url = "github:AvengeMedia/dankcalendar";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # niri scrollable-tiling compositor. The flake is used ONLY for its typed
    # home-manager settings module (programs.niri.settings → KDL, validated
    # with `niri validate` at build time); the niri binary itself comes from
    # nixpkgs (26.04) — niri-flake's own niri-stable lags behind.
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Helium browser (Chromium fork) — exposes overlays.default -> pkgs.helium.
    helium = {
      url = "github:schembriaiden/helium-browser-nix-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
