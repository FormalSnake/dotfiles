{ pkgs, ... }:
{
  # — Alt-Tab window switcher (Quickshell) —
  #
  # A classic hold-to-cycle window switcher for Hyprland, written as a tiny
  # standalone Quickshell config (separate from the caelestia shell instance).
  #
  # How it works:
  #   • The es layout remaps left Alt to AltGr (lv3:lalt_switch), which Hyprland
  #     sees as the MOD5 modifier. Two Hyprland binds (in hyprland.lua) fire the
  #     `alttab:next` / `alttab:prev` global shortcuts on the FIRST press of
  #     MOD5+Tab / MOD5+SHIFT+Tab.
  #   • On that trigger this Quickshell instance fetches the window list
  #     (`hyprctl clients -j`, sorted by focusHistoryID → most-recently-used),
  #     pops an overlay layer-surface and takes EXCLUSIVE keyboard focus. From
  #     then on Quickshell itself handles every Tab / Shift+Tab (cycle), Escape
  #     (cancel), Enter (commit) and — crucially — the RELEASE of AltGr, which
  #     commits the selection (`hyprctl dispatch focuswindow address:…`). Because
  #     the surface grabs the keyboard while AltGr is physically held, Wayland
  #     delivers the release event to it.
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
      Component.onCompleted: Hyprland.refreshToplevels()

      function begin(dir) {
        if (root.open) { root.step(dir); return; }
        root.pendingDir = dir;
        root.entries = [];
        root.index = 0;
        root.pendingCommit = false;
        // Open (and grab the keyboard) IMMEDIATELY, before fetching the window
        // list. Otherwise the grab only arms after the `hyprctl clients`
        // subprocess returns and the window maps, and a fast tap-and-release
        // lands in that gap — the release leaks to Hyprland, which (in lua mode)
        // won't act on a modifier release, so the overlay gets stuck open.
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

      LazyLoader {
        active: root.open

        PanelWindow {
          id: win
          anchors { top: true; bottom: true; left: true; right: true }
          color: "transparent"
          exclusionMode: ExclusionMode.Ignore
          WlrLayershell.layer: WlrLayer.Overlay
          WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
          WlrLayershell.namespace: "alttab"

          // Subtle dim behind the panel.
          Rectangle { anchors.fill: parent; color: "#66000000" }

          FocusScope {
            anchors.fill: parent
            focus: true
            Component.onCompleted: forceActiveFocus()

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
              color: "#1e1e2e"          // base
              border.color: "#cba6f7"   // mauve
              border.width: 2
              implicitWidth: Math.min(parent.width - 80, col.implicitWidth + 32)
              implicitHeight: col.implicitHeight + 32

              Column {
                id: col
                anchors.centerIn: parent
                spacing: 12

                Row {
                  id: previews
                  spacing: 12
                  anchors.horizontalCenter: parent.horizontalCenter

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
                        color: cell.index === root.index ? "#585b70" : "#00000000" // surface2 / clear
                        border.color: cell.index === root.index ? "#cba6f7" : "#00000000"
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
                  color: "#cdd6f4"          // text
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
