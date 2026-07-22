{ config, lib, inputs, ... }:
{
  imports = [ inputs.agenix.nixosModules.default ];

  # openssh must be enabled for the host key to exist; agenix could fall back to
  # it, but we decrypt with the shared `kyan` age identity instead (below).
  # Closed on the LAN by default (tailscale0 stays trusted elsewhere); hosts
  # that want LAN ssh override with openFirewall = true.
  services.openssh = {
    enable = true;
    openFirewall = lib.mkDefault false;
  };

  age = {
    # Master identity used to decrypt at activation time. This is the same
    # `kyan` age key the MacBook uses (recipient age1fg5...k3hufv in
    # secrets/secrets.nix). Copied here out-of-band; NOT git-tracked.
    identityPaths = [ "${config.users.users.kyandesutter.home}/.config/age/keys.txt" ];

    secrets =
      let
        mkSecret = name: {
          file = ../../../secrets/${name}.age;
          owner = "kyandesutter";
          group = "users";
        };
      in
      {
        openai             = mkSecret "openai";
        anthropic          = mkSecret "anthropic";
        gemini             = mkSecret "gemini";
        deepseek           = mkSecret "deepseek";
        canaryllm          = mkSecret "canaryllm";
        nucleo-license     = mkSecret "nucleo-license";
        npm-github-token   = mkSecret "npm-github-token";
        npm-registry-token = mkSecret "npm-registry-token";
        wstunnel-path-prefix = mkSecret "wstunnel-path-prefix";
        wstunnel-endpoint    = mkSecret "wstunnel-endpoint";
        couchdb-admin        = mkSecret "couchdb-admin";
      };
  };
}
