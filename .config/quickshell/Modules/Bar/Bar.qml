// Bar.qml — floating pill top bar.
//   left:   "//" + now playing (circular art, scrolling "Artist - Song") + workspaces
//   center: clock
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
    readonly property int pillWidth: 1200
    readonly property int workspacePillHeight: 30
    readonly property int workspaceCircleSize: 22

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
    // Hyprland.workspaces carries the special workspace (-98), is unordered,
    // and only lists workspaces that actually exist. Workspaces 1-4 are
    // persistent — always shown, with plain placeholder entries when empty —
    // and any real workspace above 4 is appended after them, sorted.
    property var workspaces: []

    function reloadWorkspaces() {
        var all = Hyprland.workspaces.values
        var real = {}
        var extra = []
        for (var i = 0; i < all.length; i++) {
            if (all[i].id <= 0)
                continue
            if (all[i].id <= 4)
                real[all[i].id] = all[i]
            else
                extra.push(all[i])
        }
        extra.sort(function (a, b) { return a.id - b.id })

        var out = []
        for (var id = 1; id <= 4; id++) {
            if (real[id])
                out.push(real[id])
            else
                out.push({ id: id, active: false })
        }
        root.workspaces = out.concat(extra)
    }

    // Quickshell 0.3.2 interpolates the request raw into a Lua call
    // (hl.dispatch(<request>)). With this Hyprland's Lua config the legacy
    // string form ("workspace N") is a syntax error and the quoted form is
    // rejected as "expected a dispatcher" — the working request is a real
    // dispatcher object: hl.dsp.focus({workspace = N}). This also creates
    // the workspace on demand, which is what makes the 1-4 placeholders
    // clickable. Native workspace.activate() works too, but only for
    // workspaces that already exist.
    function activateWorkspace(id) {
        Hyprland.dispatch("hl.dsp.focus({workspace = " + id + "})")
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

        // ---- left: // + now playing + workspaces ------------------------
        Row {
            id: leftRow
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            // decorative prefix
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "//"
                color: Theme.barForeground
                font.family: Theme.barFontFamily
                font.pixelSize: Theme.barFontSize
            }

            // ---- now playing: circular art + scrolling "Artist - Song" ---
            // Always visible — shows a dim "Not playing" when no player has a
            // track, so the left zone keeps a stable shape.
            Item {
                anchors.verticalCenter: parent.verticalCenter
                height: 26
                width: artCircle.width + 10 + mediaScroll.width

                Rectangle {
                    id: artCircle
                    width: 22
                    height: 22
                    anchors.verticalCenter: parent.verticalCenter
                    radius: width / 2
                    color: Theme.barHighlight
                    clip: true

                    Image {
                        anchors.fill: parent
                        sourceSize: Qt.size(22, 22)
                        fillMode: Image.PreserveAspectCrop
                        source: Media.artUrl
                    }
                }

                // marquee window: clips the text and scrolls it whenever the
                // full "Artist - Song" string is wider than the window, so
                // nothing is permanently cut off
                Item {
                    id: mediaScroll
                    anchors.left: artCircle.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 180
                    height: mediaText.implicitHeight
                    clip: true

                    property real overflow: Math.max(0, mediaText.implicitWidth - width)
                    property bool needsScroll: overflow > 1

                    onNeedsScrollChanged: if (!needsScroll) mediaText.x = 0

                    Text {
                        id: mediaText
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            if (!Media.hasPlayer)
                                return "Not playing"
                            var a = (Media.artist || "").trim()
                            var t = (Media.title || "").trim()
                            if (a && t)
                                return a + " - " + t
                            return a || t || "Not playing"
                        }
                        color: Media.hasPlayer ? Theme.barForeground : Theme.barDim
                        font.family: Theme.barFontFamily
                        font.pixelSize: Theme.barFontSize
                        width: implicitWidth

                        onTextChanged: {
                            mediaText.x = 0
                            if (mediaScroll.needsScroll)
                                scrollAnim.restart()
                        }
                    }

                    SequentialAnimation {
                        id: scrollAnim
                        running: mediaScroll.needsScroll
                        loops: Animation.Infinite
                        NumberAnimation {
                            target: mediaText
                            property: "x"
                            from: 0
                            to: -mediaScroll.overflow
                            duration: mediaScroll.overflow * 30
                        }
                        PauseAnimation { duration: 1600 }
                        NumberAnimation {
                            target: mediaText
                            property: "x"
                            from: -mediaScroll.overflow
                            to: 0
                            duration: mediaScroll.overflow * 30
                        }
                        PauseAnimation { duration: 1600 }
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

            // ---- workspaces: black pill with circular buttons -------------
            // Inverted island inside the white pill — near-black container,
            // circular buttons, active one filled white with a dark number.
            Rectangle {
                id: workspacePill
                anchors.verticalCenter: parent.verticalCenter
                height: root.workspacePillHeight
                radius: height / 2
                color: Theme.barInk
                width: workspaceRow.implicitWidth + 8

                Row {
                    id: workspaceRow
                    anchors.centerIn: parent
                    spacing: 4

                    Repeater {
                        model: root.workspaces
                        Rectangle {
                            required property var modelData
                            implicitWidth: root.workspaceCircleSize
                            implicitHeight: root.workspaceCircleSize
                            radius: implicitWidth / 2
                            color: modelData.active ? Theme.barBackground : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: modelData.id
                                color: modelData.active ? Theme.barInk : Theme.barDim
                                font.family: Theme.barFontFamily
                                font.pixelSize: Theme.barFontSizeSmall
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.activateWorkspace(modelData.id)
                            }
                        }
                    }
                }
            }
        }

        // ---- center: clock ------------------------------------------------
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(clock.date, "hh:mm ddd, MMM d")
            color: Theme.barForeground
            font.family: Theme.barFontFamily
            font.pixelSize: Theme.barFontSize
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
                font.family: Theme.barFontFamily
                font.pixelSize: Theme.barFontSize
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
                font.family: Theme.barFontFamily
                font.pixelSize: Theme.barFontSize

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
                font.family: Theme.barFontFamily
                font.pixelSize: Theme.barFontSize

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
                font.family: Theme.barFontFamily
                font.pixelSize: Theme.barFontSize
            }
        }
    }
}
