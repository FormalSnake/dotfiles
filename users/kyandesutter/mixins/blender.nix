{ lib, pkgs, ... }:
let
  # blender-mcp (ahujasid): an MCP server that drives Blender by talking to a
  # companion addon over a socket the addon opens on 127.0.0.1:9876. Not in
  # nixpkgs. The PyPI sdist carries both halves (the server, and the addon under
  # bundled/), which is why it is packaged from there rather than from GitHub:
  # the two handshake on ADDON_PROTOCOL_VERSION and refuse to talk when they
  # drift, so they have to come from one source.
  blender-mcp = pkgs.python3Packages.buildPythonApplication rec {
    pname = "blender-mcp";
    version = "1.9.1";
    pyproject = true;

    src = pkgs.fetchPypi {
      pname = "blender_mcp";
      inherit version;
      hash = "sha256-EIu5TXRUllajUtl+m+54TPgQ2J526c7YdPM3KQHx3hU=";
    };

    build-system = with pkgs.python3Packages; [ setuptools ];
    dependencies = with pkgs.python3Packages; [ mcp httpx ];

    # The sdist ships tests but no test dependency group; they also want a live
    # Blender on the other end of the socket.
    doCheck = false;
    pythonImportsCheck = [ "blender_mcp.server" ];

    meta.mainProgram = "blender-mcp";
  };

  # The addon half, taken out of the packaged server instead of being fetched
  # separately. Upstream's own installer (`blender-mcp install-addon`) copies
  # the same file to the same name; declaring it here means a nixpkgs blender
  # bump or a version bump above can't leave a stale copy behind.
  addonSource = "${blender-mcp}/${pkgs.python3.sitePackages}/blender_mcp/bundled/addon.py";

  # Blender reads user scripts from a per-version directory, so this path moves
  # with the packaged Blender rather than being pinned to a version by hand.
  addonDir = "Library/Application Support/Blender/${lib.versions.majorMinor pkgs.blender.version}/scripts/addons";
in
{
  home.packages = [ pkgs.blender ];

  home.file."${addonDir}/blender_mcp.py".source = addonSource;

  # Claude Code side. Same shape as the Godot MCP server (mixins/godot.nix):
  # declared here, materialised by the home-manager claude-code module into an
  # HM-owned plugin `.mcp.json` so it doesn't fight the imperative ~/.claude.json.
  #
  # Telemetry is on by default upstream and uploads prompts, generated code,
  # viewport screenshots and scene metadata. The server checks these env vars
  # before anything else, so setting one keeps the addon's own consent checkbox
  # from mattering.
  programs.claude-code.mcpServers.blender = {
    command = lib.getExe blender-mcp;
    env.DISABLE_TELEMETRY = "1";
  };
}
