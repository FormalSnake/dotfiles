// Animated overlay for the SDDM greeter: glyph rain, a faint grid, CRT
// scanlines and a decorative boot log. Spliced into the
// sddm-astronaut theme by the override in modules/nixos/mixins/hyprland.nix
// as a layer over the preset wallpaper, behind a Loader, so a QML error here
// costs the animation and leaves the login form working.
//
// Everything is generated at runtime rather than shipped as a video: the
// greeter has to look right on the 1080p panels and on whatever is plugged
// into HDMI, and a fixed-resolution clip does not.

import QtQuick

Item {
    id: bg

    readonly property color rainColor: "#2ef58a"
    readonly property color headColor: "#c8fff0"
    readonly property color gridColor: "#0d3b34"
    readonly property color logColor: "#1f8f5c"

    // Halfwidth katakana carries the look; the hex digits and symbols keep it
    // readable as machine output. The rain runs in Noto CJK Mono because
    // GeistMono has no katakana at all; the log line below is ASCII, so it
    // keeps the system terminal face. font.families does not exist in this Qt
    // build, so both are single families rather than a fallback list.
    readonly property string glyphs: "ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ0123456789ABCDEF<>/|=+*#%"
    readonly property string glyphFont: "Noto Sans Mono CJK JP"
    readonly property string logFont: "GeistMono Nerd Font"

    readonly property int cell: 26
    readonly property int trail: 18
    readonly property int columnCount: Math.max(1, Math.floor(width / cell))

    function randomGlyph() {
        return glyphs.charAt(Math.floor(Math.random() * glyphs.length))
    }

    // Static grid. Painted once per resize, not per frame.
    Canvas {
        id: grid

        anchors.fill: parent
        opacity: 0.55

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = bg.gridColor
            ctx.lineWidth = 1
            for (var x = 0; x < width; x += 64) {
                ctx.beginPath()
                ctx.moveTo(x + 0.5, 0)
                ctx.lineTo(x + 0.5, height)
                ctx.stroke()
            }
            for (var y = 0; y < height; y += 64) {
                ctx.beginPath()
                ctx.moveTo(0, y + 0.5)
                ctx.lineTo(width, y + 0.5)
                ctx.stroke()
            }
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    Item {
        id: rain

        anchors.fill: parent
        clip: true

        Repeater {
            model: bg.columnCount

            Item {
                id: column

                x: index * bg.cell
                width: bg.cell
                height: bg.trail * bg.cell

                function reroll() {
                    for (var i = 0; i < glyphColumn.count; i++) {
                        var glyph = glyphColumn.itemAt(i)
                        if (glyph)
                            glyph.text = bg.randomGlyph()
                    }
                }

                Column {
                    spacing: 0

                    Repeater {
                        id: glyphColumn

                        model: bg.trail

                        Text {
                            width: bg.cell
                            height: bg.cell
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.family: bg.glyphFont
                            font.pixelSize: bg.cell - 7
                            color: index === bg.trail - 1 ? bg.headColor : bg.rainColor
                            // Square falloff so only the last few glyphs read
                            // as the leading edge.
                            opacity: Math.pow((index + 1) / bg.trail, 2.2) * 0.9
                            text: bg.randomGlyph()
                        }
                    }
                }

                property int speed: 4500 + Math.round(Math.random() * 9000)
                property real seed: Math.random()

                SequentialAnimation {
                    // Held until the backdrop has a height, otherwise the
                    // Loader can start the fall against a zero-height parent
                    // and every column parks at y 0.
                    running: bg.height > 0

                    // The first pass starts partway down, so the rain is
                    // already spread over the screen when the greeter paints
                    // instead of filling in over the first ten seconds.
                    NumberAnimation {
                        target: column
                        property: "y"
                        from: -column.height + column.seed * (bg.height + column.height)
                        to: bg.height
                        duration: Math.max(1, Math.round(column.speed * (1 - column.seed)))
                    }

                    SequentialAnimation {
                        loops: Animation.Infinite

                        NumberAnimation {
                            target: column
                            property: "y"
                            from: -column.height
                            to: bg.height
                            duration: column.speed
                            onStarted: column.reroll()
                        }
                    }
                }

                // Churns one glyph at a time rather than the whole column, so
                // the cost stays at one text assignment per column per tick.
                Timer {
                    interval: 140 + Math.round(Math.random() * 220)
                    running: true
                    repeat: true
                    onTriggered: {
                        var i = Math.random() < 0.5 ? bg.trail - 1
                                                    : Math.floor(Math.random() * bg.trail)
                        var glyph = glyphColumn.itemAt(i)
                        if (glyph)
                            glyph.text = bg.randomGlyph()
                    }
                }
            }
        }
    }

    // Darkens the middle strip the login form sits in so the rain never
    // fights the username and password fields for contrast.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        height: parent.height
        width: Math.min(parent.width, 980)

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0) }
            GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.7) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0) }
        }
    }

    Canvas {
        id: vignette

        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var gradient = ctx.createRadialGradient(width / 2, height / 2,
                                                    Math.min(width, height) * 0.2,
                                                    width / 2, height / 2,
                                                    Math.max(width, height) * 0.72)
            gradient.addColorStop(0.0, Qt.rgba(0, 0, 0, 0))
            gradient.addColorStop(0.6, Qt.rgba(0, 0, 0, 0.45))
            gradient.addColorStop(1.0, Qt.rgba(0, 0, 0, 0.9))
            ctx.fillStyle = gradient
            ctx.fillRect(0, 0, width, height)
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    // Scanlines: one draw call, all rectangles share a colour and material.
    Item {
        anchors.fill: parent
        opacity: 0.22

        Repeater {
            model: Math.ceil(bg.height / 3)

            Rectangle {
                y: index * 3
                width: bg.width
                height: 1
                color: "#000000"
            }
        }
    }

    // Slow CRT roll bar.
    Rectangle {
        width: parent.width
        height: 200
        opacity: 0.05

        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0) }
            GradientStop { position: 0.5; color: bg.rainColor }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0) }
        }

        NumberAnimation on y {
            from: -200
            to: bg.height
            duration: 7000
            loops: Animation.Infinite
        }
    }

    // Decorative boot log. Flavour text, not real system state.
    Column {
        id: bootLog

        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 34
        anchors.bottomMargin: 30
        spacing: 3
        opacity: 0.6

        readonly property var lines: [
            "[ ok ] mount /nix/store  read-only",
            "[ ok ] seed entropy pool  256 bit",
            "[ ok ] link up  tailscale0",
            "[ ok ] compositor  weston  kiosk",
            "[ ok ] gpu power state  D0",
            "[ ok ] session bus  ready",
            "[ .. ] handshake  chacha20-poly1305",
            "[ .. ] probing 0x7ffd  no route",
            "[ .. ] awaiting operator",
            "[ ok ] keyring  unlocked on login",
            "[ ok ] clock skew  0.002s",
            "[ .. ] listening  /dev/null"
        ]

        property var shown: []
        property int cursor: 0

        Repeater {
            model: bootLog.shown

            Text {
                text: modelData
                color: bg.logColor
                font.family: bg.logFont
                font.pixelSize: 13
            }
        }

        Text {
            text: "_"
            color: bg.headColor
            font.family: bg.logFont
            font.pixelSize: 13

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { to: 0; duration: 90 }
                PauseAnimation { duration: 520 }
                NumberAnimation { to: 1; duration: 90 }
                PauseAnimation { duration: 520 }
            }
        }

        Timer {
            interval: 900
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                var next = bootLog.shown.slice()
                next.push(bootLog.lines[bootLog.cursor % bootLog.lines.length])
                bootLog.cursor++
                if (next.length > 9)
                    next.shift()
                bootLog.shown = next
            }
        }
    }
}
