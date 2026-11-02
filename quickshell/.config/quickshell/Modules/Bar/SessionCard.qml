// SessionCard.qml — the island's third menu: the power menu.
//
// Same card and pop as the media and volume pages; reached by hovering
// the third tab button in the column. A big avatar (click to change),
// the user@host line under it, and a grid of power actions below.
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
        // light up in the launcher's selection yellow under the
        // cursor, with the glyph and label knocked out in the
        // near-black that goes with it (launcherSelectionOn) — the
        // same fixed pair the launcher's selected row uses, which is
        // why it is yellow in both themes rather than following the
        // palette. The black wipe paints straight over the yellow, so
        // what the fill's edge is judged against is yellow, not the
        // card: black-on-yellow is 14.67:1 where black-on-card is
        // 1.47:1.
        GridLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            columns: 4
            columnSpacing: 12
            rowSpacing: 12

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
                    radius: 16

                    // the launcher's selection yellow under the cursor
                    color: sessionCard.hoveredCell === index
                        ? Theme.launcherSelection
                        : Theme.cardHighlight

                    // eases the fill in rather than snapping it
                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }

                    // resting content — the near-black that reads on
                    // yellow, or the card's own ink on the grey
                    Column {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.glyph
                            color: sessionCard.hoveredCell === index
                                ? Theme.launcherSelectionOn
                                : Theme.cardForeground
                            font.family: Theme.iconFont
                            font.pixelSize: 24
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.label
                            color: sessionCard.hoveredCell === index
                                ? Theme.launcherSelectionOn
                                : Theme.cardDim
                            font.family: Theme.barFontFamily
                            font.pixelSize: 12
                        }
                    }

                    // the wipe — black, from the left, filling the cell
                    // over the hold. A Canvas clipped to the cell's own
                    // rounded-rect path (ctx.clip(), the same clockwise
                    // outline Bar.qml's card canvas draws), filled black
                    // from the left edge to width * holdProgress.
                    //
                    // Clipping to the path instead of painting a rounded
                    // Rectangle buys two things. The silhouette is the
                    // cell's silhouette exactly — same path, same
                    // radius, same geometry — so the black is never a
                    // hair smaller than the button. And the leading edge
                    // is the fillRect's own: hard and vertical. A
                    // Rectangle's radius rounds all four of its corners,
                    // so a rounded Rectangle wipe wore a soft rounded tip
                    // that never reached as far as the progress said —
                    // and at low progress Qt clamped the radius to half
                    // the width and the whole fill collapsed into a pill.
                    // That is why the black read smaller than the button.
                    //
                    // The content is re-drawn on top in the yellow that
                    // reads on black, clipped to the same width the fill
                    // has reached, so the glyph and label surface
                    // exactly where the black has landed. The copy
                    // underneath keeps the near-black that reads on the
                    // cell, which is what makes the label legible across
                    // the whole sweep instead of vanishing under it. Two
                    // copies is the price of a centred label on a wiping
                    // fill — one copy would need a colour that reads on
                    // both black and the cell, and there isn't one. Both
                    // copies stay QML Text: drawing the glyph in the
                    // canvas would put it on the canvas's own font and
                    // baseline, which does not have to match the Text's,
                    // and a mismatch at the seam is the one thing the
                    // two-copy trick exists to avoid.
                    Canvas {
                        id: wipe
                        anchors.fill: parent

                        onPaint: {
                            var w = width
                            var h = height
                            var r = cell.radius
                            var ctx = getContext("2d")

                            ctx.clearRect(0, 0, w, h)
                            ctx.beginPath()

                            // one clockwise outline: top edge, top-right
                            // cap, right edge, bottom-right cap, bottom
                            // edge, bottom-left cap, left edge, top-left
                            // cap. Every arc starts at the point the
                            // path is already standing on, or canvas
                            // silently inserts a straight connector and
                            // the curve collapses.
                            ctx.moveTo(r, 0)
                            ctx.lineTo(w - r, 0)
                            ctx.arc(w - r, r, r, -Math.PI / 2, 0, false)
                            ctx.lineTo(w, h - r)
                            ctx.arc(w - r, h - r, r, 0, Math.PI / 2, false)
                            ctx.lineTo(r, h)
                            ctx.arc(r, h - r, r, Math.PI / 2, Math.PI, false)
                            ctx.lineTo(0, r)
                            ctx.arc(r, r, r, Math.PI, 3 * Math.PI / 2, false)
                            ctx.closePath()

                            // the fill is clipped to the cell's
                            // silhouette; the leading edge is the
                            // fillRect's own, hard and vertical
                            ctx.save()
                            ctx.clip()
                            ctx.fillStyle = "black"
                            ctx.fillRect(0, 0, w * cell.holdProgress, h)
                            ctx.restore()
                        }

                        // a Canvas repaints only on request, so every
                        // frame of the hold asks for one
                        Connections {
                            target: cell
                            function onHoldProgressChanged() { wipe.requestPaint() }
                        }
                    }

                    // the yellow copy of the content, clipped to the
                    // width the black has reached. Transparent itself —
                    // only the children paint — and the copy sits in a
                    // full-cell-sized Item so it stays centred in the
                    // cell and never reaches the corners the clip cuts.
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: cell.width * cell.holdProgress
                        color: "transparent"
                        clip: true

                        Item {
                            width: cell.width
                            height: cell.height

                            Column {
                                anchors.centerIn: parent
                                spacing: 8

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.glyph
                                    color: Theme.launcherSelection
                                    font.family: Theme.iconFont
                                    font.pixelSize: 24
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.label
                                    color: Theme.launcherSelection
                                    font.family: Theme.barFontFamily
                                    font.pixelSize: 12
                                }
                            }
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
