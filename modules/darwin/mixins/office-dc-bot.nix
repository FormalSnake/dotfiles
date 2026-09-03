{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.kyan.officeDcBot;
  home = config.users.users.kyandesutter.home;

  rev = "6aa2ce2c6f0d77d80e5676cb558c8f038c29dca1";

  src = pkgs.fetchFromGitHub {
    owner = "FormalSnake";
    repo = "office-dc-bot";
    inherit rev;
    hash = "sha256-ihhlkgRQQgfPZFu0tOLkIa6x+Gtkh2AvrSTyMVEOA0A=";
  };

  # Tagged by revision so bumping `rev` above builds a new image instead of
  # reusing whatever the previous one left behind under a floating tag.
  tag = "office-dc-bot:${builtins.substring 0 12 rev}";

  launcher = pkgs.writeShellScript "office-dc-bot-launch" ''
    set -euo pipefail

    # OrbStack starts as a login item, so on a fresh boot this agent can win the
    # race. Exit non-zero and let launchd retry on ThrottleInterval.
    if ! docker info >/dev/null 2>&1; then
      echo "docker daemon not up yet, waiting" >&2
      exit 1
    fi

    if ! docker image inspect ${tag} >/dev/null 2>&1; then
      docker build -t ${tag} ${src}
    fi

    # --rm cannot clean up after a daemon restart or a hard power cut, and the
    # container name is fixed, so drop a leftover before claiming it again.
    docker rm -f office-dc-bot >/dev/null 2>&1 || true

    # The token stays on the host: --env-file is read by the CLI, so nothing
    # decrypted is bind-mounted into the container or written to the store.
    exec docker run --rm --name office-dc-bot \
      --env-file ${config.age.secrets."office-dc-bot".path} \
      -v office-dc-bot-data:/app/data \
      ${tag}
  '';
in
{
  options.kyan.officeDcBot.enable =
    lib.mkEnableOption "office Discord bot (Minecraft server status) in a local container";

  config = lib.mkIf cfg.enable {
    launchd.user.agents.office-dc-bot = {
      serviceConfig = {
        Label = "kyan.office-dc-bot";
        ProgramArguments = [ "${launcher}" ];
        EnvironmentVariables = {
          PATH = "/usr/local/bin:/opt/homebrew/bin:${home}/.orbstack/bin:/run/current-system/sw/bin:/usr/bin:/bin";
        };
        KeepAlive = true;
        RunAtLoad = true;
        ThrottleInterval = 60;
        StandardOutPath = "${home}/Library/Logs/office-dc-bot.log";
        StandardErrorPath = "${home}/Library/Logs/office-dc-bot.log";
      };
    };
  };
}
