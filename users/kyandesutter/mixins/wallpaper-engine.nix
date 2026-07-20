{ config, lib, pkgs, ... }:
# Animated Wallpaper Engine scenes on the g815 niri/DMS desktop, without
# disturbing the wallpaper-derived matugen theming and without fighting the
# load-bearing power management. Design: docs/superpowers/specs/
# 2026-07-13-wallpaper-engine-noctalia-design.md (written for Noctalia; the
# selection hook and wallpaper-apply call below were rewired onto DMS/matugen
# when Noctalia was replaced — see the notes on each below).
#
# DMS + matugen stay the single source of truth: a WE scene appears in the
# picker as a *still* named `we-<workshopid>.png` — a full-resolution frame
# rendered from the scene (see weStill; falls back to the scene's own
# preview.*), so DMS renders and matugen-samples that still exactly as any
# other wallpaper — the theme pipeline is untouched. The rendered still
# matters because niri shows it (not the live engine) in the backdrop between
# workspaces, where the raw ~192px preview would upscale to a blurry smear.
# On every re-theme matugen runs the `[templates.wallpaper-path]` template
# (dms.nix), whose post_hook feeds matugen's `{{image}}` straight to
# `wallpaper-engine-select` (exposed below via kyan.wallpaperEngine.selectCommand),
# which records/clears the picked scene id in a single selection file. A
# user-service reconciler subscribes to that file AND to /run/power/state
# (published by power-reconcile, see modules/nixos/mixins/power.nix) and
# enforces one rule: the engine spans every output niri currently reports,
# iff a scene is selected and we're not on battery. This mixin only *reads*
# /run/power/state — it touches none of the load-bearing power services.
#
# Per-output tracking is gone (this used to be keyed by Noctalia's
# $NOCTALIA_WALLPAPER_CONNECTOR): matugen's post_hook only fires for DMS's
# single theming "target monitor" wallpaper (SessionData.qml
# setMonitorWallpaper/matugenTargetMonitor, verified against
# AvengeMedia/DankMaterialShell@main), so there's no per-connector signal left
# to key off. This isn't a real capability loss in practice — weSet below
# already applied one scene identically to every connected output — so the
# reconciler now just mirrors that: one global selection, spanned across
# whatever outputs niri reports live at reconcile time.
#
# Steam workshop path for Wallpaper Engine (appid 431960).
let
  cacheDir = "wallpaper-engine";
  workshop = "$HOME/.steam/steam/steamapps/workshop/content/431960";
  dms = config.programs.dank-material-shell.package;

  # Invoked as the post_hook of the [templates.wallpaper-path] matugen
  # template (dms.nix), which passes the newly themed image path as $1 —
  # matugen's `{{image}}`, interpolated straight into the post_hook command
  # the same way the aura template feeds aura-repaint its colour arg. Runs
  # inside DMS's systemd *user* service (limited PATH); self-contained shell
  # needing only coreutils. Records/clears the picked scene id.
  wallpaperEngineSelect = pkgs.writeShellApplication {
    name = "wallpaper-engine-select";
    text = ''
      path="''${1:?usage: wallpaper-engine-select <image-path>}"
      selfile="''${XDG_CACHE_HOME:-$HOME/.cache}/${cacheDir}/selected"
      mkdir -p "$(dirname "$selfile")"
      base="$(basename "$path")"
      if [[ "$base" =~ ^we-([0-9]+)\. ]]; then
        printf '%s' "''${BASH_REMATCH[1]}" > "$selfile"
      else
        rm -f "$selfile"
      fi
    '';
  };

  # Long-lived reconciler. Watches the selection file and /run/power/state via
  # inotify and converges a single spanning engine to the desired state. Runs
  # in the main shell (process substitution, not a pipeline) so the tracked
  # engine PID persists across events.
  wallpaperEngineReconcile = pkgs.writeShellApplication {
    name = "wallpaper-engine-reconcile";
    runtimeInputs = [ pkgs.linux-wallpaperengine pkgs.inotify-tools pkgs.niri pkgs.jq pkgs.coreutils ];
    text = ''
      base="''${XDG_CACHE_HOME:-$HOME/.cache}/${cacheDir}"
      selfile="$base/selected"
      fpsfile="$base/fps"
      powerstate="/run/power/state"
      mkdir -p "$base"

      engine_pid=""
      running_sig=""

      stop() {
        if [[ -n "$engine_pid" ]] && kill -0 "$engine_pid" 2>/dev/null; then
          kill "$engine_pid" 2>/dev/null || true
          # linux-wallpaperengine intermittently hangs on SIGTERM during GL
          # teardown (prints "Stopping" then never exits). A bare `wait` here
          # would block this single-threaded loop forever, so every later
          # wallpaper change goes unreconciled. Give it up to 2s, then SIGKILL.
          for _ in $(seq 1 20); do
            kill -0 "$engine_pid" 2>/dev/null || break
            sleep 0.1
          done
          kill -9 "$engine_pid" 2>/dev/null || true
          wait "$engine_pid" 2>/dev/null || true
        fi
        engine_pid=""
        running_sig=""
      }

      # Builds the launch args (global ARGS) and a stable signature (global SIG)
      # spanning every output niri currently reports live, all pointed at the
      # one selected scene (no per-connector distinction — see the file header).
      build() {
        ARGS=()
        SIG=""
        local id="" conns=() conn=""
        [[ -r "$selfile" ]] && id="$(cat "$selfile" 2>/dev/null || true)"
        [[ -n "$id" ]] || return 0
        mapfile -t conns < <(niri msg --json outputs | jq -r 'keys[]' | sort)
        for conn in "''${conns[@]}"; do
          # --scaling is POSITIONAL: it binds to the *preceding* --screen-root, so
          # it must sit right after each --bg — a single trailing --scaling would
          # only reach the last output and the rest would fall back to the default
          # (fit) mode, letterboxing scenes whose aspect differs from the panel.
          ARGS+=(--screen-root "$conn" --bg "$id" --scaling fill)
          SIG+="$conn=$id;"
        done
      }

      reconcile() {
        local power="battery" fps="60"
        [[ -r "$powerstate" ]] && power="$(cat "$powerstate" 2>/dev/null || echo battery)"
        [[ -r "$fpsfile" ]] && fps="$(cat "$fpsfile" 2>/dev/null || echo 60)"
        build
        if [[ -n "$SIG" && "$power" != "battery" ]]; then
          local desired="$SIG@$fps"
          if [[ "$desired" != "$running_sig" ]]; then
            stop
            # --silent: a desktop background must not blast scene audio.
            linux-wallpaperengine "''${ARGS[@]}" --silent --fps "$fps" &
            engine_pid=$!
            running_sig="$desired"
          fi
        else
          stop
        fi
      }

      trap 'stop; exit 0' TERM INT

      reconcile
      while read -r _; do
        # Coalesce bursts (matugen can re-fire in quick succession, e.g. a
        # light/dark flip right after a wallpaper pick) so we don't restart
        # the GL engine on every event.
        while read -r -t 0.4 _; do :; done
        reconcile
      done < <(inotifywait -q -m -r -e close_write,create,moved_to,delete "$base" /run/power)
    '';
  };

  # Render a full-resolution still for a scene and drop it in the picker set as
  # we-<id>.png, replacing any stale we-<id>.* first. WE ships only a tiny
  # preview.* thumbnail (often a 192px square), and DMS shows that still in
  # niri's backdrop (place-within-backdrop) between workspaces — upscaling a
  # 192px thumbnail to the panel is the blurry, smeared "stretch" you see there,
  # while the live engine (bottom layer) can't be placed in the backdrop. So we
  # render the scene once at full res via linux-wallpaperengine's --screenshot
  # (its pywal path): --window mode renders OFF-SCREEN (no visible toplevel in
  # niri) but never self-exits, so we poll for the file, then kill it. The
  # rendered frame doubles as the matugen sample, so colours now come from the
  # actual scene rather than the thumbnail. Falls back to the raw preview if the
  # render yields nothing.
  weStill = pkgs.writeShellApplication {
    name = "we-still";
    runtimeInputs = [ pkgs.linux-wallpaperengine pkgs.coreutils ];
    text = ''
      id="''${1:-}"
      destdir="''${2:-}"
      geom="''${3:-2560x1600}"
      if [[ -z "$id" || -z "$destdir" ]]; then
        echo "usage: we-still <workshop-id> <destdir> [WxH]" >&2
        exit 1
      fi
      scene="${workshop}/$id"
      mkdir -p "$destdir"

      shopt -s nullglob nocaseglob
      old=("$destdir"/we-"$id".*)
      (( ''${#old[@]} )) && rm -f "''${old[@]}"

      dest="$destdir/we-$id.png"
      tmp="$destdir/.we-$id.tmp.png"
      rm -f "$tmp"
      echo "rendering still for $id ($geom)…" >&2
      linux-wallpaperengine --window "0x0x$geom" --bg "$id" --scaling fill \
        --silent --screenshot "$tmp" --screenshot-delay 30 >/dev/null 2>&1 &
      pid=$!
      ok=""
      # Scene load + shader compile take a couple of seconds; poll up to ~20s for
      # the screenshot to appear and stop growing, then stop the engine.
      for _ in $(seq 1 40); do
        sleep 0.5
        if [[ -s "$tmp" ]]; then
          s1="$(stat -c%s "$tmp")"; sleep 0.5; s2="$(stat -c%s "$tmp")"
          if [[ "$s1" == "$s2" ]]; then ok=1; break; fi
        fi
        kill -0 "$pid" 2>/dev/null || break
      done
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true

      if [[ -n "$ok" ]]; then
        mv -f "$tmp" "$dest"
        printf '%s' "$dest"
        exit 0
      fi
      rm -f "$tmp"

      # Fallback: the raw low-res preview is better than no wallpaper at all.
      previews=("$scene"/preview.*)
      if (( ''${#previews[@]} )); then
        fb="$destdir/we-$id.''${previews[0]##*.}"
        cp -f "''${previews[0]}" "$fb"
        echo "render failed; used raw preview for $id" >&2
        printf '%s' "$fb"
        exit 0
      fi
      echo "no still could be produced for $id" >&2
      exit 1
    '';
  };

  # List installed WE scenes to find an id. `we-list [search]` filters by title.
  weList = pkgs.writeShellApplication {
    name = "we-list";
    runtimeInputs = [ pkgs.jq pkgs.coreutils ];
    text = ''
      q="''${1:-}"
      shopt -s nullglob nocasematch
      for d in "${workshop}"/*/; do
        id="$(basename "$d")"
        pj="$d/project.json"
        [[ -f "$pj" ]] || continue
        title="$(jq -r '.title // "?"' "$pj" 2>/dev/null || echo '?')"
        type="$(jq -r '.type // "?"' "$pj" 2>/dev/null || echo '?')"
        [[ -z "$q" || "$title" == *"$q"* ]] || continue
        printf '%-12s  %-6s  %s\n' "$id" "$type" "$title"
      done
    '';
  };

  # Apply a scene to EVERY connected output in one command: `we-set <id> [fps]`.
  # Ensures the still is in the picker set (so theming samples it), optionally
  # sets the engine fps, then sets it as THE wallpaper via DMS's global
  # `wallpaper set` IPC target (docs/IPC.md). DMS's per-monitor `setFor` only
  # takes effect once per-monitor mode is enabled in Settings — off by
  # default here — so the plain global setter is what actually reaches every
  # output (and is what triggers the matugen re-theme that feeds the
  # reconciler; see the file header).
  weSet = pkgs.writeShellApplication {
    name = "we-set";
    runtimeInputs = [ dms pkgs.coreutils weStill ];
    text = ''
      id="''${1:-}"
      fps="''${2:-}"
      if [[ -z "$id" ]]; then
        echo "usage: we-set <workshop-id> [fps]   (find ids with: we-list)" >&2
        exit 1
      fi
      scene="${workshop}/$id"
      if [[ ! -d "$scene" ]]; then
        echo "scene $id not found under $scene (try: we-list)" >&2
        exit 1
      fi
      dest="$(we-still "$id" "$HOME/Pictures/Wallpapers/dark")"

      if [[ -n "$fps" ]]; then
        mkdir -p "$HOME/.cache/${cacheDir}"
        printf '%s' "$fps" > "$HOME/.cache/${cacheDir}/fps"
      fi

      dms ipc call wallpaper set "$dest"
      echo "applied $id"
    '';
  };

  # Add a scene's preview to the picker without applying it (choose light/dark).
  weAdd = pkgs.writeShellApplication {
    name = "we-add";
    runtimeInputs = [ pkgs.coreutils weStill ];
    text = ''
      id="''${1:-}"
      variant="''${2:-dark}"
      if [[ -z "$id" ]]; then
        echo "usage: we-add <workshop-id> [light|dark]" >&2
        exit 1
      fi
      scene="${workshop}/$id"
      if [[ ! -d "$scene" ]]; then
        echo "scene $id not found under $scene" >&2
        exit 1
      fi
      dest="$(we-still "$id" "$HOME/Pictures/Wallpapers/$variant")"
      echo "added $dest"
    '';
  };
in
{
  # Exposed as a store-path command so dms.nix can wire it into the
  # [templates.wallpaper-path] matugen post_hook (that hook runs in a
  # limited-PATH service, so it references consumers by absolute store path —
  # see auraRepaint there).
  options.kyan.wallpaperEngine.selectCommand = lib.mkOption {
    type = lib.types.str;
    internal = true;
    readOnly = true;
    default = "${wallpaperEngineSelect}/bin/wallpaper-engine-select";
    description = "Command the matugen wallpaper-path post_hook runs (with the new image path as $1) to publish the selected Wallpaper Engine scene.";
  };

  config = {
    home.packages = [
      pkgs.linux-wallpaperengine
      wallpaperEngineSelect
      weStill
      weList
      weSet
      weAdd
    ];

    systemd.user.services.wallpaper-engine = {
      Unit = {
        Description = "Wallpaper Engine reconciler (animated wallpaper, power-aware)";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
        # No keep-old: on a rebuild that changes the reconciler, let it restart —
        # it re-reads the selection file on startup and relaunches the current
        # scene, so a logic change takes effect immediately instead of needing
        # a manual `systemctl --user restart`.
      };
      Install.WantedBy = [ "graphical-session.target" ];
      Service = {
        ExecStart = "${wallpaperEngineReconcile}/bin/wallpaper-engine-reconcile";
        Restart = "on-failure";
        RestartSec = 2;
      };
    };
  };
}
