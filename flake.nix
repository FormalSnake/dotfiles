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

    nix-homebrew = {
      url = "github:zhaofengli/nix-homebrew";
    };

    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin = {
      url = "github:catppuccin/nix";
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

    # — NixOS (g815 gaming laptop) inputs —

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    # NordVPN — laptop VPN exit only (the device mesh is Tailscale). No
    # first-party nixpkgs module exists; this community flake provides the
    # package + a NixOS module (services.nordvpn).
    nordvpn-flake.url = "github:connerohnesorge/nordvpn-flake";

    # CachyOS kernel + scx schedulers. nyxpkgs-unstable tracks nixpkgs-unstable.
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";

    # Declarative Flatpak management (used for Sober, the Roblox client, which
    # is only distributed as a Flatpak — not packaged in nixpkgs).
    nix-flatpak.url = "github:gmodena/nix-flatpak";

    # noctalia V5 desktop shell — native C++/OpenGL ES, official flake (home-
    # manager module under homeModules.default). Build from source following our
    # nixpkgs (no cachix substituter).
    noctalia = {
      url = "github:noctalia-dev/noctalia";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Helium browser (Chromium fork) — exposes overlays.default -> pkgs.helium.
    helium = {
      url = "github:schembriaiden/helium-browser-nix-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
