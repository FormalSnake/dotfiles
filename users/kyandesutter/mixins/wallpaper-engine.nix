{ config, lib, pkgs, ... }:
# Animated Wallpaper Engine scenes on the g815 niri/Noctalia desktop, without
# disturbing the wallpaper-derived matugen theming and without fighting the
# load-bearing power management. Design: docs/superpowers/specs/
# 2026-07-13-wallpaper-engine-noctalia-design.md.
#
# Noctalia stays the single source of truth: a WE scene appears in its picker as
# a *still* named `we-<workshopid>.png` — a full-resolution frame rendered from
# the scene (see weStill; falls back to the scene's own preview.*), so Noctalia
# renders and matugen-samples that still exactly as any other wallpaper — the
# theme pipeline is untouched. The rendered still matters because niri shows it
# (not the live engine) in the backdrop between workspaces, where the raw
# ~192px preview would upscale to a blurry smear. On every wallpaper pick the noctalia
# `wallpaper_changed` hook appends `wallpaper-engine-select` (exposed below via
# kyan.wallpaperEngine.selectCommand), which records the picked scene *per
# output* under ~/.cache/wallpaper-engine/outputs/<connector>. A user-service
# reconciler subscribes to that directory AND to /run/power/state (published by
# power-reconcile, see modules/nixos/mixins/power.nix) and enforces one rule:
# a single engine spans every output that has a scene selected, and only while
# we're not on battery. This mixin only *reads* /run/power/state — it touches
# none of the load-bearing power services.
#
# Steam workshop path for Wallpaper Engine (appid 431960).
let
  cacheDir = "wallpaper-engine";
  workshop = "$HOME/.steam/steam/steamapps/workshop/content/431960";
  noctalia = config.programs.noctalia.package;

  # Runs inside noctalia's systemd *user* service (limited PATH); self-contained
  # shell needing only coreutils. Records/clears the picked scene for one output.
  wallpaperEngineSelect = pkgs.writeShellApplication {
    name = "wallpaper-engine-select";
    text = ''
      outdir="''${XDG_CACHE_HOME:-$HOME/.cache}/${cacheDir}/outputs"
      mkdir -p "$outdir"
      path="''${NOCTALIA_WALLPAPER_PATH:-}"
      conn="''${NOCTALIA_WALLPAPER_CONNECTOR:-}"
      # Without a connector we can't target an engine output; nothing to do.
      [[ -n "$conn" ]] || exit 0
      base="$(basename "$path")"
      if [[ "$base" =~ ^we-([0-9]+)\. ]]; then
        printf '%s' "''${BASH_REMATCH[1]}" > "$outdir/$conn"
      else
        rm -f "$outdir/$conn"
      fi
    '';
  };

  # Long-lived reconciler. Watches the per-output selection dir and
  # /run/power/state via inotify and converges a single spanning engine to the
  # desired state. Runs in the main shell (process substitution, not a pipeline)
  # so the tracked engine PID persists across events.
  wallpaperEngineReconcile = pkgs.writeShellApplication {
    name = "wallpaper-engine-reconcile";
    runtimeInputs = [ pkgs.linux-wallpaperengine pkgs.inotify-tools pkgs.coreutils ];
    text = ''
      base="''${XDG_CACHE_HOME:-$HOME/.cache}/${cacheDir}"
      outdir="$base/outputs"
      fpsfile="$base/fps"
      powerstate="/run/power/state"
      mkdir -p "$outdir"

      engine_pid=""
      running_sig=""

      stop() {
        if [[ -n "$engine_pid" ]] && kill -0 "$engine_pid" 2>/dev/null; then
          kill "$engine_pid" 2>/dev/null || true
          wait "$engine_pid" 2>/dev/null || true
        fi
        engine_pid=""
        running_sig=""
      }

      # Builds the launch args (global ARGS) and a stable signature (global SIG)
      # from every output that has a scene selected, sorted by connector.
      build() {
        ARGS=()
        SIG=""
        shopt -s nullglob
        local raw=("$outdir"/*) files=() f conn id
        if (( ''${#raw[@]} )); then
          mapfile -t files < <(printf '%s\n' "''${raw[@]}" | sort)
        fi
        for f in "''${files[@]}"; do
          [[ -f "$f" ]] || continue
          conn="$(basename "$f")"
          id="$(cat "$f" 2>/dev/null || true)"
          [[ -n "$id" ]] || continue
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
        # Coalesce bursts (noctalia re-fires wallpaper_changed on hover-preview)
        # so we don't restart the GL engine on every event.
        while read -r -t 0.4 _; do :; done
        reconcile
      done < <(inotifywait -q -m -r -e close_write,create,moved_to,delete "$base" /run/power)
    '';
  };

  # Render a full-resolution still for a scene and drop it in the picker set as
  # we-<id>.png, replacing any stale we-<id>.* first. WE ships only a tiny
  # preview.* thumbnail (often a 192px square), and Noctalia shows that still in
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
  # sets the engine fps, then points every niri output at it via noctalia.
  weSet = pkgs.writeShellApplication {
    name = "we-set";
    runtimeInputs = [ noctalia pkgs.niri pkgs.jq pkgs.coreutils weStill ];
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

      mapfile -t conns < <(niri msg --json outputs | jq -r 'keys[]')
      if [[ ''${#conns[@]} -eq 0 ]]; then
        echo "no outputs reported by niri" >&2
        exit 1
      fi
      for c in "''${conns[@]}"; do
        noctalia msg wallpaper-set "$c" "$dest"
      done
      echo "applied $id to: ''${conns[*]}"
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
  # Exposed as a store-path command so noctalia.nix can append it to the
  # `wallpaper_changed` hook (that hook runs in a limited-PATH service, so it
  # references consumers by absolute store path — see flexokiScheme there).
  options.kyan.wallpaperEngine.selectCommand = lib.mkOption {
    type = lib.types.str;
    internal = true;
    readOnly = true;
    default = "${wallpaperEngineSelect}/bin/wallpaper-engine-select";
    description = "Command the noctalia wallpaper_changed hook runs to publish the selected Wallpaper Engine scene.";
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
        # it re-reads outputs/ on startup and relaunches the current scene, so a
        # logic change takes effect immediately instead of needing a manual
        # `systemctl --user restart`.
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
