{ pkgs, ... }:
{
  # Godot 4 with C#/.NET support.
  #
  # `godot-mono` is the Mono/.NET editor build (binary on PATH: `godot4-mono`,
  # also `godot4.6-mono`). It is available on both x86_64-linux and
  # aarch64-darwin, so this mixin is cross-platform and imported from the base
  # home module — both hosts stay in sync.
  #
  # `dotnet-sdk_8` is the SDK Godot's C# project template targets (net8.0); it's
  # required to build the C# assemblies the editor compiles. Bump alongside
  # Godot's default target framework if a newer SDK is needed.
  home.packages = with pkgs; [
    godot-mono
    dotnet-sdk_8
  ];

  # Godot MCP server (Coding-Solo) — lets Claude Code launch the editor, run
  # projects, and capture debug output. Declared declaratively here; the
  # home-manager claude-code module materialises it into an HM-owned plugin
  # `.mcp.json`, so it does not fight the otherwise-imperative ~/.claude.json.
  # GODOT_PATH pins the server to the Mono build above instead of relying on its
  # PATH auto-detection.
  programs.claude-code.mcpServers.godot = {
    command = "${pkgs.godot-mcp}/bin/godot-mcp";
    env.GODOT_PATH = "${pkgs.godot-mono}/bin/godot4-mono";
  };
}
