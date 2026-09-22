// Portions from omarchy-radio-atlas (MIT, Copyright 2026 Akshar Patel)
import QtQuick
import Quickshell.Io
import qs.Core
import qs.Components
import qs.Plugins
import "lib"
import "lib/RadioModel.js" as RadioModel

// Radio Atlas's window content: the globe beside a station list and the
// player. The overlay host owns the card, the scrim and the keyboard grab;
// this item sizes itself, and the card follows. Playback, saved stations and
// every Radio Browser request live in lib/RadioAtlasService.qml, shared with
// the bar cell.
Item {
    id: root

    readonly property var host: PluginService.surfaces["plugin:radio-atlas"] || null
    readonly property bool opened: root.host ? root.host.isOpen : false
    readonly property var _screen: root.host ? root.host.screen : null

    readonly property real preferredWidth: 1180
    readonly property real preferredHeight: 760
    readonly property real sidebarWidth: Math.min(390, root.width * 0.39)

    width: Math.round(Math.min(root.preferredWidth, (root._screen ? root._screen.width : root.preferredWidth) * 0.85))
    height: Math.round(Math.min(root.preferredHeight, (root._screen ? root._screen.height : root.preferredHeight) * 0.85))

    property var countries: []
    property var worldStations: []
    property var results: []
    property string mode: "world"
    property string activeCountryCode: ""
    property string activeCountryName: ""
    property bool helpVisible: false
    property bool outputsVisible: false
    property int outputCursor: 0
    property int selectedIndex: -1
    property var selectedStation: null
    property bool keyboardSelectionVisible: false

    property bool fetching: false
    property string fetchError: ""
    property int _fetchToken: 0
    readonly property int worldStationLimit: 5000
    property int worldExpansionMisses: 0
    property bool _expanding: false
    property bool _settingSearch: false

    readonly property var displayStations: root.mode === "favorites"
        ? RadioAtlasService.favorites
        : (root.mode === "recent" ? RadioAtlasService.recent : root.results)
    readonly property var currentGeoStations: RadioModel.mergeGeoStations(root.worldStations, root.displayStations, root.countries)
    readonly property bool remoteMode: root.mode !== "favorites" && root.mode !== "recent"
    readonly property var outputChoices: [{ id: "", label: "System default" }].concat(RadioAtlasService.outputs)
    readonly property string playingUuid: RadioAtlasService.station ? RadioAtlasService.station.uuid : ""

    readonly property var controlSections: [
        {
            title: "Keyboard",
            controls: [
                { keys: ["/"], action: "Search" },
                { keys: ["Up", "Down"], action: "Select station" },
                { keys: ["Enter"], action: "Play selected station" },
                { keys: ["Space"], action: "Play or pause" },
                { keys: ["R"], action: "Tune randomly" },
                { keys: ["F"], action: "Favorite selected station" },
                { keys: ["M"], action: "Mute or unmute" },
                { keys: ["+", "-"], action: "Change volume" },
                { keys: ["Esc"], action: "Back, clear, or close" },
                { keys: ["?"], action: "Show or hide controls" }
            ]
        },
        {
            title: "Mouse and bar",
            controls: [
                { input: "Drag or flick", action: "Spin globe" },
                { input: "Wheel on globe", action: "Zoom" },
                { input: "Click a signal", action: "Play station" },
                { input: "Click a country", action: "Browse stations" },
                { input: "Bar left click", action: "Open or close" },
                { input: "Bar middle click", action: "Tune randomly" },
                { input: "Bar right click", action: "Stop playback" },
                { input: "Bar wheel", action: "Change volume" }
            ]
        }
    ]

    // The host hands keyboard focus to its own backdrop on every open, and a
    // key only travels up from the focused item, never down into this one.
    readonly property Item _activeFocus: root.Window.activeFocusItem
    on_ActiveFocusChanged: Qt.callLater(root._claimFocus)

    function _inside(item) {
        for (var it = item; it; it = it.parent)
            if (it === root)
                return true;
        return false;
    }

    function _claimFocus() {
        if (!root.opened || root._inside(root.Window.activeFocusItem))
            return;
        root.forceActiveFocus();
    }

    onOpenedChanged: {
        if (root.opened) {
            root.worldExpansionMisses = 0;
            root.fetchError = "";
            if (root.worldStations.length === 0)
                root.showWorld();
            root.scheduleWorldExpansion(800);
            Qt.callLater(root._claimFocus);
        } else {
            root.helpVisible = false;
            root.outputsVisible = false;
            globe.stopKineticRotation(true);
            worldExpandTimer.stop();
        }
    }

    function close() {
        if (root.host)
            root.host.close();
    }

    function isHelpKey(event) {
        return event.key === Qt.Key_Question || event.text === "?"
            || (event.key === Qt.Key_Slash && (event.modifiers & Qt.ShiftModifier));
    }

    function toggleControls() {
        root.helpVisible = !root.helpVisible;
        root.outputsVisible = false;
        root.forceActiveFocus();
    }

    function toggleOutputs() {
        root.outputsVisible = !root.outputsVisible;
        if (!root.outputsVisible)
            return;
        var current = root.outputChoices.findIndex(o => o.id === RadioAtlasService.output);
        root.outputCursor = Math.max(0, current);
        RadioAtlasService.refreshOutputs();
    }

    function selectOutput(id) {
        RadioAtlasService.setOutput(id);
        root.outputsVisible = false;
    }

    function _setSearchText(text) {
        root._settingSearch = true;
        searchField.text = text;
        root._settingSearch = false;
    }

    function highlightStationCountry(station, focusGlobe) {
        if (!station) {
            root.activeCountryCode = "";
            root.activeCountryName = "";
            return;
        }
        root.activeCountryCode = String(station.countryCode || "").toUpperCase();
        root.activeCountryName = String(station.country || root.activeCountryCode);
        if (focusGlobe !== true)
            return;
        var latitude = Number(station.latitude);
        var longitude = Number(station.longitude);
        if (station.latitude !== null && station.longitude !== null && isFinite(latitude) && isFinite(longitude))
            globe.focusCoordinate(latitude, longitude);
        else if (root.activeCountryCode)
            globe.focusCountry(root.activeCountryCode);
    }

    function restorePlayingCountry(focusGlobe) {
        if (RadioAtlasService.running) {
            root.highlightStationCountry(RadioAtlasService.station, focusGlobe === true);
            return;
        }
        root.activeCountryCode = "";
        root.activeCountryName = "";
    }

    function setSelection(index, fromKeyboard) {
        root.keyboardSelectionVisible = fromKeyboard === true;
        var stations = root.displayStations;
        if (!Array.isArray(stations) || stations.length === 0 || index < 0) {
            root.selectedIndex = -1;
            root.selectedStation = null;
            return;
        }
        root.selectedIndex = Math.max(0, Math.min(stations.length - 1, index));
        root.selectedStation = stations[root.selectedIndex];
        stationList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
    }

    function moveSelection(delta) {
        var n = root.displayStations.length;
        if (n === 0)
            return;
        if (root.selectedIndex < 0)
            root.setSelection(delta < 0 ? n - 1 : 0, true);
        else
            root.setSelection((root.selectedIndex + delta + n) % n, true);
    }

    function setStationList(nextMode, stations) {
        root.mode = nextMode;
        if (root.remoteMode)
            root.results = stations;
        root.setSelection(stations.length > 0 ? 0 : -1);
    }

    function refreshLocalSelection() {
        if (root.remoteMode)
            return;
        var stations = root.displayStations;
        var preferred = root.selectedStation ? root.selectedStation.uuid : root.playingUuid;
        var index = preferred ? RadioModel.indexByUuid(stations, preferred) : -1;
        if (index < 0 && stations.length > 0)
            index = Math.min(Math.max(root.selectedIndex, 0), stations.length - 1);
        root.setSelection(index);
    }

    // Each request carries the token it was issued under; a mode change or
    // a newer request makes the answer to an older one stale.
    function _beginFetch() {
        root.fetching = true;
        root.fetchError = "";
        return ++root._fetchToken;
    }

    function _unavailable() {
        return root.displayStations.length > 0
            ? "Showing cached stations · Radio Browser is unavailable"
            : "Radio Browser is unavailable. Try again shortly.";
    }

    function showWorld(refresh) {
        searchDebounce.stop();
        root._setSearchText("");
        root.outputsVisible = false;
        root.restorePlayingCountry(false);
        RadioAtlasService.localError = "";
        root.setStationList("world", root.worldStations);
        if (refresh === false) {
            root.fetching = false;
            root._fetchToken++;
            return;
        }
        var token = root._beginFetch();
        RadioAtlasService.fetchWorld(rows => {
            if (rows)
                root.worldStations = RadioModel.mergeStations(root.worldStations, rows, root.worldStationLimit);
            if (token !== root._fetchToken)
                return;
            root.fetching = false;
            if (!rows) {
                root.fetchError = root._unavailable();
                return;
            }
            root.setStationList("world", root.worldStations);
            root.scheduleWorldExpansion(1200);
        });
    }

    function _showLocal(nextMode) {
        searchDebounce.stop();
        root._setSearchText("");
        root.outputsVisible = false;
        root._fetchToken++;
        root.fetching = false;
        root.fetchError = "";
        root.mode = nextMode;
        root.restorePlayingCountry(true);
        root.setSelection(root.displayStations.length > 0 ? 0 : -1);
    }

    function showFavorites() {
        root._showLocal("favorites");
    }

    function showRecent() {
        root._showLocal("recent");
    }

    function previewSearch(text) {
        var query = String(text || "").trim();
        if (!query) {
            root.showWorld();
            return false;
        }
        root.restorePlayingCountry(false);
        root.fetchError = "";
        root.setStationList("search", RadioModel.searchStations(root.worldStations, query));
        return true;
    }

    function search(text) {
        var query = String(text || "").trim();
        if (!root.previewSearch(query))
            return;
        var token = root._beginFetch();
        RadioAtlasService.search(query, rows => {
            if (token !== root._fetchToken || root.mode !== "search")
                return;
            root.fetching = false;
            if (!rows) {
                root.fetchError = root._unavailable();
                return;
            }
            root.setStationList("search", rows);
        });
    }

    function browseCountry(code, name) {
        var countryCode = String(code || "").toUpperCase();
        if (!/^[A-Z]{2}$/.test(countryCode))
            return;
        var countryName = String(name || "");
        if (!countryName) {
            for (var i = 0; i < root.countries.length; i++) {
                var properties = root.countries[i] && root.countries[i].properties;
                if (String(properties && properties.code || "").toUpperCase() === countryCode) {
                    countryName = String(properties.name || "");
                    break;
                }
            }
        }
        if (!countryName)
            countryName = countryCode;
        searchDebounce.stop();
        root.outputsVisible = false;
        var cached = RadioModel.stationsForCountry(root.worldStations, countryCode);
        root.worldStations = RadioModel.prioritizeStations(cached, root.worldStations, root.worldStationLimit);
        root.setStationList("country", cached);
        root.activeCountryCode = countryCode;
        root.activeCountryName = countryName;
        root._setSearchText(countryName);
        var token = root._beginFetch();
        RadioAtlasService.fetchCountry(countryCode, root.worldStations, rows => {
            if (token !== root._fetchToken || root.mode !== "country")
                return;
            root.fetching = false;
            if (!rows) {
                root.fetchError = root._unavailable();
                return;
            }
            var merged = RadioModel.mergeStations(root.results, rows, 500);
            root.worldStations = RadioModel.prioritizeStations(merged, root.worldStations, root.worldStationLimit);
            root.setStationList("country", merged);
        });
        root.forceActiveFocus();
    }

    function tuneRandom() {
        searchDebounce.stop();
        root._setSearchText("");
        root.outputsVisible = false;
        root.setStationList("random", []);
        root.restorePlayingCountry(false);
        root._beginFetch();
        RadioAtlasService.tuneRandom();
    }

    function activateMapStation(station) {
        var index = RadioModel.indexByUuid(root.displayStations, station.uuid);
        if (index < 0) {
            index = RadioModel.indexByUuid(root.worldStations, station.uuid);
            if (index < 0)
                return;
            root.showWorld(false);
        }
        root.setSelection(index);
        root.playSelected();
    }

    function playSelected() {
        var station = root.selectedStation;
        if (!station)
            return;
        root.highlightStationCountry(station, true);
        if (root.remoteMode)
            RadioAtlasService.play(station, RadioModel.stationWindow(root.displayStations, station.uuid, 500));
        else
            RadioAtlasService.playFromSaved(station, root.displayStations);
    }

    function playPause() {
        if (RadioAtlasService.running)
            RadioAtlasService.toggle();
        else
            root.playSelected();
    }

    function scheduleWorldExpansion(delay) {
        if (!root.opened || root.worldStations.length === 0
            || root.worldStations.length >= root.worldStationLimit || root.worldExpansionMisses >= 3)
            return;
        worldExpandTimer.interval = Math.max(500, Number(delay || 1600));
        worldExpandTimer.restart();
    }

    function emptyStateText() {
        if (root.fetchError)
            return root.fetchError;
        if (RadioAtlasService.localError)
            return RadioAtlasService.localError;
        if (root.mode === "favorites")
            return "No favorites yet. Select a station and press F.";
        if (root.mode === "recent")
            return "No listening history yet.";
        if (root.mode === "search")
            return "No stations match “" + String(searchField.text || "").trim() + "”.";
        if (root.mode === "country")
            return "No working stations found in " + (root.activeCountryName || "this country") + ".";
        return "No working stations found.";
    }

    function _key(event) {
        if (searchField.editing) {
            if (event.key === Qt.Key_Escape) {
                if (searchField.text !== "")
                    root.showWorld();
                else
                    root.forceActiveFocus();
                event.accepted = true;
            }
            return;
        }

        if (root.helpVisible) {
            if (event.key === Qt.Key_Escape || root.isHelpKey(event)) {
                root.toggleControls();
                event.accepted = true;
            }
            return;
        }

        if (root.outputsVisible) {
            var n = root.outputChoices.length;
            if (event.key === Qt.Key_Escape)
                root.outputsVisible = false;
            else if (event.key === Qt.Key_Up)
                root.outputCursor = (root.outputCursor - 1 + n) % n;
            else if (event.key === Qt.Key_Down)
                root.outputCursor = (root.outputCursor + 1) % n;
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
                root.selectOutput(root.outputChoices[root.outputCursor].id);
            else
                return;
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Escape) {
            if (searchField.text !== "")
                root.showWorld();
            else
                root.close();
        } else if (root.isHelpKey(event)) {
            root.toggleControls();
        } else if (event.key === Qt.Key_Slash) {
            searchField.forceFocus();
        } else if (event.key === Qt.Key_Up) {
            root.moveSelection(-1);
        } else if (event.key === Qt.Key_Down) {
            root.moveSelection(1);
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.playSelected();
        } else if (event.key === Qt.Key_Space) {
            root.playPause();
        } else if (event.key === Qt.Key_R) {
            root.tuneRandom();
        } else if (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal) {
            RadioAtlasService.changeVolume(5);
        } else if (event.key === Qt.Key_Minus) {
            RadioAtlasService.changeVolume(-5);
        } else if (event.key === Qt.Key_M) {
            RadioAtlasService.toggleMute();
        } else if (event.key === Qt.Key_F && root.selectedStation) {
            RadioAtlasService.toggleFavorite(root.selectedStation);
        } else {
            return;
        }
        event.accepted = true;
    }

    Keys.onPressed: event => root._key(event)

    Connections {
        target: RadioAtlasService

        function onStationChanged() {
            var station = RadioAtlasService.station;
            if (!station)
                return;
            var index = RadioModel.indexByUuid(root.displayStations, station.uuid);
            if (index >= 0 && index !== root.selectedIndex)
                root.setSelection(index);
            root.highlightStationCountry(station, true);
        }

        function onFavoritesChanged() {
            if (root.mode === "favorites")
                root.refreshLocalSelection();
        }

        function onRecentChanged() {
            if (root.mode === "recent")
                root.refreshLocalSelection();
        }

        function onRandomTuned(stations) {
            if (root.mode !== "random")
                return;
            root.fetching = false;
            root.setStationList("random", stations);
        }

        function onRandomFailed(message) {
            if (root.mode !== "random")
                return;
            root.fetching = false;
            root.fetchError = message;
        }
    }

    FileView {
        path: Qt.resolvedUrl("assets/countries.json").toString().replace(/^file:\/\//, "")
        watchChanges: false
        onLoaded: {
            try {
                var collection = JSON.parse(text());
                root.countries = Array.isArray(collection.features) ? collection.features : [];
            } catch (error) {
                root.countries = [];
                root.fetchError = "Map data could not be loaded";
            }
        }
    }

    Timer {
        id: searchDebounce
        interval: 300
        onTriggered: root.search(searchField.text)
    }

    Timer {
        id: worldExpandTimer
        interval: 1600
        onTriggered: {
            if (!root.opened || root._expanding || root.worldStations.length >= root.worldStationLimit)
                return;
            root._expanding = true;
            RadioAtlasService.fetchWorldMore(rows => {
                root._expanding = false;
                if (!root.opened)
                    return;
                root.worldExpansionMisses += 1;
                if (!rows || rows.length === 0) {
                    root.scheduleWorldExpansion(30000);
                    return;
                }
                var merged = RadioModel.mergeStations(root.worldStations, rows, root.worldStationLimit);
                if (merged.length === root.worldStations.length) {
                    root.scheduleWorldExpansion(10000);
                    return;
                }
                root.worldExpansionMisses = 0;
                root.worldStations = merged;
                if (root.mode === "world")
                    root.results = merged;
                root.scheduleWorldExpansion(1600);
            });
        }
    }

    // --- Header ------------------------------------------------------------

    Item {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Theme.space.controlHeight

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Radio Atlas"
            color: Theme.color.foreground
            font.family: Theme.fontFamilySans
            font.pixelSize: Theme.fontSize.title
            font.weight: Theme.weight.semibold
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.space.sm

            Input {
                id: searchField
                width: Math.min(330, root.width * 0.32)
                placeholder: "Search station, country, or genre"
                onTextChanged: {
                    if (root._settingSearch)
                        return;
                    if (searchField.text.length > 128) {
                        searchField.text = searchField.text.slice(0, 128);
                        return;
                    }
                    if (root.previewSearch(searchField.text))
                        searchDebounce.restart();
                }
                onAccepted: {
                    searchDebounce.stop();
                    root.search(searchField.text);
                }
            }

            IconButton {
                name: "shuffle"
                tooltipText: "Tune randomly"
                onClicked: root.tuneRandom()
            }

            IconButton {
                name: "circle-help"
                variant: root.helpVisible ? "selected" : "ghost"
                tooltipText: root.helpVisible ? "Hide controls" : "Show controls"
                onClicked: root.toggleControls()
            }

            IconButton {
                name: "x"
                tooltipText: "Close"
                onClicked: root.close()
            }
        }
    }

    Separator {
        id: headerRule
        anchors.top: header.bottom
        anchors.topMargin: Theme.space.panelPadding
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: -Theme.space.panelPadding
        anchors.rightMargin: -Theme.space.panelPadding
    }

    // --- Globe and station list --------------------------------------------

    Item {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: headerRule.bottom
        anchors.bottom: parent.bottom
        visible: !root.helpVisible

        Item {
            id: mapPane
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: sidebarRule.left

            Globe {
                id: globe
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: mapHint.top
                anchors.topMargin: Theme.space.panelPadding
                anchors.rightMargin: Theme.space.panelPadding
                anchors.bottomMargin: Theme.space.lg
                countries: root.countries
                stations: root.currentGeoStations
                selectedStation: RadioAtlasService.station || root.selectedStation
                activeCountryCode: root.activeCountryCode
                onInteractionStarted: {
                    root.keyboardSelectionVisible = false;
                    root.forceActiveFocus();
                }
                onPointerMoved: root.keyboardSelectionVisible = false
                onStationActivated: station => root.activateMapStation(station)
                onCountryActivated: (code, name) => root.browseCountry(code, name)
            }

            Text {
                id: mapHint
                anchors.left: parent.left
                anchors.right: signalCount.left
                anchors.rightMargin: Theme.space.sectionGap
                anchors.bottom: parent.bottom
                readonly property string _error: root.fetchError || RadioAtlasService.localError
                text: mapHint._error !== ""
                    ? mapHint._error
                    : (root.activeCountryName
                        ? root.activeCountryName + " · click another country to browse"
                        : "Drag or flick to spin · wheel to zoom · click a signal or country")
                textFormat: Text.PlainText
                color: mapHint._error !== "" ? Theme.color.destructive : Theme.color.mutedForeground
                font.family: Theme.fontFamilySans
                font.pixelSize: Theme.fontSize.caption
                elide: Text.ElideRight
            }

            Text {
                id: signalCount
                anchors.right: parent.right
                anchors.rightMargin: Theme.space.panelPadding
                anchors.bottom: parent.bottom
                text: root.currentGeoStations.length + " signals"
                color: Theme.color.mutedForeground
                font.family: Theme.fontFamilyMono
                font.pixelSize: Theme.fontSize.caption
            }
        }

        Separator {
            id: sidebarRule
            vertical: true
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -Theme.space.panelPadding
            anchors.right: sidebar.left
            anchors.rightMargin: Theme.space.panelPadding
        }

        Item {
            id: sidebar
            width: root.sidebarWidth
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            ButtonGroup {
                id: tabs
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: Theme.space.panelPadding
                height: Theme.space.controlHeight
                options: [
                    { label: "World", value: "world" },
                    { label: "Favorites", value: "favorites" },
                    { label: "Recent", value: "recent" }
                ]
                index: root.mode === "favorites" ? 1 : (root.mode === "recent" ? 2 : (root.mode === "world" ? 0 : -1))
                onPressed: i => {
                    if (i === 1)
                        root.showFavorites();
                    else if (i === 2)
                        root.showRecent();
                    else
                        root.showWorld();
                    root.forceActiveFocus();
                }
            }

            // The ring's halo falls outside a row, so the clip is a ring's
            // width wider than the list on every side.
            Item {
                id: listClip
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: tabs.bottom
                anchors.topMargin: Theme.space.sectionGap - Theme.ringWidth
                anchors.bottom: playerRule.top
                anchors.bottomMargin: Theme.space.panelPadding - Theme.ringWidth
                anchors.leftMargin: -Theme.ringWidth
                anchors.rightMargin: -Theme.ringWidth
                clip: true
                visible: !root.outputsVisible

                ListView {
                    id: stationList
                    anchors.fill: parent
                    anchors.margins: Theme.ringWidth
                    model: root.displayStations
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Item {
                        id: stationRow

                        required property var modelData
                        required property int index

                        readonly property bool favorite: RadioAtlasService.isFavorite(stationRow.modelData.uuid)

                        width: ListView.view.width
                        height: Theme.space.controlHeight * 2 + Theme.borderWidth

                        Cell {
                            id: rowCell
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            height: Theme.space.controlHeight * 2
                            ghost: true
                            interactive: true
                            selected: root.playingUuid === stationRow.modelData.uuid
                            cursor: root.keyboardSelectionVisible && root.selectedIndex === stationRow.index
                            onContainsPointerChanged: if (rowCell.containsPointer) root.setSelection(stationRow.index)
                            onClicked: {
                                root.setSelection(stationRow.index);
                                root.playSelected();
                                root.forceActiveFocus();
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: rowCell.width - Theme.space.controlPaddingX * 2 - favoriteButton.width - Theme.space.iconGap
                                spacing: Theme.space.xxs

                                Text {
                                    width: parent.width
                                    text: stationRow.modelData.name
                                    textFormat: Text.PlainText
                                    color: rowCell.foreground
                                    font.family: Theme.fontFamilySans
                                    font.pixelSize: Theme.fontSize.body
                                    font.weight: root.playingUuid === stationRow.modelData.uuid ? Theme.weight.semibold : Theme.weight.medium
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: RadioModel.stationMeta(stationRow.modelData)
                                    textFormat: Text.PlainText
                                    color: rowCell.dimForeground
                                    font.family: Theme.fontFamilyMono
                                    font.pixelSize: Theme.fontSize.caption
                                    elide: Text.ElideRight
                                }
                            }

                            IconButton {
                                id: favoriteButton
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                name: "star"
                                variant: stationRow.favorite ? "default" : "ghost"
                                tooltipText: stationRow.favorite ? "Remove favorite" : "Add favorite"
                                onClicked: RadioAtlasService.toggleFavorite(stationRow.modelData)
                            }
                        }

                        Separator {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            visible: stationRow.index < root.displayStations.length - 1
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - Theme.space.panelPadding * 2
                    visible: (!root.fetching || !root.remoteMode) && root.displayStations.length === 0
                    text: root.emptyStateText()
                    textFormat: Text.PlainText
                    color: root.fetchError || RadioAtlasService.localError ? Theme.color.destructive : Theme.color.mutedForeground
                    font.family: Theme.fontFamilySans
                    font.pixelSize: Theme.fontSize.body
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                }

                SectionLabel {
                    anchors.centerIn: parent
                    visible: root.fetching && root.remoteMode && root.displayStations.length === 0
                    text: "Loading stations"
                }
            }

            // The output picker takes the list's place rather than floating
            // over it: the overlay's card is the one card here.
            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: tabs.bottom
                anchors.topMargin: Theme.space.sectionGap
                spacing: Theme.space.rowGap
                visible: root.outputsVisible

                SectionLabel {
                    leftPadding: Theme.space.controlPaddingX
                    text: "Audio output"
                }

                Repeater {
                    model: root.outputChoices

                    delegate: Cell {
                        id: outputRow

                        required property var modelData
                        required property int index

                        width: parent.width
                        ghost: true
                        interactive: true
                        selected: outputRow.modelData.id === RadioAtlasService.output
                        cursor: root.outputCursor === outputRow.index
                        onContainsPointerChanged: if (outputRow.containsPointer) root.outputCursor = outputRow.index
                        onClicked: root.selectOutput(outputRow.modelData.id)

                        Text {
                            width: outputRow.width - Theme.space.controlPaddingX * 2
                            text: outputRow.modelData.label
                            textFormat: Text.PlainText
                            color: outputRow.foreground
                            font.family: Theme.fontFamilySans
                            font.pixelSize: Theme.fontSize.body
                            elide: Text.ElideRight
                        }
                    }
                }

                Text {
                    leftPadding: Theme.space.controlPaddingX
                    visible: RadioAtlasService.outputs.length === 0 && !RadioAtlasService.outputsLoading
                    text: RadioAtlasService.outputsError || "No other audio outputs found"
                    textFormat: Text.PlainText
                    color: RadioAtlasService.outputsError ? Theme.color.destructive : Theme.color.mutedForeground
                    font.family: Theme.fontFamilySans
                    font.pixelSize: Theme.fontSize.caption
                }
            }

            // --- Player --------------------------------------------------------

            Separator {
                id: playerRule
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: -Theme.space.panelPadding
                anchors.rightMargin: -Theme.space.panelPadding
                anchors.bottom: player.top
                anchors.bottomMargin: Theme.space.panelPadding
            }

            Column {
                id: player
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                spacing: Theme.space.rowGap

                Item {
                    width: parent.width
                    height: Theme.space.controlHeight

                    Column {
                        anchors.left: parent.left
                        anchors.right: playingFavorite.left
                        anchors.rightMargin: Theme.space.iconGap
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.space.xxs

                        Text {
                            width: parent.width
                            text: RadioAtlasService.running
                                ? (String(RadioAtlasService.station.name || "").trim() || RadioAtlasService.title || "Unknown station")
                                : "Nothing playing"
                            textFormat: Text.PlainText
                            color: Theme.color.foreground
                            font.family: Theme.fontFamilySans
                            font.pixelSize: Theme.fontSize.body
                            font.weight: RadioAtlasService.running ? Theme.weight.semibold : Theme.weight.medium
                            elide: Text.ElideRight
                        }

                        Text {
                            readonly property bool _failed: RadioAtlasService.playerError !== "" || RadioAtlasService.error !== ""
                            width: parent.width
                            text: RadioAtlasService.playerError
                                ? RadioAtlasService.playerError
                                : RadioAtlasService.error
                                    ? RadioAtlasService.error + ". Play to retry, or Next."
                                    : !RadioAtlasService.running
                                        ? "Choose a signal to begin"
                                        : !RadioAtlasService.loaded
                                            ? "Connecting"
                                            : (RadioAtlasService.trackTitle ? RadioAtlasService.trackTitle + " · " : "")
                                                + (RadioAtlasService.paused ? "Paused" : "Live")
                                                + (RadioAtlasService.queue.length > 1 ? " · " + RadioAtlasService.queue.length + " stations queued" : "")
                            textFormat: Text.PlainText
                            color: _failed ? Theme.color.destructive : Theme.color.mutedForeground
                            font.family: Theme.fontFamilySans
                            font.pixelSize: Theme.fontSize.caption
                            elide: Text.ElideRight
                        }
                    }

                    IconButton {
                        id: playingFavorite
                        readonly property bool favorite: RadioAtlasService.isFavorite(root.playingUuid)
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: RadioAtlasService.running
                        name: "star"
                        variant: playingFavorite.favorite ? "default" : "ghost"
                        tooltipText: playingFavorite.favorite ? "Remove from favorites" : "Add to favorites"
                        onClicked: RadioAtlasService.toggleFavorite(RadioAtlasService.station)
                    }
                }

                Item {
                    width: parent.width
                    height: Theme.space.controlHeight

                    ButtonGroup {
                        id: transport
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        height: Theme.space.controlHeight
                        exclusive: false
                        options: [
                            { icon: "skip-back", value: "previous", enabled: RadioAtlasService.running },
                            {
                                icon: RadioAtlasService.running && !RadioAtlasService.paused ? "pause" : "play",
                                value: "playpause",
                                enabled: RadioAtlasService.running || root.selectedStation !== null
                            },
                            { icon: "skip-forward", value: "next", enabled: RadioAtlasService.running },
                            { icon: "square", value: "stop", enabled: RadioAtlasService.running }
                        ]
                        onPressed: i => {
                            var action = transport.valueAt(i);
                            if (action === "previous")
                                RadioAtlasService.previous();
                            else if (action === "playpause")
                                root.playPause();
                            else if (action === "next")
                                RadioAtlasService.next();
                            else
                                RadioAtlasService.stop();
                            root.forceActiveFocus();
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.space.sm

                        IconButton {
                            name: "headphones"
                            variant: root.outputsVisible ? "selected" : "ghost"
                            tooltipText: RadioAtlasService.output
                                ? "Audio output: " + RadioAtlasService.outputLabel(RadioAtlasService.output)
                                : "Choose audio output"
                            onClicked: {
                                root.toggleOutputs();
                                root.forceActiveFocus();
                            }
                        }

                        IconButton {
                            name: "volume-x"
                            variant: RadioAtlasService.muted ? "default" : "ghost"
                            enabled: RadioAtlasService.running
                            tooltipText: RadioAtlasService.muted ? "Unmute" : "Mute"
                            onClicked: RadioAtlasService.toggleMute()
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: Theme.space.controlHeight

                    Icon {
                        id: volumeIcon
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.space.controlPaddingX
                        anchors.verticalCenter: parent.verticalCenter
                        name: RadioAtlasService.volume > 0 ? (RadioAtlasService.volume < 50 ? "volume-1" : "volume-2") : "volume-x"
                        size: Theme.fontSize.body
                        color: Theme.color.mutedForeground
                    }

                    Text {
                        id: volumeReadout
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: RadioAtlasService.volume + "%"
                        color: Theme.color.mutedForeground
                        font.family: Theme.fontFamilyMono
                        font.pixelSize: Theme.fontSize.bodySmall
                    }

                    Track {
                        id: volumeTrack
                        anchors.left: volumeIcon.right
                        anchors.leftMargin: Theme.space.iconGap
                        anchors.right: volumeReadout.left
                        anchors.rightMargin: Theme.space.iconGap
                        anchors.verticalCenter: parent.verticalCenter
                        value: RadioAtlasService.volume / 100
                        interactive: true

                        MouseArea {
                            anchors.fill: parent
                            anchors.topMargin: -Theme.space.md
                            anchors.bottomMargin: -Theme.space.md
                            cursorShape: Qt.PointingHandCursor
                            function _setFromX(x) {
                                RadioAtlasService.setVolume(Math.max(0, Math.min(1, x / volumeTrack.width)) * 100);
                            }
                            onPressed: mouse => _setFromX(mouse.x)
                            onPositionChanged: mouse => { if (pressed) _setFromX(mouse.x); }
                        }
                    }
                }
            }
        }
    }

    // --- Controls ------------------------------------------------------------

    Row {
        id: controlsRow
        anchors.top: headerRule.bottom
        anchors.topMargin: Theme.space.sectionGap
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width, 920)
        spacing: Theme.space.sectionGap * 3
        visible: root.helpVisible

        Repeater {
            model: root.controlSections

            delegate: Column {
                id: section

                required property var modelData

                width: (controlsRow.width - controlsRow.spacing) / 2
                spacing: Theme.space.rowGap

                SectionLabel {
                    leftPadding: Theme.space.controlPaddingX
                    text: section.modelData.title
                }

                Repeater {
                    model: section.modelData.controls

                    delegate: Item {
                        id: control

                        required property var modelData

                        width: section.width
                        height: Theme.space.controlHeight

                        Item {
                            id: controlInput
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.space.controlPaddingX
                            anchors.verticalCenter: parent.verticalCenter
                            width: section.width * 0.4
                            height: parent.height

                            Chord {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !!control.modelData.keys
                                keys: control.modelData.keys || []
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                visible: !control.modelData.keys
                                text: control.modelData.input || ""
                                color: Theme.color.foreground
                                font.family: Theme.fontFamilySans
                                font.pixelSize: Theme.fontSize.body
                                font.weight: Theme.weight.medium
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            anchors.left: controlInput.right
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: control.modelData.action
                            color: Theme.color.mutedForeground
                            font.family: Theme.fontFamilySans
                            font.pixelSize: Theme.fontSize.body
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
