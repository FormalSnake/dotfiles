{ pkgs, ... }:
let
  # The daemon half of thisisgm/omarchy-pods (GPL-3.0): kavishdevar/librepods'
  # Linux app, vendored and extended with the IPC surface FormalShell's AirPods
  # panel consumes. It publishes its whole state as one JSON line at
  # $XDG_STATE_HOME/librepods/status.json (written on change, removed on quit)
  # and takes control verbs (noise:*, ca:*, onebud:*, ear:*, adaptive:N) over
  # $XDG_RUNTIME_DIR/librepods.sock. Upstream librepods and pkgs.librepods have
  # none of that (no status file, no ca/onebud/adaptive verbs, no AirPods Pro 3
  # model map), which is why this is not the nixpkgs package.
  #
  # Requires BlueZ `Experimental = true` for the AAP L2CAP channel, already set
  # in modules/nixos/mixins/bluetooth.nix. AirPods must be paired first.
  omapods = pkgs.stdenv.mkDerivation (finalAttrs: {
    pname = "librepods-omapods";
    version = "1.0.2";

    src = pkgs.fetchFromGitHub {
      owner = "thisisgm";
      repo = "omarchy-pods";
      tag = "v${finalAttrs.version}";
      hash = "sha256-FeTfGNhooKrYxEun9j8IytIIg1hC1HgL8LBBM2bb/Ok=";
    };

    sourceRoot = "${finalAttrs.src.name}/daemon";

    buildInputs = [
      pkgs.libpulseaudio
      pkgs.openssl
      pkgs.qt6.qtbase
      pkgs.qt6.qtconnectivity
      pkgs.qt6.qtdeclarative
      pkgs.qt6.qttools
    ];

    nativeBuildInputs = [
      pkgs.cmake
      pkgs.pkg-config
      pkgs.qt6.wrapQtAppsHook
    ];

    meta = {
      homepage = "https://github.com/thisisgm/omarchy-pods";
      description = "librepods with the status-file and control-verb IPC FormalShell reads";
      license = pkgs.lib.licenses.gpl3;
      mainProgram = "librepods";
    };
  });
in
{
  # librepods-ctl lands on PATH for hand-driving the daemon while debugging.
  home.packages = [ omapods ];

  # Headless: no window, no tray icon. FormalShell's airpods panel is the UI;
  # the shell watches the status file and writes the socket directly. Unit
  # shape mirrors the daemon's own shipped librepods.service, including the
  # logging rule (the BLE advertisement debug line fires several times a
  # second otherwise). Restart is back now that there is no tray to quit
  # from: a crashed daemon deletes nothing, and its absent status file
  # already tells the shell the truth while it comes back.
  systemd.user.services.librepods = {
    Unit = {
      Description = "librepods AirPods daemon (omarchy-pods build, headless)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
    Service = {
      Type = "simple";
      Environment = "QT_LOGGING_RULES=openpods.debug=false";
      ExecStart = "${omapods}/bin/librepods --headless";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
}
