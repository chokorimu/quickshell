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
// No MouseArea in here takes hover: a hover-enabled area would steal
// cardZone's hover in Bar.qml and collapse the island under a resting
// cursor. The avatar and the power cells are click-only.
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

        // power grid — lock / logout / reboot / shutdown
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
                    color: Theme.cardHighlight

                    // resting content — the near-black that reads on the
                    // cell's own surface
                    Column {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.glyph
                            color: Theme.cardForeground
                            font.family: Theme.iconFont
                            font.pixelSize: 24
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.label
                            color: Theme.cardDim
                            font.family: Theme.barFontFamily
                            font.pixelSize: 12
                        }
                    }

                    // the wipe — black, from the left, filling the cell
                    // over the hold. Clipped to its own width, with the
                    // content re-drawn inside it in the yellow that
                    // reads on black, so the glyph and label surface
                    // exactly where the fill has reached. The copy
                    // underneath keeps the near-black that reads on the
                    // cell, which is what makes the label legible across
                    // the whole sweep instead of vanishing under it. Two
                    // copies is the price of a centred label on a wiping
                    // fill — one copy would need a colour that reads on
                    // both black and the cell, and there isn't one.
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: cell.width * cell.holdProgress
                        color: "black"
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
                        onPressed: holdAnim.start()
                        onReleased: cell.cancelHold()
                    }
                }
            }
        }
    }
}
