{ config, lib, pkgs, osConfig ? { }, ... }:
let
  home = config.home.homeDirectory;

  # Same fallback as claude-code.nix: nix-darwin leaves networking.hostName null.
  osHostName = (osConfig.networking or { }).hostName or null;
  host = if osHostName == null || osHostName == "" then "macbook" else osHostName;

  # Hosts that run the server and the ssh alias the desktop reaches each by
  # (users/kyandesutter/mixins/cli/ssh.nix). The ids are each server's
  # ~/.t3/userdata/environment-id; the desktop matches the connection to the
  # server by it.
  servers = {
    macbook = {
      alias = "macbook-t3";
      environmentId = "5c911926-9553-4e77-afea-49eacc89b011";
    };
    g815 = {
      alias = "g815";
      environmentId = "d0c1975c-343f-40d3-8370-2689724f8040";
    };
  };
  isServer = servers ? ${host};

  # The desktop app only reads saved-environments.json to migrate it into its
  # safeStorage-encrypted connection-catalog.json, once, while the catalog does
  # not exist. SSH targets carry no token: the app pairs itself over ssh and
  # reuses the server already listening on the remote.
  savedEnvironments = pkgs.writeText "t3code-saved-environments.json" (
    builtins.toJSON {
      version = 1;
      records = lib.mapAttrsToList (name: { alias, environmentId }: {
        inherit environmentId;
        label = name;
        httpBaseUrl = "http://127.0.0.1:${toString port}";
        wsBaseUrl = "ws://127.0.0.1:${toString port}";
        createdAt = "2026-10-25T00:00:00.000Z";
        lastConnectedAt = null;
        desktopSsh = {
          inherit alias;
          hostname = alias;
          username = null;
          port = null;
        };
      }) servers;
    }
  );

  # Second Claude account (claude-code.nix) as its own provider instance, so
  # the model picker switches between the two logins.
  providerInstances = pkgs.writeText "t3code-provider-instances.json" (
    builtins.toJSON {
      claude-pulse = {
        driver = "claudeAgent";
        displayName = "Claude Pulse";
        enabled = true;
        config.homePath = "${home}/.claude-pulse";
      };
    }
  );

  # claude comes from programs.claude-code (claude-code-nix), so the wrapper's
  # bundled codex is dropped rather than shadowing nothing useful.
  #
  # nixpkgs ships node-pty's linux prebuild without an RPATH to libstdc++.
  # `t3 serve` runs on node, which already has it loaded, but the desktop app
  # runs its backend under Electron, which does not, so the backend dies on
  # start and the app never opens a window.
  #
  # Pinned to 0.1.2 ahead of nixpkgs-unstable: the mobile app refuses 0.0.x
  # servers. Drop the src/pnpmDeps override (and the rpath fixup, which
  # nixpkgs master carries too) once pkgs.t3code reaches 0.1.2.
  #
  # The import patch appends CLI turns to a thread imported earlier; upstream
  # imports a session once and never follows it (t3code-cli-sync below).
  t3code = pkgs.t3code.override {
    enableCodex = false;
    t3code-unwrapped = pkgs.t3code.unwrapped.overrideAttrs (
      finalAttrs: old:
      {
        version = "0.1.2";
        src = old.src.override {
          tag = "v${finalAttrs.version}";
          hash = "sha256-C5l7541kanlsukhswrAEu8GFpr/YpWDnofJ5dlg7+LM=";
        };
        pnpmDeps = pkgs.fetchPnpmDeps {
          inherit (finalAttrs) pname version src pnpmWorkspaces;
          pnpm = pkgs.pnpm_11;
          fetcherVersion = 4;
          hash = "sha256-xRmOrOZbBljaF1IJr0JFUFzdhkld6+ehLIlpVOg/J3E=";
        };
        patches = (old.patches or [ ]) ++ [ ./t3code-import-new-turns.patch ];
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        postFixup = (old.postFixup or "") + ''
          for pty in $out/libexec/t3code/node_modules/.pnpm/node-pty@*/node_modules/node-pty/prebuilds/linux-*/pty.node; do
            chmod u+w "$pty"
            patchelf --add-rpath ${lib.getLib pkgs.stdenv.cc.cc}/lib "$pty"
          done
        '';
      }
    );
  };

  # The desktop app always starts its own backend, and 0.1.0 refuses to start
  # one on a data directory the background server owns, so the app gets its
  # own home and reaches every server, this host's included, as a connection.
  desktopHome = "${home}/.t3-desktop";
  # symlinkJoin bakes postBuild into buildCommand, so the wrap appends there.
  t3codeDesktop = t3code.overrideAttrs (old: {
    buildCommand = old.buildCommand + ''
      wrapProgram "$out/bin/t3code-desktop" --set-default T3CODE_HOME ${desktopHome}
    '' + lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
      # lndir links the bundle's executable to the unwrapped bin/.
      for exe in "$out"/Applications/*.app/Contents/MacOS/*; do
        ln -sfn ../../../../bin/t3code-desktop "$exe"
      done
    '';
  });

  port = 3773;
  httpsPort = 8773;

  # Imports Claude Code CLI sessions into the server as their transcripts
  # change, for both accounts.
  cliSyncArgs = [
    (lib.getExe pkgs.nodejs)
    "${./t3code-cli-sync.mjs}"
    (lib.getExe' t3code "t3")
    "${config.xdg.stateHome}/t3code-cli-sync"
    "${home}/.claude"
    "${home}/.claude-pulse"
  ];

  # The server only binds loopback; tailnet clients reach it through Tailscale
  # Serve HTTPS, which the mobile app and app.t3.codes require anyway. 443 is
  # CouchDB's on the mac (obsidian-livesync-serve.nix), so t3 gets its own
  # port. `t3 serve --tailscale-serve` is not used: it edits the serve config
  # itself, and a stray `tailscale serve` on 443 has already broken LiveSync
  # once.
  serveArgs = [
    "${pkgs.tailscale}/bin/tailscale"
    "serve"
    "--bg"
    "--https=${toString httpsPort}"
    "http://127.0.0.1:${toString port}"
  ];

  serverArgs = [
    (lib.getExe' t3code "t3")
    "serve"
    "--host"
    "127.0.0.1"
    "--port"
    (toString port)
    "${home}/Developer"
  ];

  # Provider CLIs (claude, gh, git) must resolve from a service environment
  # that has no login shell behind it.
  path = lib.concatStringsSep ":" [
    "${config.home.profileDirectory}/bin"
    "/run/current-system/sw/bin"
    "/usr/bin"
    "/bin"
  ];

  deviceHub = lib.concatMapStrings (
    key: " | if has(\"${key}\") then . else .${key} = true end"
  ) [ "enableDeviceSupport" "deviceOnboardingCompleted" "enableAgentDeviceAccess" ];
in
{
  home.packages = [ t3codeDesktop ];

  # settings.json is the server's own runtime file (it watches it and writes
  # UI changes back), so only the provider instances are merged in. The
  # device hub (iOS simulators, via xcrun) is switched on once on the mac and
  # left to the UI after that.
  home.activation.t3codeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    for dir in "${home}/.t3/userdata" "${desktopHome}/userdata"; do
      run mkdir -p "$dir"
      [ -s "$dir/settings.json" ] || echo '{}' > "$dir/settings.json"
      run ${lib.getExe pkgs.jq} --slurpfile add ${providerInstances} \
        '.providerInstances = ((.providerInstances // {}) * $add[0])${lib.optionalString pkgs.stdenv.hostPlatform.isDarwin deviceHub}' \
        "$dir/settings.json" > "$dir/settings.json.hm-tmp"
      run mv "$dir/settings.json.hm-tmp" "$dir/settings.json"
    done
    dir="${desktopHome}/userdata"
    if [ ! -e "$dir/connection-catalog.json" ]; then
      run install -m 600 ${savedEnvironments} "$dir/saved-environments.json"
    fi
  '';

  xdg.mimeApps.associations.added = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
    "x-scheme-handler/t3code" = [ "com.t3tools.T3Code.desktop" ];
  };

  launchd.agents = lib.optionalAttrs (isServer && pkgs.stdenv.hostPlatform.isDarwin) {
    t3code = {
      enable = true;
      config = {
        ProgramArguments = serverArgs;
        RunAtLoad = true;
        KeepAlive = true;
        WorkingDirectory = home;
        EnvironmentVariables = {
          PATH = path;
          SHELL = lib.getExe pkgs.fish;
        };
        StandardOutPath = "${home}/Library/Logs/t3code.log";
        StandardErrorPath = "${home}/Library/Logs/t3code.log";
      };
    };

    t3code-cli-sync = {
      enable = true;
      config = {
        ProgramArguments = cliSyncArgs;
        RunAtLoad = true;
        KeepAlive = true;
        ThrottleInterval = 30;
        StandardOutPath = "${home}/Library/Logs/t3code-cli-sync.log";
        StandardErrorPath = "${home}/Library/Logs/t3code-cli-sync.log";
      };
    };

    # Reasserted every five minutes for the same reason as the LiveSync
    # mapping: any dev-session `tailscale serve` can replace it.
    t3code-serve = {
      enable = true;
      config = {
        ProgramArguments = serveArgs;
        RunAtLoad = true;
        StartInterval = 300;
        StandardOutPath = "${home}/Library/Logs/t3code-serve.log";
        StandardErrorPath = "${home}/Library/Logs/t3code-serve.log";
      };
    };
  };

  systemd.user = lib.optionalAttrs (isServer && pkgs.stdenv.hostPlatform.isLinux) {
    services.t3code = {
      Unit = {
        Description = "T3 Code server";
        After = [ "network-online.target" ];
      };
      Service = {
        ExecStart = lib.escapeShellArgs serverArgs;
        WorkingDirectory = home;
        Environment = [
          "PATH=${path}"
          "SHELL=${lib.getExe pkgs.fish}"
        ];
        Restart = "always";
        RestartSec = 5;
      };
      Install.WantedBy = [ "default.target" ];
    };

    services.t3code-cli-sync = {
      Unit = {
        Description = "Import Claude Code CLI sessions into T3 Code";
        After = [ "t3code.service" ];
        BindsTo = [ "t3code.service" ];
      };
      Service = {
        ExecStart = lib.escapeShellArgs cliSyncArgs;
        Restart = "always";
        RestartSec = 30;
      };
      Install.WantedBy = [ "default.target" ];
    };

    # Needs tailscale operator rights, which modules/nixos/mixins/desktop/hyprland.nix
    # grants kyandesutter.
    services.t3code-serve = {
      Unit.Description = "Publish the T3 Code server over Tailscale Serve";
      Service = {
        Type = "oneshot";
        ExecStart = lib.escapeShellArgs serveArgs;
      };
    };
    timers.t3code-serve = {
      Timer = {
        OnStartupSec = 10;
        OnUnitActiveSec = 300;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
