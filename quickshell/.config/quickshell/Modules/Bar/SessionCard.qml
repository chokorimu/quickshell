// SessionCard.qml — the island's fifth menu: the power menu.
//
// Same card and pop as the media, volume, theme and capture pages;
// reached by hovering the fifth tab button in the column. A big avatar
// (click to change), the user@host line under it, and a grid of power
// actions below.
//
// The avatar lives at ~/.config/quickshell/avatar.png — picked through
// a file dialog and copied into place, so it survives restarts. The
// user comes from $USER and the hostname from /proc/sys/kernel/hostname
// (no env var is guaranteed to carry it).
//
// The power cells DO take hover — they light up yellow under the
// cursor, and a hold has to cancel when the cursor walks off — and
// that is exactly the trap this note used to warn about: a
// hover-enabled MouseArea inside the card steals cardZone's hover in
// Bar.qml and collapses the island under a resting cursor. The cells
// therefore report their hover up through `hoveredCell`, and Bar.qml
// ORs it into its own `hovered` the same way the tab buttons arrive
// through columnHovered. The avatar stays click-only.
import QtQml
import QtQuick
import QtQuick.Dialogs
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../Theme"

Item {
    id: sessionCard

    readonly property string user: Quickshell.env("USER") || "user"
    property string hostname: ""

    readonly property string avatarPath: Quickshell.env("HOME") + "/.config/quickshell/avatar.png"

    // Which power cell the cursor is on, -1 for none. Exists so the
    // cells can take hover without collapsing the island: a
    // hover-enabled MouseArea in here steals cardZone's hover in
    // Bar.qml, so the cells report up through this and Bar.qml ORs
    // `hovered` into its own — the same handoff columnHovered does
    // for the tab buttons. It is plumbing, not styling: the cells are
    // still grey at rest.
    property int hoveredCell: -1
    readonly property bool hovered: hoveredCell >= 0

    // hostname — read once; the card is short-lived enough that a
    // change mid-session is not worth a watcher
    Process {
        running: true
        command: ["cat", "/proc/sys/kernel/hostname"]
        stdout: StdioCollector {
            onStreamFinished: sessionCard.hostname = this.text.trim()
        }
    }

    // does an avatar exist yet? Checked with test -f rather than by
    // pointing the Image at a missing file, which would log a load
    // error on every shell reload
    Process {
        running: true
        command: ["test", "-f", sessionCard.avatarPath]
        onExited: (code) => {
            if (code === 0)
                avatar.source = "file://" + sessionCard.avatarPath
        }
    }

    // the picked avatar, copied into place; on success the Image is
    // re-pointed at the same path (a same-value assignment would not
    // reload, hence the clear-then-set)
    Process {
        id: copyProc
        onExited: (code) => {
            if (code === 0) {
                avatar.source = ""
                avatar.source = "file://" + sessionCard.avatarPath
            }
        }
    }

    FileDialog {
        id: avatarPicker
        title: "Choose an avatar"
        nameFilters: ["Images (*.png *.jpg *.jpeg *.svg *.webp *.bmp)"]
        onAccepted: {
            var path = decodeURIComponent(avatarPicker.selectedFile.toString().replace(/^file:\/\//, ""))
            copyProc.command = ["cp", path, sessionCard.avatarPath]
            copyProc.running = true
        }
    }

    // How long a power cell must be held before it fires. Long enough
    // that a stray click cannot power the machine off, short enough
    // that it does not feel like work.
    readonly property int holdDuration: 1500

    // How thick the traced ring is, in logical pixels. The path the
    // stroke follows is inset by half of this, so the ring's outer
    // edge lands exactly on the cell's silhouette.
    readonly property real holdRingWidth: 5

    // one-shot process for the power actions — command set per hold
    Process {
        id: powerProc
    }

    // the group, centered in the card's content area (the 28px offset
    // mirrors the media page's cardColumnWidth / 2 centering)
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: 28
        anchors.verticalCenter: parent.verticalCenter
        spacing: 24

        // avatar — click to change; a user glyph stands in until an
        // image is picked. Centered on the column with an explicit
        // anchor — a plain Column left-aligns its children, so without
        // it the frame would sit at the column's left edge while the
        // text and grid below center themselves.
        Rectangle {
            id: avatarFrame
            anchors.horizontalCenter: parent.horizontalCenter
            width: 160
            height: 160
            radius: width / 2
            color: Theme.cardHighlight
            clip: true

            Image {
                id: avatar
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                source: ""
                visible: status === Image.Ready
            }

            Text {
                anchors.centerIn: parent
                text: "\uF007" // user
                visible: avatar.status !== Image.Ready
                color: Theme.cardDim
                font.family: Theme.iconFont
                font.pixelSize: 72
            }

            MouseArea {
                anchors.fill: parent
                onClicked: avatarPicker.open()
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: sessionCard.hostname.length > 0
                ? sessionCard.user + "@" + sessionCard.hostname
                : sessionCard.user
            color: Theme.cardForeground
            font.family: Theme.barFontFamily
            font.pixelSize: 18
        }

        // power grid — lock / logout / reboot / shutdown. The cells
        // lighten under the cursor to Theme.cardHover — a neutral that
        // is light in both palettes — with the glyph and label knocked
        // out in cardHoverOn. The hold traces a black ring around the
        // cell's own outline, so what that ring is judged against is
        // the light fill rather than the card: black-on-light is
        // 14-17:1 where black-on-cardHighlight is 1.7:1 in the dark
        // palette.
        GridLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            columns: 4
            columnSpacing: 8
            rowSpacing: 8

            Repeater {
                model: [
                    { glyph: "\uF023", label: "Lock",     cmd: ["hyprlock"] },
                    { glyph: "\uF08B", label: "Log out",  cmd: ["hyprctl", "dispatch", "exit"] },
                    { glyph: "\uF021", label: "Reboot",   cmd: ["systemctl", "reboot"] },
                    { glyph: "\uF011", label: "Shut down", cmd: ["systemctl", "poweroff"] }
                ]

                Rectangle {
                    id: cell

                    // 0 -> 1 across the hold. The wipe's width reads it,
                    // and the animation's onFinished is what fires the
                    // action, so the bar and the trigger can never
                    // disagree about how far along the hold is.
                    property real holdProgress: 0

                    Layout.preferredWidth: 104
                    Layout.preferredHeight: 88
                    radius: 10

                    // the hover fill lightens the cell in both
                    // palettes, because the wipe is black and its
                    // leading edge has to read against whatever it
                    // lands on
                    color: sessionCard.hoveredCell === index
                        ? Theme.cardHover
                        : Theme.cardHighlight

                    // eases the fill in rather than snapping it
                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }

                    // resting content — the near-black that reads on
                    // the light hover fill, or the card's own ink on
                    // the grey
                    Column {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.glyph
                            color: sessionCard.hoveredCell === index
                                ? Theme.cardHoverOn
                                : Theme.cardForeground
                            font.family: Theme.iconFont
                            font.pixelSize: 24
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.label
                            color: sessionCard.hoveredCell === index
                                ? Theme.cardHoverOn
                                : Theme.cardDim
                            font.family: Theme.barFontFamily
                            font.pixelSize: 12
                        }
                    }

                    // the wipe — a ring of black traced around the
                    // cell's own rounded-rect outline, filling clockwise
                    // from the top centre as the hold runs.
                    //
                    // A Canvas rather than a stroked Rectangle for the
                    // same reason the old fill was one: the silhouette
                    // has to be the cell's silhouette exactly, and a
                    // Rectangle's radius rounds all four of its corners.
                    //
                    // The path is inset by half the ring's width so the
                    // stroke's outer edge lands exactly on the cell's
                    // boundary. A stroke straddles the path it follows,
                    // so an un-inset one would paint half the ring onto
                    // the card outside the button.
                    //
                    // The progress is a walk along that path: the
                    // perimeter is computed from the same inset geometry,
                    // then the outline is traced segment by segment until
                    // the hold's share of it is drawn and stops there.
                    // That leading end is the readout, and it starts at
                    // the top centre and runs clockwise.
                    //
                    // The interior never changes colour, so the content
                    // needs no second copy — the glyph and label sit
                    // near-black on the hover fill for the whole hold.
                    // That is the other thing the ring buys over the
                    // sweep: the old wipe needed a duplicated Text in the
                    // fill's colour, because one copy would have had to
                    // read on both black and the cell.
                    Canvas {
                        id: wipe
                        anchors.fill: parent

                        onPaint: {
                            var w = width
                            var h = height
                            var r = cell.radius
                            var ring = sessionCard.holdRingWidth
                            var o = ring / 2

                            // the inset outline the stroke is centred on:
                            // the ring's outer edge lands on the cell's
                            // boundary, its inner edge one ring in
                            var x0 = o, y0 = o, x1 = w - o, y1 = h - o
                            var rr = r - o

                            // the outline as nine segments, clockwise from
                            // the top centre: four straight runs and four
                            // quarter arcs, split either side of the top
                            // centre so the trace starts at 12 o'clock.
                            // Straights carry a start and an end; arcs a
                            // centre, a radius and the angles they sweep.
                            var S = [
                                { x0: w / 2,  y0: y0,     x1: x1 - rr, y1: y0 },
                                { cx: x1 - rr, cy: y0 + rr, r: rr, a0: -Math.PI / 2, a1: 0 },
                                { x0: x1,     y0: y0 + rr,  x1: x1,     y1: y1 - rr },
                                { cx: x1 - rr, cy: y1 - rr,  r: rr, a0: 0,             a1: Math.PI / 2 },
                                { x0: x1 - rr, y0: y1,       x1: x0 + rr, y1: y1 },
                                { cx: x0 + rr, cy: y1 - rr,  r: rr, a0: Math.PI / 2,   a1: Math.PI },
                                { x0: x0,     y0: y1 - rr,  x1: x0,     y1: y0 + rr },
                                { cx: x0 + rr, cy: y0 + rr,  r: rr, a0: Math.PI,       a1: 3 * Math.PI / 2 },
                                { x0: x0 + rr, y0: y0,       x1: w / 2,  y1: y0 }
                            ]

                            // perimeter — straights by distance, arcs by
                            // swept angle times radius
                            var per = 0
                            for (var i = 0; i < S.length; i++) {
                                var s = S[i]
                                s.len = (s.cx !== undefined)
                                    ? (s.a1 - s.a0) * s.r
                                    : Math.sqrt((s.x1 - s.x0) * (s.x1 - s.x0)
                                        + (s.y1 - s.y0) * (s.y1 - s.y0))
                                per += s.len
                            }

                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, w, h)

                            // nothing to trace at rest
                            if (cell.holdProgress <= 0)
                                return

                            // walk the outline until the hold's share of
                            // it is drawn, then stop. Each segment is
                            // drawn whole or cut at the fraction of it the
                            // remaining length covers, and that leading
                            // end is the progress readout. No dash is
                            // involved: setLineDash is not honoured by
                            // this Canvas, so a dashed stroke came back
                            // as a full ring at every progress.
                            var remain = per * cell.holdProgress
                            ctx.beginPath()
                            ctx.moveTo(w / 2, y0)
                            for (var j = 0; j < S.length && remain > 0; j++) {
                                var g = S[j]
                                var f = remain >= g.len ? 1 : remain / g.len
                                remain -= g.len
                                if (g.cx !== undefined)
                                    ctx.arc(g.cx, g.cy, g.r, g.a0,
                                        g.a0 + (g.a1 - g.a0) * f, false)
                                else
                                    ctx.lineTo(g.x0 + (g.x1 - g.x0) * f,
                                        g.y0 + (g.y1 - g.y0) * f)
                            }

                            ctx.lineWidth = ring
                            ctx.lineCap = "butt"
                            ctx.strokeStyle = "black"
                            ctx.stroke()
                        }

                        // a Canvas repaints only on request, so every
                        // frame of the hold asks for one
                        Connections {
                            target: cell
                            function onHoldProgressChanged() { wipe.requestPaint() }
                        }
                    }

                    // released early, or dragged off the cell
                    function cancelHold() {
                        holdAnim.stop()
                        cell.holdProgress = 0
                    }

                    NumberAnimation {
                        id: holdAnim
                        target: cell
                        property: "holdProgress"
                        from: 0
                        to: 1
                        duration: sessionCard.holdDuration
                        onFinished: {
                            powerProc.command = modelData.cmd
                            powerProc.running = true
                            cell.holdProgress = 0
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        // keeps a fast cross-cell move from clearing
                        // a cell that has already taken over
                        onEntered: sessionCard.hoveredCell = index
                        onExited: {
                            if (sessionCard.hoveredCell === index)
                                sessionCard.hoveredCell = -1
                            cell.cancelHold()
                        }
                        onPressed: holdAnim.start()
                        onReleased: cell.cancelHold()
                    }
                }
            }
        }
    }
}
