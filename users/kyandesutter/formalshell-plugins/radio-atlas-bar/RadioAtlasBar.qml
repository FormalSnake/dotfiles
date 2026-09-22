// Portions from omarchy-radio-atlas (MIT, Copyright 2026 Akshar Patel)
import QtQuick
import qs.Core
import qs.Components
import qs.Plugins
import "../radio-atlas/lib"

// Radio Atlas on the bar: left click opens the overlay, middle click tunes a
// random station, right click stops, the wheel steps the volume. The plugin
// host (Surfaces/Bar/widgets/PluginBarModule.qml) is already a Cell, so this
// arms that cell's own pointer target, tooltip and open mark instead of
// nesting a second, padded Cell inside it.
Item {
    id: root

    readonly property Item cell: {
        var item = root.parent;
        while (item && item.contentAcross === undefined)
            item = item.parent;
        return item;
    }

    // The host's own PLUGIN ERROR caption. The host cell sizes itself off
    // every child it holds, hidden or not, so that caption would leave an
    // empty label's width beside the icon; this entry loaded, so it is
    // emptied.
    readonly property Item _errorLabel: {
        var box = root.parent ? root.parent.parent : null;
        if (!root.cell || !box)
            return null;
        for (var i = 0; i < box.children.length; i++) {
            var child = box.children[i];
            if (child !== root.parent && child.meta !== undefined)
                return child;
        }
        return null;
    }

    readonly property var overlay: PluginService.surfaces["plugin:radio-atlas"] || null
    readonly property bool playing: RadioAtlasService.running && !RadioAtlasService.paused

    // The tooltip's Text guesses its format, so markup in a title would
    // render, and a title is whatever the stream says it is.
    function _plain(text) {
        return String(text || "").replace(/[\u0000-\u001f\u007f]+/g, " ").slice(0, 160)
            .replace(/</g, "‹").replace(/>/g, "›");
    }

    readonly property string tooltip: RadioAtlasService.running
        ? (RadioAtlasService.error !== ""
            ? RadioAtlasService.error + ": "
            : (RadioAtlasService.paused ? "Radio paused: " : "Playing: "))
            + root._plain(RadioAtlasService.title || RadioAtlasService.station.name)
            + " · " + (RadioAtlasService.muted ? "muted" : RadioAtlasService.volume + "%")
        : "Open Radio Atlas"

    readonly property color _ink: root.cell ? root.cell.foreground : Theme.color.foreground
    readonly property color _dimInk: root.cell ? root.cell.dimForeground : Theme.color.mutedForeground

    // A hidden label takes no room in the lockup (a positioner skips it),
    // so idle is an icon-only cell like every builtin beside it.
    implicitWidth: lockup.implicitWidth
    implicitHeight: lockup.implicitHeight

    CellRow {
        id: lockup
        spacing: Theme.space.xs

        Icon {
            name: "globe"
            color: root.playing ? Theme.color.primary : root._ink
        }

        // The builtin now-playing cell's title: sans, marquee past 220 and
        // still otherwise. Paused or failed, it stays and dims. A vertical
        // bar leaves it to the tooltip.
        MarqueeText {
            visible: RadioAtlasService.label !== "" && !(root.cell && root.cell.vertical)
            text: RadioAtlasService.label
            color: root.playing ? root._ink : root._dimInk
            maxWidth: 220
        }
    }

    Binding {
        when: root._errorLabel !== null
        target: root._errorLabel
        property: "text"
        value: ""
    }

    Binding {
        when: root.cell !== null
        target: root.cell
        property: "interactive"
        value: true
    }

    Binding {
        when: root.cell !== null
        target: root.cell
        property: "acceptedButtons"
        value: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    }

    Binding {
        when: root.cell !== null
        target: root.cell
        property: "tooltipText"
        value: root.tooltip
    }

    Binding {
        when: root.cell !== null
        target: root.cell
        property: "panelOpen"
        value: root.overlay ? root.overlay.isOpen : false
    }

    Connections {
        target: root.cell

        function onClicked(mouse) {
            if (mouse.button === Qt.RightButton)
                RadioAtlasService.stop();
            else if (mouse.button === Qt.MiddleButton)
                RadioAtlasService.tuneRandom();
            else if (root.overlay)
                root.overlay.toggle();
        }

        function onWheeled(wheel) {
            RadioAtlasService.changeVolume(wheel.angleDelta.y > 0 ? 5 : -5);
            wheel.accepted = true;
        }
    }
}
