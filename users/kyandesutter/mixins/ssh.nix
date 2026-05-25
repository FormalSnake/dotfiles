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

      "github.com" = {
        AddKeysToAgent = "yes";
        UseKeychain = "yes";
        IdentityFile = "~/.ssh/id_ed25519";
      };

      "superintelligence" = {
        HostName = "212.64.180.162";
        User = "kdesutter";
      };
    };
  };
}
