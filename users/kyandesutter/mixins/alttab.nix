{ config, lib, pkgs, inputs, ... }:
let
  # Build-time FALLBACK palette. The alttab colours primarily follow noctalia's
  # live matugen (wallpaper-derived) palette via a JSON file the QML watches at
  # runtime (see below + mixins/noctalia.nix's `alttab` user template). When that
  # file is missing or unparseable (e.g. before noctalia has rendered its first
  # palette, or a malformed write) the QML falls back to these catppuccin values,
  # baked here from the globally-active flavor — same source jankyborders uses.
  # palette.json is `<flavor>.colors.<name>.hex` ("#rrggbb").
  palette =
    (lib.importJSON
      "${inputs.catppuccin.packages.${pkgs.stdenv.hostPlatform.system}.palette}/palette.json")
    .${config.catppuccin.flavor}.colors;

  # Fallbacks mirror the previously-hardcoded mocha literals 1:1:
  #   base #1e1e2e, mauve #cba6f7, surface2 #585b70, text #cdd6f4.
  fbBase = palette.base.hex; # panel background
  fbAccent = palette.mauve.hex; # panel border + selected-cell border
  fbSelected = palette.surface2.hex; # selected-cell fill
  fbText = palette.text.hex; # title text
in
{
  # — Alt-Tab window switcher (Quickshell) —
  #
  # A classic hold-to-cycle window switcher for Hyprland, written as a tiny
  # standalone Quickshell config (noctalia, the desktop shell, is native C++ and
  # not Quickshell-based, so this is the only Quickshell instance in the session).
  #
  # How it works:
  #   • Hyprland binds (in hyprland.lua) fire the `alttab:next` / `alttab:prev`
  #     global shortcuts on the FIRST press of Alt+Tab / Alt+SHIFT+Tab. They are
  #     bound on both plain left Alt (ALT modifier) and the es layout's AltGr
  #     (MOD5), so either key opens the switcher.
  #   • On that trigger this Quickshell instance fetches the window list
  #     (`hyprctl clients -j`, sorted by focusHistoryID → most-recently-used),
  #     pops an overlay layer-surface and takes EXCLUSIVE keyboard focus. From
  #     then on Quickshell itself handles every Tab / Shift+Tab (cycle), Escape
  #     (cancel), Enter (commit) and — crucially — the RELEASE of Alt or AltGr,
  #     which commits the selection (`hyprctl dispatch focuswindow address:…`).
  #     Because the surface grabs the keyboard while the modifier is physically
  #     held, Wayland delivers the release event to it.
  #   • Each entry shows a live window preview via ScreencopyView, falling back
  #     to the app icon when no frame is available (e.g. windows on another,
  #     unrendered workspace).
  #
  # The instance is launched from hyprland.lua's hyprland.start block (so it
  # inherits Hyprland's Wayland env) as `qs -c alttab`, which resolves to the
  # config written below at ~/.config/quickshell/alttab/.
  home.packages = [ pkgs.quickshell ];

  xdg.configFile."quickshell/alttab/shell.qml".text = ''
    import QtQuick
    import Quickshell
    import Quickshell.Io
    import Quickshell.Wayland
    import Quickshell.Hyprland

    ShellRoot {
      id: root

      // Window list for the current switch: array of
      // { address, title, cls, toplevel } sorted most-recently-used first.
      property var entries: []
      property int index: 0
      property bool open: false
      property int pendingDir: 1
      // Set when AltGr is released before the window list has loaded (a very fast
      // tap); the commit then happens as soon as the list arrives.
      property bool pendingCommit: false

      // — Dynamic theming —
      // Colours follow noctalia's live matugen palette, written by noctalia into
      // ~/.cache/noctalia/alttab-colors.json (the `alttab` user template — see
      // mixins/noctalia.nix). The FileView below watches that file and parses it
      // into these properties. They are INITIALISED to the catppuccin fallback
      // (baked at build time from config.catppuccin.flavor, interpolated by Nix),
      // so the switcher is themed even before noctalia renders its first palette
      // or if the file is ever missing/malformed.
      property string cBase: "${fbBase}"
      property string cAccent: "${fbAccent}"
      property string cSelected: "${fbSelected}"
      property string cText: "${fbText}"

      // Parse the runtime palette JSON, overriding each colour only when present
      // and truthy. Any failure (file absent, unreadable, invalid JSON, missing
      // keys) leaves the catppuccin fallbacks untouched.
      function applyColors() {
        var raw = colorsFile.text();
        if (!raw || raw.length === 0) return;
        var c;
        try { c = JSON.parse(raw); } catch (e) { return; }
        if (!c) return;
        if (c.base) root.cBase = c.base;
        if (c.accent) root.cAccent = c.accent;
        if (c.selected) root.cSelected = c.selected;
        if (c.text) root.cText = c.text;
      }

      FileView {
        id: colorsFile
        path: "${config.home.homeDirectory}/.cache/noctalia/alttab-colors.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.applyColors()
        // onLoadFailed (missing file etc.) intentionally unhandled: the baked
        // catppuccin fallbacks already in cBase/cAccent/cSelected/cText stand.
      }

      // Resolve a Hyprland window address to its Wayland Toplevel handle, which
      // ScreencopyView uses as a capture source. `hyprctl clients` reports
      // addresses WITH a 0x prefix; Hyprland.toplevels reports them WITHOUT, so
      // normalise both before comparing.
      function waylandFor(address) {
        var want = address.replace(/^0x/, "");
        var tls = Hyprland.toplevels.values;
        for (var i = 0; i < tls.length; i++) {
          if (tls[i].address.replace(/^0x/, "") === want)
            return tls[i].wayland;
        }
        return null;
      }

      // Icon name for a window class, via the desktop entry then a lowercased
      // class guess, then a generic fallback.
      function iconFor(cls) {
        var entry = cls ? DesktopEntries.heuristicLookup(cls) : null;
        var name = (entry && entry.icon) ? entry.icon : (cls ? cls.toLowerCase() : "");
        return Quickshell.iconPath(name, "application-x-executable");
      }

      // Hyprland.toplevels stays empty until refreshToplevels() is called, and
      // it is the only source of the Wayland handles ScreencopyView needs. Prime
      // it at startup (and again per-open) so the window→handle map is populated.
      Component.onCompleted: { Hyprland.refreshToplevels(); root.applyColors(); }

      function begin(dir) {
        if (root.open) { root.step(dir); return; }
        root.pendingDir = dir;
        root.entries = [];
        root.index = 0;
        root.pendingCommit = false;
        // Map the (already-built) overlay and grab the keyboard IMMEDIATELY,
        // before fetching the window list. The surface is kept alive from
        // startup (see PanelWindow below), so this only re-maps it — the
        // exclusive grab arms within a frame, fast enough to catch even a quick
        // tap-and-release. (If the grab armed only after `hyprctl clients`
        // returned and the tree was built, a fast tap would land in that gap;
        // the release would leak to Hyprland, which in lua mode ignores a
        // modifier release, leaving the overlay stuck open.)
        root.open = true;
        Hyprland.refreshToplevels();
        clientsProc.running = true; // fills entries in parallel
      }

      function step(delta) {
        if (root.entries.length === 0) return;
        var n = root.entries.length;
        root.index = ((root.index + delta) % n + n) % n;
      }

      function commit() {
        if (!root.open) return;
        // Released before the list loaded — defer until clientsProc fills it.
        if (root.entries.length === 0) { root.pendingCommit = true; return; }
        focusProc.focus(root.entries[root.index].address);
        root.cancel();
      }

      function cancel() {
        root.open = false;
        root.pendingCommit = false;
      }

      GlobalShortcut {
        appid: "alttab"
        name: "next"
        onPressed: root.begin(1)
      }

      GlobalShortcut {
        appid: "alttab"
        name: "prev"
        onPressed: root.begin(-1)
      }

      // Focus a window by address. This Hyprland runs in lua mode, where the
      // legacy `dispatch focuswindow address:…` syntax is rejected (it is parsed
      // as lua). The lua dispatcher takes a window selector instead:
      //   hl.dsp.focus({ window = "address:0x…" })
      // which focuses the window and switches to its workspace if needed.
      Process {
        id: focusProc
        function focus(addr) {
          command = ["hyprctl", "dispatch",
                     "hl.dsp.focus({window=\"address:" + addr + "\"})"];
          running = true;
        }
      }

      // Fetch the window list (the overlay is already open by this point).
      Process {
        id: clientsProc
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
          onStreamFinished: {
            if (!root.open) return; // cancelled before the list arrived
            var list = [];
            try { list = JSON.parse(this.text); } catch (e) { list = []; }
            list = list.filter(function (c) {
              return c.mapped && c.title && c.title.length > 0;
            });
            // focusHistoryID: 0 = currently focused, 1 = previous, …
            list.sort(function (a, b) { return a.focusHistoryID - b.focusHistoryID; });

            var out = [];
            for (var i = 0; i < list.length; i++) {
              out.push({
                address: list[i].address,
                title: list[i].title,
                cls: list[i]["class"],
                toplevel: root.waylandFor(list[i].address)
              });
            }
            root.entries = out;
            if (out.length === 0) { root.cancel(); return; }

            // 'next' starts on the previously-focused window (classic single
            // tap-and-release → previous window); 'prev' starts on the last.
            root.index = root.pendingDir > 0 ? Math.min(1, out.length - 1) : out.length - 1;
            // If AltGr was already released before the list arrived, commit now.
            if (root.pendingCommit) root.commit();
          }
        }
      }

      // Build the overlay surface ONCE at startup (active: true) and keep it
      // alive; map it only while a switch is in progress (visible: root.open).
      // Re-mapping an already-built surface arms the exclusive keyboard grab in
      // ~a frame, whereas the old LazyLoader rebuilt the whole tree on every
      // open — that construction latency was wide enough for a fast
      // tap-and-release to land before the grab armed, leaking the release to
      // Hyprland and leaving the overlay stuck open.
      LazyLoader {
        active: true

        PanelWindow {
          id: win
          visible: root.open
          anchors { top: true; bottom: true; left: true; right: true }
          color: "transparent"
          exclusionMode: ExclusionMode.Ignore
          WlrLayershell.layer: WlrLayer.Overlay
          // Only hold the exclusive keyboard grab while actually switching,
          // otherwise the always-present surface would swallow all keyboard
          // input. (When hidden the surface is unmapped, but gate the focus
          // mode too as a belt-and-braces guard.)
          WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
          WlrLayershell.namespace: "alttab"

          // Subtle dim behind the panel.
          Rectangle { anchors.fill: parent; color: "#66000000" }

          FocusScope {
            id: scope
            anchors.fill: parent
            focus: true
            Component.onCompleted: forceActiveFocus()

            // The surface is built once at startup, so onCompleted fires while
            // it is still hidden. Re-grab the keyboard every time the overlay is
            // actually shown — otherwise the FocusScope wouldn't hold focus and
            // Tab / Escape / the AltGr release would never reach it.
            Connections {
              target: win
              function onVisibleChanged() {
                if (win.visible) scope.forceActiveFocus();
              }
            }

            Keys.onPressed: function (e) {
              if (e.key === Qt.Key_Tab) {
                root.step((e.modifiers & Qt.ShiftModifier) ? -1 : 1);
                e.accepted = true;
              } else if (e.key === Qt.Key_Backtab) {
                root.step(-1);
                e.accepted = true;
              } else if (e.key === Qt.Key_Escape) {
                root.cancel();
                e.accepted = true;
              } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                root.commit();
                e.accepted = true;
              }
            }

            // Releasing AltGr (left Alt, remapped) commits the selection.
            Keys.onReleased: function (e) {
              if (e.isAutoRepeat) return;
              if (e.key === Qt.Key_AltGr || e.key === Qt.Key_Alt) {
                root.commit();
                e.accepted = true;
              }
            }

            Rectangle {
              id: panel
              anchors.centerIn: parent
              visible: root.entries.length > 0 // hidden during the brief load
              radius: 10
              color: root.cBase         // base (matugen surface → catppuccin base)
              border.color: root.cAccent // accent (matugen primary → catppuccin mauve)
              border.width: 2
              implicitWidth: Math.min(parent.width - 80, col.implicitWidth + 32)
              implicitHeight: col.implicitHeight + 32

              Column {
                id: col
                anchors.centerIn: parent
                spacing: 12

                Grid {
                  id: previews
                  spacing: 12
                  anchors.horizontalCenter: parent.horizontalCenter
                  // Wrap previews into a grid so every window stays on-screen
                  // instead of overflowing a single row. Fit as many 200px-wide
                  // cells (212px incl. spacing) as the usable width allows —
                  // win.width minus the panel's ~112px screen-margin + padding —
                  // capped at the number of windows so few windows don't spread
                  // into a sparse grid.
                  columns: Math.max(1, Math.min(root.entries.length,
                           Math.floor((win.width - 100) / 212)))

                  Repeater {
                    model: root.entries
                    delegate: Item {
                      id: cell
                      required property var modelData
                      required property int index
                      width: 200
                      height: 130

                      Rectangle {
                        anchors.fill: parent
                        radius: 8
                        color: cell.index === root.index ? root.cSelected : "#00000000" // selected fill / clear
                        border.color: cell.index === root.index ? root.cAccent : "#00000000"
                        border.width: 2
                      }

                      // live:true lets the view set up and drive its own capture
                      // context (a single captureFrame() on completion races the
                      // context setup → "no recording context is ready"). Windows
                      // on inactive workspaces aren't rendered by Hyprland, so they
                      // produce no frame → hasContent stays false → icon fallback.
                      ScreencopyView {
                        id: shot
                        anchors.centerIn: parent
                        width: 184
                        height: 100
                        live: true
                        captureSource: cell.modelData.toplevel
                        visible: hasContent
                      }

                      Image {
                        anchors.centerIn: parent
                        width: 64
                        height: 64
                        visible: !shot.hasContent
                        source: root.iconFor(cell.modelData.cls)
                      }
                    }
                  }
                }

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  width: previews.width
                  horizontalAlignment: Text.AlignHCenter
                  elide: Text.ElideRight
                  color: root.cText         // text
                  font.family: "Geist"
                  font.pixelSize: 14
                  text: (root.entries.length > 0 && root.index < root.entries.length)
                        ? root.entries[root.index].title : ""
                }
              }
            }
          }
        }
      }
    }
  '';
}
