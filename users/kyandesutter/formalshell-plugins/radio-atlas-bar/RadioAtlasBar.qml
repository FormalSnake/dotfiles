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

    implicitWidth: icon.width
    implicitHeight: icon.implicitHeight

    Icon {
        id: icon
        anchors.centerIn: parent
        name: "globe"
        color: root.playing ? Theme.color.primary : (root.cell ? root.cell.foreground : Theme.color.foreground)
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
