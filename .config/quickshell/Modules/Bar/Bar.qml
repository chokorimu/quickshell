// Bar.qml — floating pill top bar.
//   left:   now playing (art, title, artist)
//   center: workspaces + clock
//   right:  network, volume, memory, battery
//
// The window reserves the pill's band via exclusiveZone in shell.qml, so
// windows are pushed down while the pill still floats centered inside it.
// Phase 2: three zones with live data and plain styling. The dynamic-island
// expand/collapse behaviour lands in phase 3, and the final look is waiting
// on the Figma pass — so nothing here is final.
import QtQml
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../../Theme"
import "../../Services"

Item {
    id: root

    // load-bearing: as a child of the PanelWindow, this Item does not get
    // resized to fill the window's content item on its own. Without this the
    // root is 0x0 and the pill's horizontalCenter anchor centers against
    // nothing, parking half the pill off the left edge.
    anchors.fill: parent

    readonly property int barHeight: 36
    readonly property int topMargin: 8
    readonly property int pillWidth: 1000

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    function launch(cmd) {
        proc.command = cmd
        proc.running = true
    }

    Process { id: proc }

    // ---- workspaces -----------------------------------------------------
    // Hyprland.workspaces carries the special workspace (-98) and is unordered;
    // flatten to a sorted list of real workspaces only.
    property var workspaces: []

    function reloadWorkspaces() {
        var all = Hyprland.workspaces.values
        var out = []
        for (var i = 0; i < all.length; i++) {
            if (all[i].id > 0)
                out.push(all[i])
        }
        out.sort(function (a, b) { return a.id - b.id })
        root.workspaces = out
    }

    // load-bearing: forces the lazy Hyprland service to populate
    Connections {
        target: Hyprland.workspaces
        function onValuesChanged() { root.reloadWorkspaces() }
    }

    Component.onCompleted: root.reloadWorkspaces()

    // ---- the pill -------------------------------------------------------
    Rectangle {
        id: pill

        anchors.top: parent.top
        anchors.topMargin: root.topMargin
        anchors.horizontalCenter: parent.horizontalCenter

        width: root.pillWidth
        height: root.barHeight
        radius: height / 2
        color: Theme.barBackground

        // ---- left: now playing ------------------------------------------
        Item {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            height: 26
            width: mediaRow.width
            visible: Media.hasPlayer

            Row {
                id: mediaRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Image {
                    width: 22
                    height: 22
                    anchors.verticalCenter: parent.verticalCenter
                    sourceSize: Qt.size(22, 22)
                    fillMode: Image.PreserveAspectCrop
                    clip: true
                    source: Media.artUrl
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Media.title
                    color: Theme.barForeground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    elide: Text.ElideRight
                    width: 180
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Media.artist
                    color: Theme.barDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    elide: Text.ElideRight
                    width: 100
                }
            }

            // click toggles playback, wheel skips — waybar's media bindings
            MouseArea {
                anchors.fill: parent
                onClicked: Media.toggle()
                onWheel: function (wheel) {
                    if (wheel.angleDelta.y > 0)
                        Media.next()
                    else
                        Media.previous()
                }
            }
        }

        // ---- center: workspaces + clock ---------------------------------
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            spacing: 16

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Repeater {
                    model: root.workspaces
                    Rectangle {
                        required property var modelData
                        implicitWidth: 24
                        implicitHeight: 24
                        radius: 7
                        color: modelData.active ? Theme.barHighlight : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: modelData.id
                            color: modelData.active ? Theme.barForeground : Theme.barDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: modelData.activate()
                        }
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(clock.date, "hh:mm")
                color: Theme.barForeground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }
        }

        // ---- right: network, volume, memory, battery --------------------
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 18

            // network — click opens impala
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    if (!Network.connected)
                        return "offline"
                    return Network.kind === "wifi" ? Network.ssid : "ethernet"
                }
                color: Network.connected ? Theme.barForeground : Theme.barDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                elide: Text.ElideRight
                width: 120

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.launch(["kitty", "-e", "impala"])
                }
            }

            // volume — click opens pavucontrol, wheel adjusts
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Audio.muted ? "muted" : "vol " + Math.round(Audio.volume * 100)
                color: Audio.muted ? Theme.barDim : Theme.barForeground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.launch(["pavucontrol"])
                    onWheel: function (wheel) {
                        Audio.nudge(wheel.angleDelta.y > 0 ? 0.05 : -0.05)
                    }
                }
            }

            // memory — click opens btop
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Memory.available ? "mem " + Memory.usedGb.toFixed(1) + "G" : "mem --"
                color: Theme.barForeground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.launch(["kitty", "-e", "btop"])
                }
            }

            // battery
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Battery.present ? Math.round(Battery.percentage * 100) + "%" : "--"
                color: Battery.charging ? Theme.barForeground : (Battery.percentage <= 0.15 ? Theme.barUrgent : Theme.barForeground)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }
        }
    }
}
