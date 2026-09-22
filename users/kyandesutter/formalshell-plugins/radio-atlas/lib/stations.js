// Portions from omarchy-radio-atlas (MIT, Copyright 2026 Akshar Patel)
.pragma library

// Radio Browser's wire format in, station records out, plus the saved state
// schema. Pure, so RadioAtlasService.qml only orchestrates processes and
// files. The rules are radio-fetch's jq filter and radio-state's validator
// from the original, transcribed field for field.

var API_FALLBACK = "https://all.api.radio-browser.info";
var SERVERS_URL = API_FALLBACK + "/json/servers";
var MAX_RESPONSE_CHARS = 4194304;
var MAX_RECORDS = 500;
var MAX_FAVORITES = 500;
var MAX_RECENT = 30;
var CACHE_MAX_AGE_MS = 24 * 60 * 60 * 1000;

var UUID_PATTERN = /^[0-9A-Fa-f-]{20,64}$/;
var SINK_PATTERN = /^[A-Za-z0-9._:+-]{1,160}$/;
var OUTPUT_PATTERN = /^[A-Za-z0-9._:+-]{0,160}$/;
var MIRROR_PATTERN = /^[A-Za-z0-9.-]+\.api\.radio-browser\.info$/;
var STREAM_PATTERN = /^https?:\/\//i;

function _clean(value, limit) {
    if (typeof value !== "string")
        return "";
    return value.replace(/[\u0000-\u001f\u007f]/g, " ").replace(/  +/g, " ").slice(0, limit);
}

function _compact(value, limit) {
    if (typeof value !== "string")
        return "";
    return value.replace(/[\u0000-\u001f\u007f]/g, "").slice(0, limit);
}

// jq's `tonumber` with a fallback: a number stays, a numeric string parses,
// anything else (null, "", an object) is the fallback.
function _number(value, fallback) {
    var n = NaN;
    if (typeof value === "number")
        n = value;
    else if (typeof value === "string" && value.trim() !== "")
        n = Number(value);
    return isFinite(n) ? n : fallback;
}

// jq's `a // b` keeps "" and 0; only null, undefined and false fall through.
function _or(value, fallback) {
    return value === null || value === undefined || value === false ? fallback : value;
}

function playable(station) {
    return !!station && typeof station.url === "string"
        && STREAM_PATTERN.test(station.url) && !/[\r\n]/.test(station.url);
}

function record(row) {
    var name = _clean(_or(row.name, "Unknown station"), 160);
    return {
        uuid: _compact(_or(row.stationuuid, ""), 64),
        name: name === "" ? "Unknown station" : name,
        url: _compact(_or(_or(row.url_resolved, row.url), ""), 2048),
        homepage: _compact(_or(row.homepage, ""), 2048),
        favicon: _compact(_or(row.favicon, ""), 2048),
        country: _clean(_or(row.country, ""), 100),
        countryCode: _clean(_or(row.countrycode, ""), 2).toUpperCase(),
        state: _clean(_or(row.state, ""), 100),
        language: _clean(_or(row.language, ""), 120),
        tags: _clean(_or(row.tags, ""), 500),
        codec: _clean(_or(row.codec, ""), 32),
        bitrate: _number(_or(row.bitrate, 0), 0),
        votes: _number(_or(row.votes, 0), 0),
        clicks: _number(_or(row.clickcount, 0), 0),
        latitude: _number(row.geo_lat, null),
        longitude: _number(row.geo_long, null)
    };
}

function _keep(station) {
    return station.uuid !== ""
        && STREAM_PATTERN.test(station.url)
        && (station.latitude === null || (station.latitude >= -90 && station.latitude <= 90))
        && (station.longitude === null || (station.longitude >= -180 && station.longitude <= 180));
}

// A raw response body to at most `max` sanitised, deduplicated records, or
// null when the body is not an array of at most `max` entries.
function parseResponse(text, max) {
    if (typeof text !== "string" || text.length > MAX_RESPONSE_CHARS)
        return null;
    var rows;
    try {
        rows = JSON.parse(text);
    } catch (e) {
        return null;
    }
    if (!Array.isArray(rows) || rows.length > max)
        return null;
    var out = [];
    var seen = {};
    var head = rows.slice(0, MAX_RECORDS);
    for (var i = 0; i < head.length && out.length < MAX_RECORDS; i++) {
        if (!head[i] || typeof head[i] !== "object")
            continue;
        var station = record(head[i]);
        if (!_keep(station) || seen["$" + station.uuid])
            continue;
        seen["$" + station.uuid] = true;
        out.push(station);
    }
    return out;
}

function union(lists, max) {
    var out = [];
    var seen = {};
    for (var l = 0; l < lists.length; l++) {
        var rows = Array.isArray(lists[l]) ? lists[l] : [];
        for (var i = 0; i < rows.length && out.length < max; i++) {
            if (!rows[i] || seen["$" + rows[i].uuid])
                continue;
            seen["$" + rows[i].uuid] = true;
            out.push(rows[i]);
        }
    }
    return out;
}

function shuffle(list) {
    var out = list.slice(0);
    for (var i = out.length - 1; i > 0; i--) {
        var j = Math.floor(Math.random() * (i + 1));
        var t = out[i];
        out[i] = out[j];
        out[j] = t;
    }
    return out;
}

// /json/servers lists each mirror once per address family.
function parseServers(text) {
    var rows;
    try {
        rows = JSON.parse(text);
    } catch (e) {
        return [];
    }
    if (!Array.isArray(rows))
        return [];
    var out = [];
    for (var i = 0; i < rows.length; i++) {
        var name = rows[i] && typeof rows[i].name === "string" ? rows[i].name : "";
        if (!MIRROR_PATTERN.test(name) || out.indexOf("https://" + name) >= 0)
            continue;
        out.push("https://" + name);
    }
    return shuffle(out);
}

var _SEARCH_ORDER = [["hidebroken", "true"], ["order", "clickcount"], ["reverse", "true"]];

function worldRequest() {
    return {
        max: 500,
        path: "/json/stations/search",
        params: [["has_geo_info", "true"]].concat(_SEARCH_ORDER, [["limit", "500"]])
    };
}

function worldMoreRequest() {
    return {
        max: 500,
        path: "/json/stations/search",
        params: [["hidebroken", "true"], ["order", "random"], ["limit", "500"]]
    };
}

function countryRequest(code) {
    return {
        max: 25,
        path: "/json/stations/bycountrycodeexact/" + code,
        params: _SEARCH_ORDER.concat([["limit", "25"]])
    };
}

function searchRequests(query) {
    return ["name", "country", "tag"].map(function (field) {
        return {
            max: 80,
            path: "/json/stations/search",
            params: [[field, query]].concat(_SEARCH_ORDER, [["limit", "80"]])
        };
    });
}

function randomRequest() {
    return {
        max: 60,
        path: "/json/stations/search",
        params: [["hidebroken", "true"], ["order", "random"], ["limit", "60"]]
    };
}

function resolveRequest(uuids) {
    return {
        max: uuids.length,
        path: "/json/stations/byuuid",
        params: [["uuids", uuids.join(",")]]
    };
}

// curl's argv for one request against one mirror, the flags radio-fetch
// passes. `--max-filesize` aborts a transfer past the cap even when the
// server sends no length.
function curlArgs(base, request, userAgent) {
    var args = ["curl", "--fail", "--silent", "--show-error",
        "--connect-timeout", "4", "--max-time", request.max >= 500 ? "45" : "12",
        "--retry", "1", "--retry-delay", "0",
        "--max-filesize", String(MAX_RESPONSE_CHARS), "--proto", "=https",
        "--user-agent", userAgent, "--get", base + request.path];
    for (var i = 0; i < request.params.length; i++)
        args.push("--data-urlencode", request.params[i][0] + "=" + request.params[i][1]);
    return args;
}

function mappable(station) {
    return (station.latitude !== null && station.longitude !== null)
        || /^[A-Z]{2}$/.test(station.countryCode);
}

// radio-fetch's random pick: mappable stations only, the excluded ones
// dropped unless that would leave nothing, then shuffled.
function pickRandom(rows, excluded) {
    var skip = {};
    for (var i = 0; i < excluded.length; i++)
        skip["$" + excluded[i]] = true;
    var usable = rows.filter(mappable);
    var fresh = usable.filter(function (s) { return !skip["$" + s.uuid]; });
    return shuffle(fresh.length > 0 ? fresh : usable);
}

function validWorldCache(doc) {
    return !!doc && typeof doc.fetchedAt === "number" && Array.isArray(doc.stations)
        && doc.stations.length > 0 && doc.stations.length <= MAX_RECORDS;
}

function validCountryCache(doc, code) {
    return !!doc && typeof doc.fetchedAt === "number" && Array.isArray(doc.stations)
        && doc.stations.length <= 25
        && doc.stations.every(function (s) { return s && s.countryCode === code; });
}

function stale(doc, now) {
    return now - doc.fetchedAt > CACHE_MAX_AGE_MS;
}

var _SAVED_KEYS = ["uuid", "name", "url", "homepage", "favicon", "country", "countryCode",
    "state", "language", "tags", "codec", "bitrate", "votes", "clicks", "latitude", "longitude"];

// What a favourite or a recent entry keeps: the record's own fields, never
// the estimatedLocation copy a map merge made.
function savedRecord(station) {
    var out = {};
    for (var i = 0; i < _SAVED_KEYS.length; i++)
        out[_SAVED_KEYS[i]] = station[_SAVED_KEYS[i]] === undefined ? null : station[_SAVED_KEYS[i]];
    return out;
}

// radio-state's validator: the file is taken whole or not at all, so a
// state that fails here is left on disk untouched.
function parseState(text) {
    var doc;
    try {
        doc = JSON.parse(text);
    } catch (e) {
        return null;
    }
    if (!doc || typeof doc !== "object" || Array.isArray(doc))
        return null;
    var volume = doc.volume === undefined || doc.volume === null ? 70 : doc.volume;
    var output = doc.output === undefined || doc.output === null ? "" : doc.output;
    if (!Array.isArray(doc.favorites) || doc.favorites.length > MAX_FAVORITES
        || !Array.isArray(doc.recent) || doc.recent.length > MAX_RECENT
        || typeof volume !== "number" || volume < 0 || volume > 100
        || typeof output !== "string" || !OUTPUT_PATTERN.test(output))
        return null;
    var saved = function (s) { return !!s && typeof s === "object" && typeof s.uuid === "string" && s.uuid !== ""; };
    return {
        favorites: doc.favorites.filter(saved),
        recent: doc.recent.filter(saved),
        volume: Math.round(volume),
        output: output
    };
}

// `pactl -f json list sinks` to [{ id, label }]; AirPlay sinks share one
// description, so theirs carries the address out of the sink name.
function parseSinks(text) {
    var rows;
    try {
        rows = JSON.parse(text);
    } catch (e) {
        return null;
    }
    if (!Array.isArray(rows))
        return null;
    var out = [];
    for (var i = 0; i < rows.length; i++) {
        var row = rows[i];
        if (!row || typeof row !== "object" || typeof row.name !== "string" || !SINK_PATTERN.test(row.name))
            continue;
        var label = String(_or(row.description, row.name));
        if (row.name.indexOf("raop_sink.") === 0)
            label += " · " + row.name.split(".").slice(-5, -1).join(".");
        out.push({ id: row.name, label: _clean(label, 160) });
    }
    return out;
}
