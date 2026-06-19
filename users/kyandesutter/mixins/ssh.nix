{ pkgs, lib, ... }:
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    # Pull in OrbStack's auto-generated ssh config
    includes = [ "~/.orbstack/ssh/config" ];

    settings = {
      "*" = {
        AddKeysToAgent = "yes";
        ServerAliveInterval = 60;
      };

      "mac-codeserver" = {
        HostName = "192.168.1.36";
        User = "kyandesutter";
        LocalForward = "8080 127.0.0.1:8080";
      };

      # Remote work server over Tailscale (reachable anywhere). `mosh macbook`
      # uses this entry for the resilient shell; a separate `ssh -fN macbook`
      # holds the tunnels (mosh cannot forward ports). serve-sim needs BOTH
      # 3200 (preview UI) and 3100 (MJPEG/WS stream) — see docs/remote-server.md.
      "macbook" = {
        HostName = "macbook-pro-2"; # Tailscale MagicDNS name of the Mac (confirmed via direct ssh)
        User = "kyandesutter";
        LocalForward = [
          "3200 127.0.0.1:3200"
          "3100 127.0.0.1:3100"
          "8080 127.0.0.1:8080"
          # CanaryPulse dev servers — so the browser on the client can reach them
          # as localhost (auth/CORS/cookies are localhost-only in dev). The admin
          # SPA loads its API/scraper URLs as http://localhost:<port> in the
          # browser, so 3001 (API) is required alongside 4322 (admin) for login.
          "4322 127.0.0.1:4322" # admin SPA
          "3001 127.0.0.1:3001" # API (browser calls directly: auth + tRPC)
          "3003 127.0.0.1:3003" # scraper (REST + WebSocket)
          "4321 127.0.0.1:4321" # web (optional)
        ];
      };

      "superserver.local" = {
        HostName = "192.168.86.2";
        Port = 22;
        User = "kyandesutter";
        ForwardX11 = "yes";
        ForwardX11Trusted = "yes";
      };

      "superserver" = {
        HostName = "office.kaiiserni.com";
        Port = 22;
        User = "kyandesutter";
        ForwardX11 = "yes";
        ForwardX11Trusted = "yes";
      };

      "gitserver" = {
        HostName = "formalgit.kaiiserni.com";
        Port = 5173;
        User = "kyandesutter";
      };

      # UseKeychain is an Apple-SSH-only option; Linux OpenSSH rejects the
      # whole config if it appears, so only emit it on Darwin.
      "github.com" = {
        AddKeysToAgent = "yes";
        IdentityFile = "~/.ssh/id_ed25519";
      } // lib.optionalAttrs pkgs.stdenv.isDarwin {
        UseKeychain = "yes";
      };

      "superintelligence" = {
        HostName = "212.64.180.162";
        User = "kdesutter";
      };
    };
  };
}
