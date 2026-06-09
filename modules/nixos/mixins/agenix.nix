{ inputs, ... }:
{
  imports = [ inputs.agenix.nixosModules.default ];

  # On NixOS, agenix decrypts at activation using the host SSH key
  # (/etc/ssh/ssh_host_ed25519_key, the default identityPath). openssh must be
  # enabled so that key exists.
  services.openssh = {
    enable = true;
    openFirewall = false;
  };

  # Secrets are intentionally NOT declared yet: the laptop's host key is not a
  # recipient in secrets/secrets.nix, so decryption would fail and block the
  # first rebuild. The fish mixin reads /run/agenix/<name> defensively, so the
  # absence is harmless until enrolled.
  #
  # TODO (post-install, on the laptop):
  #   1. cat /etc/ssh/ssh_host_ed25519_key.pub
  #   2. nix run nixpkgs#ssh-to-age -- < that pub key   (gives an age1... key)
  #   3. add it to secrets/secrets.nix recipients, run `agenix -r` in secrets/
  #   4. uncomment the block below and rebuild.
  #
  # age.secrets =
  #   let
  #     mkSecret = name: {
  #       file = ../../../secrets/${name}.age;
  #       owner = "kyandesutter";
  #       group = "users";
  #     };
  #   in
  #   {
  #     openai             = mkSecret "openai";
  #     anthropic          = mkSecret "anthropic";
  #     gemini             = mkSecret "gemini";
  #     deepseek           = mkSecret "deepseek";
  #     canaryllm          = mkSecret "canaryllm";
  #     nucleo-license     = mkSecret "nucleo-license";
  #     npm-github-token   = mkSecret "npm-github-token";
  #     npm-registry-token = mkSecret "npm-registry-token";
  #   };
}
