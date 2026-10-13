{ inputs, ... }:
{
  # meshtop (github:FormalSnake/meshtop). Installed on all three hosts: the
  # TUI runs `meshtop agent` over ssh on the other two, and each agent reads
  # its activity rules from this same config. The mac's own hostname is
  # MacBook-Pro-2, so it needs `hostname` to be sampled in process there.
  imports = [ inputs.meshtop.homeModules.default ];

  programs.meshtop = {
    enable = true;
    hosts = [
      {
        name = "macbook";
        role = "dev";
        hostname = "MacBook-Pro-2";
      }
      {
        name = "g815";
        role = "builder";
      }
      {
        name = "e1504g";
        role = "client";
      }
    ];
    # Messages on the Linux hosts talks to BlueBubbles on the mac.
    ports."1234" = "bluebubbles";
  };
}
