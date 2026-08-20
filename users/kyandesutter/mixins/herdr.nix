{ config, lib, pkgs, inputs, ... }:
let
  flexoki = import ./flexoki/palette.nix;
  inherit (flexoki) base accents;

  herdr = inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # How long an agent may sit idle before herdr-reap quits it.
  idleMinutes = 90;

  # Finished agents idle for hours: the turn is over, but Claude Code and every
  # MCP server it spawned stay resident, and each one keeps a row in the agent
  # panel. This quits them and keeps the pane.
  #
  # Claude Code draws on the alternate screen and wipes it on exit, so the
  # conversation has to be captured with colour intact before the kill and
  # written back into the pane afterwards. The capture reaches as far as the
  # rendered screen and no further. Everything above it stays in Claude's own
  # transcript, which `claude --resume` in that pane reopens. The file copy
  # matters too: herdr's pane history does not survive a server restart
  # (experimental.pane_history is off).
  #
  # Idle time is tracked here rather than read from herdr: the API reports
  # state_change_seq, a counter, not a timestamp. Same status and same seq
  # across two runs means the agent has not moved, so its stamp carries over.
  # The focused pane is never reaped.
  reap = pkgs.writeShellApplication {
    name = "herdr-reap";
    runtimeInputs = [ herdr pkgs.jq pkgs.coreutils pkgs.gawk ];
    text = ''
      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/herdr-reap"
      state_file="$state_dir/state.json"
      archive_dir="$state_dir/transcripts"
      session_dir="$state_dir/sessions"
      max_idle=$(( ${toString idleMinutes} * 60 ))
      dry_run=0
      close_empty=0

      for arg in "$@"; do
        case "$arg" in
          --dry-run) dry_run=1 ;;
          --now) max_idle=0 ;;
          --close-empty) close_empty=1 ;;
          *) echo "usage: herdr-reap [--dry-run] [--now|--close-empty]" >&2; exit 2 ;;
        esac
      done

      # No session running: nothing to reap, and the timer must not log noise.
      agents=$(herdr agent list 2>/dev/null) || exit 0

      mkdir -p "$archive_dir"

      capture() {
        herdr pane read "$1" --source recent-unwrapped --lines 5000 --format ansi > "$2" || true
        # The capture ends mid-style; without a reset the last colour bleeds
        # into the prompt when the tail is written back.
        printf '\033[0m\n' >> "$2"
      }

      # A workspace nobody has an agent in is still a row in the sidebar. This
      # is hand-run, never scheduled (closing takes its panes with it).
      if [ "$close_empty" = 1 ]; then
        herdr workspace list | jq -r '.result.workspaces[] | [.workspace_id, .label] | @tsv' |
        while IFS=$'\t' read -r ws label; do
          if [ "$ws" = "''${HERDR_WORKSPACE_ID:-}" ]; then continue; fi
          panes=$(herdr pane list --workspace "$ws") || continue
          if jq -e '[.result.panes[] | select(.agent != null or .focused)] | length > 0' \
               <<<"$panes" >/dev/null; then
            continue
          fi

          # Anything in the foreground other than the pane's own shell is work
          # in progress (a dev server, a build, an editor).
          busy=0
          while read -r pane; do
            info=$(herdr pane process-info --pane "$pane") || { busy=1; break; }
            if jq -e '.result.process_info | .shell_pid as $s
                      | [.foreground_processes[] | select(.pid != $s)] | length > 0' \
                 <<<"$info" >/dev/null; then
              busy=1
              break
            fi
          done < <(jq -r '.result.panes[].pane_id' <<<"$panes")
          if [ "$busy" = 1 ]; then continue; fi

          if [ "$dry_run" = 1 ]; then
            echo "would close workspace $ws ($label)"
            continue
          fi

          while read -r pane; do
            capture "$pane" "$archive_dir/$(date +%Y%m%d-%H%M%S)-closed-''${pane//:/-}.txt"
          done < <(jq -r '.result.panes[].pane_id' <<<"$panes")
          if ! herdr workspace close "$ws" >/dev/null; then
            echo "could not close workspace $ws ($label)" >&2
            continue
          fi
          echo "closed workspace $ws ($label)"
        done
        exit 0
      fi

      [ -f "$state_file" ] || echo '{}' > "$state_file"
      now=$(date +%s)

      state=$(jq --argjson agents "$agents" --argjson now "$now" '
        . as $prev
        | [ $agents.result.agents[]
            | select(.agent_status == "idle" and (.focused | not))
            | { key: .pane_id
              , value: { seq: .state_change_seq
                       , since: (if ($prev[.pane_id].seq // -1) == .state_change_seq
                                 then $prev[.pane_id].since
                                 else $now
                                 end)
                       }
              }
          ]
        | from_entries' "$state_file")
      printf '%s\n' "$state" > "$state_file"

      agent_gone() {
        ! herdr agent list 2>/dev/null \
          | jq -e --arg p "$1" '[.result.agents[] | select(.pane_id == $p)] | length > 0' >/dev/null
      }

      # An agent that kicked off a background command and then ended its turn
      # reports plain idle, the same as one that is finished, and killing it
      # would take that command down with it. Claude runs every Bash tool call
      # under a shell sourcing ~/.claude/shell-snapshots, so a command still
      # executing shows up as a process whose parent is one of those shells,
      # somewhere under this pane's claude. Long-running foreground calls are
      # caught by this too, but those already report working and never get here.
      pane_busy() {
        local root
        root=$(herdr pane process-info --pane "$1" 2>/dev/null \
          | jq -r '.result.process_info.foreground_processes[]
                   | select(.argv0 == "claude") | .pid' | head -1)
        [ -n "$root" ] || return 1
        ps -axo pid,ppid,command | awk -v root="$root" '
          NR > 1 { parent[$1] = $2; line[$1] = $0 }
          END {
            tree[root] = 1
            do {
              added = 0
              for (p in parent)
                if (!(p in tree) && (parent[p] in tree)) { tree[p] = 1; added = 1 }
            } while (added)
            for (p in tree) {
              q = parent[p]
              if (q in tree && line[q] ~ /shell-snapshots/) exit 0
            }
            exit 1
          }'
      }

      jq -r --argjson now "$now" --argjson max "$max_idle" \
        'to_entries[] | select($now - .value.since >= $max) | .key' <<<"$state" |
      while read -r pane; do
        title=$(jq -r --arg p "$pane" \
          '.result.agents[] | select(.pane_id == $p) | .terminal_title_stripped' <<<"$agents")

        if pane_busy "$pane"; then
          echo "skipping $pane ($title): a background command is still running"
          continue
        fi

        if [ "$dry_run" = 1 ]; then
          echo "would reap $pane ($title)"
          continue
        fi

        archive="$archive_dir/$(date +%Y%m%d-%H%M%S)-''${pane//:/-}.txt"
        # Only what is currently rendered can be read back, so zoom first. A
        # full window holds roughly twice the lines of one split, which is the
        # difference between catching the final message and catching its tail.
        herdr pane zoom "$pane" --on >/dev/null || true
        sleep 1
        capture "$pane" "$archive"
        herdr pane zoom "$pane" --off >/dev/null || true
        if [ ! -s "$archive" ]; then
          echo "could not archive $pane ($title); leaving it" >&2
          continue
        fi

        # Written by the SessionStart hook in ~/.claude/hooks, the only place
        # the pane and the Claude session id are known at the same time.
        session_file="$session_dir/''${pane//:/-}"
        {
          echo
          echo "herdr-reap: quit this agent at $(date '+%H:%M') after idling."
          if [ -f "$session_file" ]; then
            echo "Resume: claude --resume $(cat "$session_file")"
          fi
        } >> "$archive"

        # Two Ctrl+C is the exit path every supported agent honours, and the
        # first one clears any half-typed input that would swallow the second.
        for _ in 1 2 3; do
          herdr agent send-keys "$pane" ctrl+c ctrl+c >/dev/null || true
          sleep 3
          if agent_gone "$pane"; then break; fi
        done

        if agent_gone "$pane"; then
          herdr pane run "$pane" \
            "tail -n 200 $archive; echo 'Saved to: $archive'" >/dev/null || true
          rm -f "$session_file"
          jq --arg p "$pane" 'del(.[$p])' "$state_file" > "$state_file.new"
          mv "$state_file.new" "$state_file"
          echo "reaped $pane ($title)"
        else
          echo "$pane ($title) did not quit; leaving it" >&2
        fi
      done
    '';
  };
in
{
  # herdr: terminal workspace manager for AI coding agents.
  # Not in nixpkgs. Installed straight from the upstream flake (nixpkgs follows
  # ours, so it builds against this config's pkgs). Replaces the previous
  # imperative `curl … | sh` install that dropped a binary in ~/.local/bin.
  home.packages = [ herdr reap ];

  # Only the macbook runs a herdr server. The Linux hosts reach it over SSH, so
  # a timer there would have no session to talk to. `herdr-reap --now` is on
  # PATH everywhere for a manual sweep.
  launchd.agents = lib.optionalAttrs pkgs.stdenv.isDarwin {
    herdr-reap = {
      enable = true;
      config = {
        ProgramArguments = [ (lib.getExe reap) ];
        StartInterval = 300;
        WorkingDirectory = config.home.homeDirectory;
        EnvironmentVariables.PATH = lib.concatStringsSep ":" [
          "${config.home.profileDirectory}/bin"
          "/run/current-system/sw/bin"
          "/usr/bin"
          "/bin"
        ];
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/herdr-reap.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/herdr-reap.log";
      };
    };
  };

  # herdr ships a Nix flake but no home-manager module, so manage its config as
  # a plain-text TOML file. Read-only (lives in the nix store). Runtime state
  # (sockets, logs, session.json) is written to ~/.config/herdr separately and
  # is untouched by this.
  xdg.configFile."herdr/config.toml".text = ''
    onboarding = false

    # Pin Flexoki Dark via [theme.custom]. The "terminal" theme reads the host
    # terminal's palette through OSC colour queries at runtime. Those don't
    # round-trip over SSH/mosh, so remotely herdr fell back to defaults and
    # rendered raw-ANSI harsh. Static tokens sourced from the one Flexoki
    # palette (users/kyandesutter/mixins/flexoki/palette.nix) need no OSC, so
    # they hold up over SSH, and Flexoki Dark's soft off-white text on a lifted
    # b950 panel keeps contrast low. Base "catppuccin" only backstops any token
    # this override doesn't name.
    [theme]
    name = "catppuccin"

    [theme.custom]
    accent = "${accents.blue.d}"
    panel_bg = "${base.b950}"
    surface_dim = "${base.black}"
    surface0 = "${base.b900}"
    surface1 = "${base.b850}"
    overlay0 = "${base.b700}"
    overlay1 = "${base.b600}"
    text = "${base.b200}"
    subtext0 = "${base.b500}"
    mauve = "${accents.purple.d}"
    green = "${accents.green.d}"
    yellow = "${accents.yellow.d}"
    red = "${accents.red.d}"
    blue = "${accents.blue.d}"
    teal = "${accents.cyan.d}"
    peach = "${accents.orange.d}"

    [ui.toast]
    delivery = "system"

    [ui]
    show_agent_labels_on_pane_borders = true

    # Order the agent panel by who needs attention instead of by space, so
    # blocked and finished agents sort above the ones still working.
    agent_panel_sort = "priority"
  '';
}
