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

        # Route SSH auth through the 1Password agent instead of gnome-keyring's.
        # IdentityAgent overrides SSH_AUTH_SOCK, so this takes over cleanly without
        # disabling gnome-keyring (which still backs the Secret Service). The socket
        # only exists once 1Password's SSH agent is enabled in-app (Settings →
        # Developer → "Use the SSH agent"); until then ssh falls back to on-disk
        # keys. The Darwin path is 1Password's sandboxed group-container socket and
        # must stay quoted (it contains spaces).
        IdentityAgent =
          if pkgs.stdenv.isDarwin
          then ''"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"''
          else "~/.1password/agent.sock";
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
        # Resolved via /etc/hosts (networking.hosts in modules/nixos/mixins/
        # networking.nix), which pins this name to the macbook's stable Tailscale
        # IP. Plain MagicDNS doesn't work here: the host forces Google DNS and
        # NordVPN overwrites /etc/resolv.conf when connected — both bypass the
        # tailnet resolver. /etc/hosts is consulted before DNS, so the name
        # resolves regardless. (NordVPN coexistence also needs `lan-discovery`
        # enabled so the direct LAN handshake isn't firewalled off — enforced by
        # nordvpn-settings.service.)
        HostName = "macbook-pro-2";
        User = "kyandesutter";
        # Mac-side connect target is `localhost` (not 127.0.0.1) on purpose:
        # Vite/Astro dev servers bind only to IPv6 [::1], while workerd/bun bind
        # IPv4. Targeting `localhost` makes sshd on the Mac try every address for
        # the name, so the forward connects regardless of which stack the server
        # chose — otherwise IPv6-only servers fail with `channel N: open failed`.
        # The local listen side is pinned to 127.0.0.1 (not bare `localhost`):
        # localhost resolves to both 127.0.0.1 and [::1], and when NordVPN is
        # connected it disables IPv6 system-wide (leak protection), so the [::1]
        # bind fails with "Cannot assign requested address" — 8 warnings per
        # connect. Pinning IPv4 skips that bind and keeps the localhost-only
        # (cookies/CORS) semantics the browser needs.
        LocalForward = [
          "127.0.0.1:3200 localhost:3200"
          "127.0.0.1:3100 localhost:3100"
          "127.0.0.1:8080 localhost:8080"
          "127.0.0.1:3000 localhost:3000" # generic dev server (Next.js/Vite default)
          # CanaryPulse dev servers — so the browser on the client can reach them
          # as localhost (auth/CORS/cookies are localhost-only in dev). The admin
          # SPA loads its API/scraper URLs as http://localhost:<port> in the
          # browser, so 3001 (API) is required alongside 4322 (admin) for login.
          "127.0.0.1:4322 localhost:4322" # admin SPA
          "127.0.0.1:3001 localhost:3001" # API (browser calls directly: auth + tRPC)
          "127.0.0.1:3003 localhost:3003" # scraper (REST + WebSocket)
          "127.0.0.1:4321 localhost:4321" # web (optional)
          "127.0.0.1:4983 localhost:4983" # Drizzle Kit / Drizzle Studio
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
