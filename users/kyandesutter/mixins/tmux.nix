{ config, lib, pkgs, ... }:
let
  src = "${config.home.homeDirectory}/.config/nix/users/kyandesutter/config/tmux";

  # Plugins are nix-managed store copies loaded by explicit run-shell lines at
  # the bottom of tmux.conf — no TPM, no vendored plugin trees in the repo.
  # The two agent plugins aren't in nixpkgs, so they're pinned here.
  agentNotifications = pkgs.tmuxPlugins.mkTmuxPlugin {
    pluginName = "tmux-agent-notifications";
    version = "0-unstable-2026-03-12";
    rtpFilePath = "claude-notifications.tmux";
    src = pkgs.fetchFromGitHub {
      owner = "kaiiserni";
      repo = "tmux-agent-notifications";
      rev = "d01787c666e0685a24db8556659a3a8db4c35592";
      hash = "sha256-jOrf6uJb7DiRm+xEDnw6MFtsA1JSObtvb3aRX/88mHU=";
    };
  };

  agentSidebarSrc = pkgs.fetchFromGitHub {
    owner = "hiroppy";
    repo = "tmux-agent-sidebar";
    rev = "2cff1cb955363394f8dd9c52d040d027536cfbd8";
    hash = "sha256-8a2fwEGPHzTF6zUNQTYVeKAanr8s4d2brfvPoKPAFjg=";
  };

  # The sidebar is a Rust binary; its .tmux entry script looks for it at
  # <plugin-dir>/bin/tmux-agent-sidebar (falling back to an interactive
  # install wizard we never want to trigger), so build it from the same rev
  # and link it into the plugin's bin/.
  agentSidebarBin = pkgs.rustPlatform.buildRustPackage {
    pname = "tmux-agent-sidebar";
    version = "0-unstable-2026-07-21";
    src = agentSidebarSrc;
    cargoHash = "sha256-j0/udhr2KBE33zLFGbHk66360YVWBBVnwjL4HtMgDPY=";
    # Upstream's test suite doesn't pass in the nix sandbox.
    doCheck = false;
  };

  agentSidebar = pkgs.tmuxPlugins.mkTmuxPlugin {
    pluginName = "tmux-agent-sidebar";
    version = "0-unstable-2026-07-21";
    src = agentSidebarSrc;
    postInstall = ''
      mkdir -p $out/share/tmux-plugins/tmux-agent-sidebar/bin
      ln -s ${agentSidebarBin}/bin/tmux-agent-sidebar \
        $out/share/tmux-plugins/tmux-agent-sidebar/bin/tmux-agent-sidebar
    '';
  };

  plugins = {
    tmux-resurrect = "${pkgs.tmuxPlugins.resurrect}/share/tmux-plugins/resurrect";
    tmux-continuum = "${pkgs.tmuxPlugins.continuum}/share/tmux-plugins/continuum";
    tmux-fzf = "${pkgs.tmuxPlugins.tmux-fzf}/share/tmux-plugins/tmux-fzf";
    tmux-agent-notifications = "${agentNotifications}/share/tmux-plugins/tmux-agent-notifications";
    tmux-agent-sidebar = "${agentSidebar}/share/tmux-plugins/tmux-agent-sidebar";
  };
in
{
  # tmux.conf and the theme stay live-editable (out-of-store symlinks into the
  # repo); the plugins/ subdir is store-managed.
  xdg.configFile = {
    "tmux/tmux.conf".source = config.lib.file.mkOutOfStoreSymlink "${src}/tmux.conf";
    "tmux/dynamic-theme.conf".source = config.lib.file.mkOutOfStoreSymlink "${src}/dynamic-theme.conf";
  } // lib.mapAttrs' (name: path: lib.nameValuePair "tmux/plugins/${name}" { source = path; }) plugins;
}
