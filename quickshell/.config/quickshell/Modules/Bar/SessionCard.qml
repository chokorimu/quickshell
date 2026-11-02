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
// cursor — and that is exactly the trap this note used to warn
// about: a hover-enabled MouseArea inside the card steals cardZone's
// hover in Bar.qml and collapses the island under a resting cursor.
// The cells therefore report their hover up through `hoveredCell`,
// and Bar.qml ORs it into its own `hovered` the same way the tab
// buttons arrive through columnHovered. The avatar stays click-only.
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
    // for the tab buttons.
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

    // one-shot process for the power actions — command set per click
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
                    Layout.preferredWidth: 104
                    Layout.preferredHeight: 88
                    radius: 10
                    color: sessionCard.hoveredCell === index
                        ? Theme.launcherSelection
                        : Theme.cardHighlight

                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }

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

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        // last writer wins, and the guard on exit
                        // keeps a fast cross-cell move from clearing
                        // a cell that has already taken over
                        onEntered: sessionCard.hoveredCell = index
                        onExited: if (sessionCard.hoveredCell === index)
                            sessionCard.hoveredCell = -1
                        onClicked: {
                            powerProc.command = modelData.cmd
                            powerProc.running = true
                        }
                    }
                }
            }
        }
    }
}
