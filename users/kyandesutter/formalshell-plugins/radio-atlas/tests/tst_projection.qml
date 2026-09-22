import QtQuick
import QtTest
import "../lib/RadioModel.js" as RadioModel

// The globe's near-side perspective: projecting and unprojecting a point
// lands back on it, and nothing past the horizon is drawn or picked.
// QT_QPA_PLATFORM=offscreen qmltestrunner -import <qtdeclarative>/lib/qt-6/qml -input tests/tst_projection.qml
TestCase {
    name: "Projection"

    function angleGap(a, b) {
        var gap = Math.abs(a - b) % 360;
        return gap > 180 ? 360 - gap : gap;
    }

    function test_roundTrip_data() {
        return [
            { tag: "centre", lat: 18, lon: -20, lat0: 18, lon0: -20, d: 3.2 },
            { tag: "near", lat: 40.4, lon: -3.7, lat0: 30, lon0: 0, d: 3.2 },
            { tag: "south", lat: -33.9, lon: 151.2, lat0: -20, lon0: 140, d: 2.1 },
            { tag: "dateline", lat: 10, lon: 179.5, lat0: 5, lon0: -175, d: 3.2 },
            { tag: "closeUp", lat: 52.37, lon: 4.9, lat0: 52, lon0: 5, d: 1.05 },
            { tag: "nearHorizon", lat: 0, lon: 70, lat0: 0, lon0: 0, d: 3.2 },
            { tag: "polar", lat: 75, lon: 30, lat0: 70, lon0: -10, d: 4.06 }
        ];
    }

    function test_roundTrip(row) {
        var p = RadioModel.projectPerspective(row.lat, row.lon, row.lat0, row.lon0, row.d);
        verify(p.visible, "point should be on the near side");
        var back = RadioModel.unproject(p.x, p.y, row.lat0, row.lon0, row.d);
        verify(back !== null, "unproject missed the sphere");
        verify(Math.abs(back.latitude - row.lat) < 1e-6, "latitude " + back.latitude + " vs " + row.lat);
        verify(angleGap(back.longitude, row.lon) < 1e-6, "longitude " + back.longitude + " vs " + row.lon);
    }

    function test_pastHorizonRejected() {
        // cos 80 degrees is 0.17, under 1 / 3.2.
        verify(!RadioModel.projectPerspective(0, 80, 0, 0, 3.2).visible);
        verify(!RadioModel.projectPerspective(0, 180, 0, 0, 3.2).visible);
        // cos 71 degrees is 0.326, just over it.
        verify(RadioModel.projectPerspective(0, 71, 0, 0, 3.2).visible);
        var r = RadioModel.horizonRatio(3.2) * 1.001;
        compare(RadioModel.unproject(r, 0, 0, 0, 3.2), null);
        compare(RadioModel.unproject(0, -r, 12, 40, 3.2), null);
        verify(RadioModel.unproject(r * 0.99, 0, 0, 0, 3.2) !== null);
    }

    function test_horizonCircle() {
        var d = 3.2;
        var c = Math.acos(1 / d) * 180 / Math.PI;
        var p = RadioModel.projectPerspective(0, c, 0, 0, d);
        verify(Math.abs(Math.sqrt(p.x * p.x + p.y * p.y) - RadioModel.horizonRatio(d)) < 1e-9);
    }

    function test_stationsPastHorizonNotPicked() {
        var stations = [
            { uuid: "far", latitude: 0, longitude: 100 },
            { uuid: "near", latitude: 0, longitude: 5 }
        ];
        compare(RadioModel.nearestVisibleStation(stations, 0, 0, "near", 800, 600, 1).uuid, "near");
        compare(RadioModel.stationPosition(stations[0], 800, 600, 1, 0, 0), null);
    }

    function test_zoomClamp() {
        verify(RadioModel.viewDistance(1) === 3.2);
        verify(RadioModel.viewDistance(1000) >= 1.05);
        verify(RadioModel.viewDistance(24) < RadioModel.viewDistance(1));
    }
}
