{ lib, ... }:
{
  # Local model server for the refine Claude Code plugin
  # (users/kyandesutter/claude/marketplace/plugins/refine). Models live in
  # ~/.ollama and are pulled imperatively: the plugin's `warm` subcommand
  # fetches the one named in its config.json.
  services.ollama.enable = true;

  # home-manager's agent runs as ProcessType Background, which macOS throttles
  # for CPU, I/O and GPU: measured 124 s model load and 15 tok/s against
  # 2.6 s and 40 tok/s for the same binary in the foreground.
  launchd.agents.ollama.config.ProcessType = lib.mkForce "Interactive";
}
