// Capture.qml — the island's fourth menu: capture.
//
// Same card and pop as the media, volume, theme and session pages;
// reached by hovering the fourth tab button in the column. Three
// sections: screenshot (output / window / region), clipboard viewing,
// and screen recording.
//
// This is the skeleton — the tab, the page gating and the layout are
// real, the buttons are placeholders. Each section notes which walk
// step wires it.
//
// The pills are click-only on purpose, the same rule the session and
// theme pages follow: a hover-enabled MouseArea in here steals
// cardZone's hover in Bar.qml and collapses the island under a
// resting cursor. Anything that needs hover later (a recording timer,
// say) has to report up through `hovered` the way SessionCard's power
// cells do.
import QtQuick
import "../../Theme"
// the header mark lives with the other cards; this is the first
// cross-module import in the tree, and it is circular with Bar.qml's
// own import of ../Capture — QML resolves both lazily, verified by
// load
import "../Bar"

Item {
    id: capturePage

    // Plumbing for Bar.qml's hover OR-in. Nothing in the skeleton
    // takes hover of its own, so this stays false — but the pattern
    // has to exist before a section grows a hover-enabled control, or
    // the first one to ship collapses the island under the cursor.
    property bool hovered: false

    // title row — header mark + "Capture", left-aligned. The 80px
    // margin clears the menu column strip (56 wide), so nothing rides
    // it.
    Row {
        id: titleRow
        anchors.top: parent.top
        anchors.topMargin: 28
        anchors.left: parent.left
        anchors.leftMargin: 80
        spacing: 12

        HeaderIcon {
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "CAPTURE"
            color: Theme.cardForeground
            font.family: Theme.barFontFamily
            font.pixelSize: 20
            font.weight: Font.DemiBold
        }
    }

    // the sections, stacked under the header and left-aligned on the
    // content area's margin, the way the volume and theme pages flow
    Column {
        anchors.top: titleRow.bottom
        anchors.topMargin: 24
        anchors.left: parent.left
        anchors.leftMargin: 80
        spacing: 28

        // ---- screenshot: output / window / region ----------------------
        // Step 2 wires these to hyprshot (-m output / -m window /
        // -m region). Region capture has to dismiss the island first:
        // slurp takes the input grab, and with hyprshot's -z freeze the
        // card would be frozen into the shot.
        Column {
            anchors.left: parent.left
            spacing: 10

            Text {
                text: "Screenshot"
                color: Theme.cardDim
                font.family: Theme.barFontFamily
                font.pixelSize: 12
            }

            Row {
                anchors.left: parent.left
                spacing: 8

                Repeater {
                    model: ["Output", "Window", "Region"]

                    delegate: Rectangle {
                        id: shotPill
                        height: 36
                        // content-driven width — the label plus even
                        // side padding, so the three pills read as one
                        // family without hand-tuned numbers
                        width: shotPillLabel.implicitWidth + 36
                        radius: 18
                        color: Theme.cardHighlight

                        Text {
                            id: shotPillLabel
                            anchors.centerIn: parent
                            text: modelData
                            color: Theme.cardForeground
                            font.family: Theme.barFontFamily
                            font.pixelSize: 13
                        }

                        MouseArea {
                            anchors.fill: parent
                            // placeholder — step 2
                            onClicked: {}
                        }
                    }
                }
            }
        }

        // ---- clipboard --------------------------------------------------
        // Step 3 wires this. wl-paste reads the current selection only,
        // so real history needs cliphist installed and running
        // (wl-paste --watch cliphist store as a hypr exec-once).
        Column {
            anchors.left: parent.left
            spacing: 10

            Text {
                text: "Clipboard"
                color: Theme.cardDim
                font.family: Theme.barFontFamily
                font.pixelSize: 12
            }

            Row {
                anchors.left: parent.left
                spacing: 8

                Rectangle {
                    id: clipPill
                    height: 36
                    width: clipPillLabel.implicitWidth + 36
                    radius: 18
                    color: Theme.cardHighlight

                    Text {
                        id: clipPillLabel
                        anchors.centerIn: parent
                        text: "View history"
                        color: Theme.cardForeground
                        font.family: Theme.barFontFamily
                        font.pixelSize: 13
                    }

                    MouseArea {
                        anchors.fill: parent
                        // placeholder — step 3
                        onClicked: {}
                    }
                }
            }
        }

        // ---- record -----------------------------------------------------
        // Step 4 wires this to wf-recorder, started and stopped from
        // the same pill, with the elapsed time beside it. wf-recorder
        // is not installed yet. OBS is the alternative backend — see
        // the streaming note below.
        Column {
            anchors.left: parent.left
            spacing: 10

            Text {
                text: "Record"
                color: Theme.cardDim
                font.family: Theme.barFontFamily
                font.pixelSize: 12
            }

            Row {
                anchors.left: parent.left
                spacing: 8

                Rectangle {
                    id: recPill
                    height: 36
                    width: recPillLabel.implicitWidth + 36
                    radius: 18
                    color: Theme.cardHighlight

                    Text {
                        id: recPillLabel
                        anchors.centerIn: parent
                        text: "Start recording"
                        color: Theme.cardForeground
                        font.family: Theme.barFontFamily
                        font.pixelSize: 13
                    }

                    MouseArea {
                        anchors.fill: parent
                        // placeholder — step 4
                        onClicked: {}
                    }
                }
            }
        }
    }
}
