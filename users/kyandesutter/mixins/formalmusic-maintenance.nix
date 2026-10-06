{ config, lib, pkgs, inputs, ... }:
let
  # The weekly FormalMusic maintenance run: headless Claude Code with the
  # repo's maintenance/weekly.md as the prompt, in a clone that belongs to the
  # run alone (never the working copies in ~/Developer/formalmusic*). The run
  # itself keeps the clone on origin/main; the prompt is read from origin/main
  # so an edit to it takes effect on the next run without touching the tree.
  claude = inputs.claude-code-nix.packages.${pkgs.stdenv.hostPlatform.system}.default;
  clone = "${config.home.homeDirectory}/Developer/formalmusic-maintenance";

  # sudo -n comes from /run/wrappers (pam_ssh_agent_auth against the gcr
  # agent); nix, nixos-rebuild, systemd-run and dbus-run-session from the
  # system profile. cargo comes from the repo's `nix develop` shell.
  path = lib.concatStringsSep ":" [
    "/run/wrappers/bin"
    (lib.makeBinPath (with pkgs; [
      bash
      coreutils
      findutils
      gnugrep
      gnused
      gawk
      git
      gh
      openssh
      curl
      jq
      ripgrep
      libnotify
      procps
      deployE1504g
      claude
    ]))
    "/run/current-system/sw/bin"
  ];

  # e1504g is often off. The run calls this with --once while it waits, and
  # hands it to a transient unit when the e1504g is offline, since retrying
  # for 48 h would outlive the service's timeout. The rev pins the nix repo
  # commit the g815 was rebuilt from, so a later dirty tree never ships.
  deployE1504g = pkgs.writeShellApplication {
    name = "formalmusic-deploy-e1504g";
    runtimeInputs = with pkgs; [ coreutils git jq openssh libnotify ];
    text = ''
      rev=$1
      once=''${2:-}
      repo=$HOME/.config/nix
      export PATH=/run/wrappers/bin:$PATH:/run/current-system/sw/bin
      export SSH_AUTH_SOCK=''${SSH_AUTH_SOCK:-$XDG_RUNTIME_DIR/gcr/ssh}
      short=$(git -C "$repo" show "$rev:flake.lock" | jq -r '.nodes.formalmusic.locked.rev[0:7]')
      deadline=$(($(date +%s) + 48 * 3600))

      report() {
        echo "$1"
        [ "$once" = --once ] || notify-send -a FormalMusic -i es.canarycoders.formalmusic "FormalMusic maintenance" "$1"
      }

      while :; do
        if ssh -o BatchMode=yes -o ConnectTimeout=15 e1504g true; then
          if nixos-rebuild switch --flake "git+file://$repo?rev=$rev#e1504g" --target-host e1504g --sudo; then
            ssh -o BatchMode=yes e1504g 'git -C ~/.config/nix pull --ff-only' \
              || echo "e1504g: ~/.config/nix did not fast-forward"
            report "e1504g: formalmusic $short, rebuilt yes"
            exit 0
          fi
          report "e1504g: formalmusic $short, rebuilt no, nixos-rebuild failed"
          exit 1
        fi
        if [ "$once" = --once ]; then
          echo "e1504g: unreachable"
          exit 2
        fi
        if [ "$(date +%s)" -ge "$deadline" ]; then
          report "e1504g: formalmusic $short, rebuilt no, offline for 48 h, gave up"
          exit 1
        fi
        echo "e1504g: unreachable, next try in 30 min"
        sleep 1800
      done
    '';
  };

  # stream-json is the only print mode that shows the run as it goes; this
  # turns it into a readable log for the journal.
  journalFilter = ''
    if .type == "system" and .subtype == "init" then "session \(.session_id), model \(.model)"
    elif .type == "assistant" then
      .message.content[]
      | if .type == "text" then .text
        elif .type == "tool_use" then "> \(.name): \(.input.command // .input.file_path // .input.description // (.input | tostring))"
        else empty end
    elif .type == "user" then
      .message.content[]? | select(type == "object" and .type == "tool_result")
      | (.content | if type == "array" then map(.text? // "") | join("\n") else tostring end)
      | split("\n") | .[:40] | map("  " + .) | join("\n")
    elif .type == "result" then "result: \(.subtype), \(.num_turns) turns, \(.duration_ms / 1000 | floor) s\n\(.result // "")"
    else empty end
  '';

  run = pkgs.writeShellApplication {
    name = "formalmusic-maintenance";
    runtimeInputs = [ ];
    text = ''
      if [ ! -d ${clone}/.git ]; then
        git clone git@github.com:FormalSnake/formalmusic.git ${clone}
      fi
      cd ${clone}
      git fetch --quiet origin
      git show origin/main:maintenance/weekly.md \
        | claude -p \
            --model opus \
            --effort high \
            --permission-mode bypassPermissions \
            --name "formalmusic maintenance $(date +%F)" \
            --output-format stream-json \
            --verbose \
        | jq --unbuffered -r ${lib.escapeShellArg journalFilter}
    '';
  };
in
{
  home.packages = [ deployE1504g ];

  systemd.user.services.formalmusic-maintenance = {
    Unit = {
      Description = "FormalMusic weekly maintenance (headless Claude Code)";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe run;
      Environment = [
        "PATH=${path}"
        "SSH_AUTH_SOCK=%t/gcr/ssh"
      ];
      TimeoutStartSec = "6h";
    };
  };

  # Persistent, so a week spent booted into Windows runs it on the next
  # NixOS login.
  systemd.user.timers.formalmusic-maintenance = {
    Unit.Description = "FormalMusic weekly maintenance";
    Timer = {
      OnCalendar = "weekly";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
