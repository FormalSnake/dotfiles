// Portions from omarchy-radio-atlas (MIT, Copyright 2026 Akshar Patel)
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "stations.js" as Stations

// Everything both Radio Atlas plugins share: the one mpv child, what it is
// playing, the saved favourites/recent/volume/output, and every Radio
// Browser request. The overlay and the bar cell import this directory by
// relative path, which resolves to the same qmldir and so the same instance.
//
// mpv runs unsandboxed: the original's bwrap and private-address proxy are
// dropped, so a station URL is only ever checked to be http(s).
Singleton {
    id: root

    readonly property string userAgent: "Radio Atlas (FormalShell)"

    readonly property string _home: Quickshell.env("HOME") || ""
    readonly property string _runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || ""
    readonly property string socketDir: root._runtimeDir === "" ? "" : root._runtimeDir + "/formalshell-radio-atlas"
    readonly property string socketPath: root.socketDir === "" ? "" : root.socketDir + "/mpv.sock"
    readonly property string statePath: (Quickshell.env("XDG_STATE_HOME") || root._home + "/.local/state")
        + "/formalshell/radio-atlas.json"
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || root._home + "/.cache")
        + "/formalshell/radio-atlas"
    readonly property string mprisPath: Qt.resolvedUrl("../mpris.so").toString().replace(/^file:\/\//, "")

    // --- Saved state ------------------------------------------------------

    property var favorites: []
    property var recent: []
    property int volume: 70
    property string output: ""
    property string localError: ""
    readonly property var _favoriteSet: {
        var set = {};
        for (var i = 0; i < root.favorites.length; i++)
            set["$" + root.favorites[i].uuid] = true;
        return set;
    }
    // False until the file has parsed, or is known not to exist: a state
    // file that fails validation is never overwritten.
    property bool _stateWritable: false

    // --- Playback -------------------------------------------------------

    property var station: null
    property var queue: []
    property int queueIndex: -1
    readonly property bool running: root.station !== null
    property bool _mpvPaused: false
    readonly property bool paused: root._mpvPaused || root.error !== ""
    property bool muted: false
    property string title: ""
    property bool loaded: false
    // A stream that failed or dropped. Kept with the station selected, never
    // retried on its own.
    property string error: ""
    property string playerError: ""
    property var outputs: []
    property string outputsError: ""
    property bool outputsLoading: false
    property string _recordedUuid: ""
    property string lastRandomUuid: ""
    property bool randomBusy: false

    readonly property string trackTitle: {
        var t = root.title.trim();
        var name = root.station ? String(root.station.name || "").trim() : "";
        return t !== "" && name !== "" && t.toLowerCase() !== name.toLowerCase() ? t : "";
    }

    signal randomTuned(var stations)
    signal randomFailed(string message)

    function isFavorite(uuid) {
        return !!uuid && root._favoriteSet["$" + uuid] === true;
    }

    // --- Process and file plumbing ---------------------------------------

    function _run(command, onDone) {
        var proc = procComponent.createObject(root, { command: command, onDone: onDone || null });
        proc.running = true;
    }

    function _readJson(path, onDone) {
        fileReader.createObject(root, { path: path, onDone: onDone });
    }

    function _writeJson(path, value) {
        var writer = fileWriter.createObject(root, { path: path });
        writer.setText(JSON.stringify(value) + "\n");
    }

    Component {
        id: procComponent

        Process {
            id: proc

            property var onDone: null
            property bool _exited: false
            property bool _collected: false
            property int _exitCode: -1
            property string _text: ""

            function _finish() {
                if (!proc._exited || !proc._collected)
                    return;
                var done = proc.onDone;
                proc.onDone = null;
                if (done)
                    done(proc._exitCode, proc._text);
                proc.destroy();
            }

            stdout: StdioCollector {
                onStreamFinished: {
                    proc._text = text;
                    proc._collected = true;
                    proc._finish();
                }
            }

            onExited: exitCode => {
                proc._exitCode = exitCode;
                proc._exited = true;
                proc._finish();
            }
        }
    }

    Component {
        id: fileReader

        FileView {
            id: reader

            property var onDone: null

            printErrors: false
            watchChanges: false

            function _finish(doc) {
                var done = reader.onDone;
                reader.onDone = null;
                if (done)
                    done(doc);
                reader.destroy();
            }

            onLoaded: {
                var doc = null;
                try {
                    doc = JSON.parse(reader.text());
                } catch (e) {
                    doc = null;
                }
                reader._finish(doc);
            }
            onLoadFailed: error => reader._finish(null)
        }
    }

    Component {
        id: fileWriter

        FileView {
            id: writer
            preload: false
            printErrors: false
            atomicWrites: true
            onSaved: writer.destroy()
            onSaveFailed: error => writer.destroy()
        }
    }

    // --- Saved state -------------------------------------------------------

    FileView {
        id: stateFile
        path: root.statePath
        printErrors: false
        watchChanges: false
        atomicWrites: true

        onLoaded: {
            var state = Stations.parseState(stateFile.text());
            if (!state) {
                root._stateWritable = false;
                root.localError = "Saved stations could not be loaded";
                return;
            }
            root.favorites = state.favorites;
            root.recent = state.recent;
            root.volume = state.volume;
            root.output = state.output;
            root.localError = "";
            root._stateWritable = true;
        }
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                root._stateWritable = true;
            } else {
                root._stateWritable = false;
                root.localError = "Saved stations could not be loaded";
            }
        }
        onSaveFailed: error => root.localError = "Saved stations could not be written"
    }

    function _saveState() {
        if (!root._stateWritable)
            return;
        stateFile.setText(JSON.stringify({
            favorites: root.favorites,
            recent: root.recent,
            volume: root.volume,
            output: root.output
        }) + "\n");
    }

    Timer {
        id: volumeSaveTimer
        interval: 600
        onTriggered: root._saveState()
    }

    function toggleFavorite(station) {
        if (!station || !station.uuid)
            return;
        if (!root._stateWritable) {
            root.localError = "Favorite could not be updated";
            return;
        }
        var uuid = station.uuid;
        var rest = root.favorites.filter(s => s.uuid !== uuid);
        root.favorites = rest.length < root.favorites.length
            ? rest
            : [Stations.savedRecord(station)].concat(rest).slice(0, Stations.MAX_FAVORITES);
        root.localError = "";
        root._saveState();
    }

    function _recordPlayed(station) {
        if (!station || !station.uuid || !root._stateWritable)
            return;
        root.recent = [Stations.savedRecord(station)]
            .concat(root.recent.filter(s => s.uuid !== station.uuid))
            .slice(0, Stations.MAX_RECENT);
        root._saveState();
    }

    // radio-player's refresh of a saved list: the stored URL plays at once,
    // and whatever Radio Browser now says about those stations replaces the
    // stored records for next time.
    function _refreshSaved(list) {
        var uuids = list.map(s => s.uuid).filter(u => Stations.UUID_PATTERN.test(u));
        if (uuids.length === 0 || uuids.join(",").length > 4096)
            return;
        root._request(Stations.resolveRequest(uuids), rows => {
            if (!rows || rows.length === 0)
                return;
            var byUuid = {};
            for (var i = 0; i < rows.length; i++)
                byUuid["$" + rows[i].uuid] = rows[i];
            var swap = s => byUuid["$" + s.uuid] ? Stations.savedRecord(byUuid["$" + s.uuid]) : s;
            root.favorites = root.favorites.map(swap);
            root.recent = root.recent.map(swap);
            root._saveState();
        });
    }

    // --- Radio Browser -----------------------------------------------------

    property var _bases: []
    property var _baseWaiters: []

    function _withBases(then) {
        if (root._bases.length > 0) {
            then(root._bases);
            return;
        }
        root._baseWaiters.push(then);
        if (root._baseWaiters.length > 1)
            return;
        root._run(["curl", "--fail", "--silent", "--connect-timeout", "4", "--max-time", "8",
            "--max-filesize", "65536", "--proto", "=https", "--user-agent", root.userAgent,
            Stations.SERVERS_URL], (code, text) => {
            var found = code === 0 ? Stations.parseServers(text) : [];
            // A failed discovery is not remembered, so the next request asks again.
            if (found.length > 0)
                root._bases = found;
            var bases = found.length > 0 ? found : [Stations.API_FALLBACK];
            var waiters = root._baseWaiters;
            root._baseWaiters = [];
            for (var i = 0; i < waiters.length; i++)
                waiters[i](bases);
        });
    }

    // One request, tried against each mirror in turn. `done` gets the
    // sanitised records or null once every mirror has failed.
    function _request(request, done) {
        root._withBases(bases => {
            var attempt = index => {
                if (index >= bases.length) {
                    done(null);
                    return;
                }
                root._run(Stations.curlArgs(bases[index], request, root.userAgent), (code, text) => {
                    var rows = code === 0 ? Stations.parseResponse(text, request.max) : null;
                    if (rows === null)
                        attempt(index + 1);
                    else
                        done(rows);
                });
            };
            attempt(0);
        });
    }

    function _countFetch(uuid) {
        if (!Stations.UUID_PATTERN.test(uuid))
            return;
        root._withBases(bases => root._run(["curl", "--fail", "--silent", "--max-time", "4",
            "--proto", "=https", "--user-agent", root.userAgent, "--output", "/dev/null",
            bases[0] + "/json/url/" + uuid], null));
    }

    property bool _worldRefreshing: false

    function _refreshWorld(done) {
        if (root._worldRefreshing && !done)
            return;
        root._worldRefreshing = true;
        root._request(Stations.worldRequest(), rows => {
            root._worldRefreshing = false;
            if (rows && rows.length > 0)
                root._writeJson(root.cacheDir + "/world.json", { fetchedAt: Date.now(), stations: rows });
            if (done)
                done(rows && rows.length > 0 ? rows : null);
        });
    }

    // The 500 most-clicked geotagged stations: the cache when it has one,
    // refreshed in the background once it is a day old.
    function fetchWorld(done) {
        root._readJson(root.cacheDir + "/world.json", doc => {
            if (Stations.validWorldCache(doc)) {
                done(doc.stations);
                if (Stations.stale(doc, Date.now()))
                    root._refreshWorld(null);
                return;
            }
            root._refreshWorld(done);
        });
    }

    function fetchWorldMore(done) {
        root._request(Stations.worldMoreRequest(), done);
    }

    property var _countryRefreshing: ({})

    function _refreshCountry(code, done) {
        if (root._countryRefreshing[code] && !done)
            return;
        root._countryRefreshing[code] = true;
        root._request(Stations.countryRequest(code), rows => {
            root._countryRefreshing[code] = false;
            var valid = rows !== null && rows.every(s => s.countryCode === code);
            if (valid)
                root._writeJson(root.cacheDir + "/countries/" + code + ".json", { fetchedAt: Date.now(), stations: rows });
            if (done)
                done(valid ? rows : null);
        });
    }

    // A country's 25 most-clicked stations. `known` is what the caller
    // already holds for the whole world, which answers at once while the
    // country's own list is fetched behind it.
    function fetchCountry(code, known, done) {
        if (!/^[A-Z]{2}$/.test(code)) {
            done(null);
            return;
        }
        root._readJson(root.cacheDir + "/countries/" + code + ".json", doc => {
            if (Stations.validCountryCache(doc, code) && doc.stations.length > 0) {
                done(doc.stations);
                if (Stations.stale(doc, Date.now()))
                    root._refreshCountry(code, null);
                return;
            }
            var local = (known || []).filter(s => s.countryCode === code).slice(0, 100);
            if (local.length > 0) {
                done(local);
                root._refreshCountry(code, null);
                return;
            }
            root._refreshCountry(code, done);
        });
    }

    // Name, country and tag matches in parallel, unioned. Null only when all
    // three requests failed.
    function search(query, done) {
        var q = String(query || "").trim();
        if (q === "" || q.length > 128) {
            done(null);
            return;
        }
        var requests = Stations.searchRequests(q);
        var results = [];
        var pending = requests.length;
        var succeeded = 0;
        requests.forEach((request, i) => root._request(request, rows => {
            results[i] = rows || [];
            if (rows)
                succeeded++;
            if (--pending === 0)
                done(succeeded > 0 ? Stations.union(results, Stations.MAX_RECORDS) : null);
        }));
    }

    function _randomExclusions() {
        var out = [];
        var add = uuid => {
            var value = String(uuid || "");
            if (Stations.UUID_PATTERN.test(value) && out.indexOf(value) < 0)
                out.push(value);
        };
        add(root.station ? root.station.uuid : "");
        add(root.lastRandomUuid);
        for (var i = 0; i < root.recent.length && out.length < 32; i++)
            add(root.recent[i].uuid);
        return out;
    }

    // Sixty random stations, mappable ones only, anything recently heard left
    // out; the first one plays and the rest become its queue.
    function tuneRandom() {
        if (root.randomBusy)
            return;
        root.randomBusy = true;
        root._request(Stations.randomRequest(), rows => {
            root.randomBusy = false;
            if (rows === null) {
                root.randomFailed("Radio Browser is unavailable. Try again shortly.");
                return;
            }
            var picked = Stations.pickRandom(rows, root._randomExclusions());
            root.randomTuned(picked);
            if (picked.length > 0) {
                root.lastRandomUuid = picked[0].uuid;
                root.play(picked[0], picked);
            }
        });
    }

    // --- mpv ---------------------------------------------------------------

    function _mpvCommand() {
        var args = ["mpv", "--no-config", "--no-video", "--force-window=no", "--audio-display=no",
            "--idle=yes", "--load-scripts=no", "--ytdl=no", "--load-unsafe-playlists=no",
            "--cache-secs=20", "--demuxer-max-bytes=8MiB", "--demuxer-max-back-bytes=2MiB",
            "--network-timeout=30", "--volume=" + root.volume, "--volume-max=100",
            "--demuxer-lavf-o=protocol_whitelist=[http,https,tls,tcp]",
            "--stream-lavf-o=protocol_whitelist=[http,https,tls,tcp]",
            "--input-ipc-server=" + root.socketPath, "--no-terminal"];
        if (root._mprisAvailable)
            args.push("--script=" + root.mprisPath);
        if (root.output !== "")
            args.push("--audio-device=pulse/" + root.output);
        // The socket's directory has to exist before mpv binds in it, and
        // `exec` leaves mpv itself as the Process's child.
        return ["sh", "-c", "mkdir -p -m 700 \"$1\" && shift && exec \"$@\"", "sh", root.socketDir].concat(args);
    }

    property bool _mprisAvailable: false

    Component.onCompleted: root._run(["test", "-f", root.mprisPath], code => root._mprisAvailable = code === 0)

    Process {
        id: mpv
        onExited: root._onMpvExited()
    }

    property var _ipc: null
    property bool _ipcReady: false
    property var _pending: []
    property int _connectAttempts: 0
    property bool _stopping: false
    // A play that arrived while the player was still quitting, replayed once
    // it has exited.
    property var _resume: null
    // Set once mpv has left its startup idle, so the idle that follows a
    // dead stream can be told apart from the one before the first load.
    property bool _active: false

    Component {
        id: socketComponent

        Socket {
            id: sock
            parser: SplitParser {
                onRead: data => root._onIpcLine(data)
            }
            onConnectionStateChanged: root._onSocketState(sock)
            onError: error => root._onSocketError(sock)
        }
    }

    // A Socket whose connect failed keeps its dead QLocalSocket and never
    // retries, so every attempt is a fresh object.
    Timer {
        id: connectTimer
        interval: 100
        onTriggered: {
            if (!mpv.running)
                return;
            if (root._ipc)
                root._ipc.destroy();
            root._ipc = socketComponent.createObject(root, { path: root.socketPath });
            root._ipc.connected = true;
        }
    }

    function _onSocketState(sock) {
        if (sock !== root._ipc)
            return;
        root._ipcReady = sock.connected;
        if (!sock.connected)
            return;
        root._connectAttempts = 0;
        var observed = ["pause", "volume", "mute", "media-title", "idle-active"];
        for (var i = 0; i < observed.length; i++)
            root._write(["observe_property", i + 1, observed[i]]);
        var pending = root._pending;
        root._pending = [];
        for (var p = 0; p < pending.length; p++)
            root._write(pending[p]);
    }

    function _onSocketError(sock) {
        if (sock !== root._ipc || sock.connected)
            return;
        root._ipcReady = false;
        if (mpv.running && ++root._connectAttempts < 60) {
            connectTimer.restart();
        } else if (mpv.running) {
            root.playerError = "Could not reach the player";
            mpv.running = false;
        }
    }

    function _write(command) {
        root._ipc.write(JSON.stringify({ command: command }) + "\n");
        root._ipc.flush();
    }

    function _send(command) {
        if (root._ipcReady) {
            root._write(command);
            return;
        }
        root._pending = root._pending.concat([command]);
        if (!mpv.running)
            root._startMpv();
    }

    function _startMpv() {
        if (root.socketPath === "") {
            root.playerError = "Radio Atlas needs XDG_RUNTIME_DIR";
            root._pending = [];
            root.station = null;
            return;
        }
        root._stopping = false;
        root._connectAttempts = 0;
        mpv.command = root._mpvCommand();
        mpv.running = true;
        connectTimer.restart();
    }

    function _onMpvExited() {
        var unexpected = !root._stopping && root.station !== null;
        var resume = root._resume;
        root._resume = null;
        root._active = false;
        if (root._ipc)
            root._ipc.destroy();
        root._ipc = null;
        root._ipcReady = false;
        root._pending = [];
        root._stopping = false;
        root.station = null;
        root.queue = [];
        root.queueIndex = -1;
        root._mpvPaused = false;
        root.muted = false;
        root.title = "";
        root.loaded = false;
        root.error = "";
        root._recordedUuid = "";
        if (unexpected)
            root.playerError = "The player stopped unexpectedly";
        if (resume)
            root.play(resume.station, resume.list);
    }

    function _onIpcLine(line) {
        var msg;
        try {
            msg = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (!msg || typeof msg.event !== "string")
            return;
        if (msg.event === "property-change") {
            if (msg.name === "pause")
                root._mpvPaused = msg.data === true;
            else if (msg.name === "mute")
                root.muted = msg.data === true;
            else if (msg.name === "media-title")
                root.title = String(msg.data || "").replace(/[\u0000-\u001f\u007f]+/g, " ").slice(0, 512);
            else if (msg.name === "idle-active")
                root._onIdle(msg.data === true);
            else if (msg.name === "volume" && typeof msg.data === "number") {
                var v = Math.max(0, Math.min(100, Math.round(msg.data)));
                if (v !== root.volume) {
                    root.volume = v;
                    volumeSaveTimer.restart();
                }
            }
        } else if (msg.event === "start-file") {
            root.loaded = false;
            root.error = "";
        } else if (msg.event === "file-loaded") {
            root.loaded = true;
            if (root.station && root.station.uuid !== root._recordedUuid) {
                root._recordedUuid = root.station.uuid;
                root._recordPlayed(root.station);
            }
        } else if (msg.event === "end-file") {
            // A live stream has no end, so eof is a dropped connection too.
            if ((msg.reason === "error" || msg.reason === "eof") && root.station)
                root.error = root._failure();
            root.loaded = false;
        }
    }

    function _failure() {
        return root.loaded ? "Stream disconnected" : "Station could not be played";
    }

    // end-file names the failure first; this catches a player that went idle
    // without one.
    function _onIdle(idle) {
        if (!idle) {
            root._active = true;
            return;
        }
        if (root._active && root.station && root.error === "")
            root.error = root._failure();
    }

    // Plays `station` with `list` as its queue for previous/next, the list it
    // was picked from.
    function play(station, list) {
        if (!Stations.playable(station)) {
            root.playerError = "Station is unavailable or has an unsafe stream URL";
            return;
        }
        var rows = (Array.isArray(list) ? list : [station]).filter(Stations.playable);
        var index = rows.findIndex(s => s.uuid === station.uuid);
        if (index < 0) {
            rows = [station].concat(rows);
            index = 0;
        }
        if (root._stopping) {
            root._resume = { station: station, list: rows };
            return;
        }
        root.queue = rows;
        root.queueIndex = index;
        root.station = station;
        root.error = "";
        root.playerError = "";
        root.title = "";
        root.loaded = false;
        root._send(["loadfile", station.url, "replace"]);
        root._send(["set_property", "pause", false]);
        root._countFetch(station.uuid);
    }

    function playFromSaved(station, list) {
        root.play(station, list);
        root._refreshSaved(list);
    }

    function toggle() {
        if (!root.station)
            return;
        if (root.error !== "") {
            root.play(root.station, root.queue);
            return;
        }
        root._send(["cycle", "pause"]);
    }

    function _step(delta) {
        if (!root.station || root.queue.length === 0)
            return;
        var n = root.queue.length;
        var index = ((root.queueIndex + delta) % n + n) % n;
        root.play(root.queue[index], root.queue);
    }

    function next() {
        root._step(1);
    }

    function previous() {
        root._step(-1);
    }

    function stop() {
        if (!mpv.running)
            return;
        root._stopping = true;
        if (root._ipcReady) {
            root._write(["quit"]);
            stopTimer.restart();
        } else {
            mpv.running = false;
        }
    }

    // mpv answers `quit` by exiting; one that does not is signalled.
    Timer {
        id: stopTimer
        interval: 1500
        onTriggered: if (mpv.running) mpv.running = false
    }

    function setVolume(value) {
        var v = Math.max(0, Math.min(100, Math.round(value)));
        if (v === root.volume)
            return;
        root.volume = v;
        if (root._ipcReady)
            root._write(["set_property", "volume", v]);
        volumeSaveTimer.restart();
    }

    function changeVolume(delta) {
        root.setVolume(root.volume + delta);
    }

    function toggleMute() {
        if (root._ipcReady)
            root._write(["cycle", "mute"]);
    }

    function refreshOutputs() {
        if (root.outputsLoading)
            return;
        root.outputsLoading = true;
        root._run(["pactl", "-f", "json", "list", "sinks"], (code, text) => {
            root.outputsLoading = false;
            var sinks = code === 0 && text.length <= Stations.MAX_RESPONSE_CHARS ? Stations.parseSinks(text) : null;
            root.outputs = sinks || [];
            root.outputsError = sinks === null ? "Audio outputs are unavailable" : "";
        });
    }

    // "" is the system default: no --audio-device on the next launch, and
    // `auto` on a running player.
    function setOutput(id) {
        var sink = String(id || "");
        if (sink !== "" && !root.outputs.some(o => o.id === sink)) {
            root.playerError = "Unknown audio output";
            return;
        }
        root.output = sink;
        if (root._ipcReady)
            root._write(["set_property", "audio-device", sink === "" ? "auto" : "pulse/" + sink]);
        root._saveState();
    }

    function outputLabel(id) {
        for (var i = 0; i < root.outputs.length; i++)
            if (root.outputs[i].id === id)
                return root.outputs[i].label;
        return id;
    }
}
