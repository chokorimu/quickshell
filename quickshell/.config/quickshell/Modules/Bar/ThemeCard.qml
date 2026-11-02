// ThemeCard.qml — the island's second menu: the theme switch.
//
// Same card and pop as the media, volume and session pages; reached by
// hovering the second tab button in the column. Two controls: a
// three-way switch for the theme mode — auto / light / dark — held in
// Theme.themeMode and written to a state file, so the choice is still
// there after a reboot, and a brightness slider.
//
// The switch is the workspace pill's design, scaled up for labels: one
// pill on the pill surface, three rounded buttons inside it, the
// inactive ones left transparent so the track shows through, and the
// active one raised to the card's own surface with a cardForeground
// label — the same surfaces, radius logic and active/inactive contrast
// as the workspace numbers, three segments wide instead of
// one-per-workspace. The workspace buttons are circles because they
// hold a single digit; these hold a word, so they are pill-shaped
// (radius = height / 2) rather than round.
//
// The slider is VolumeRow's design verbatim — 5px track on
// cardHighlight, cardDim fill, a 32x8 handle in cardForeground riding
// the fill's edge and clamped to the track, and a MouseArea taller
// than the track so a drag that drifts vertically keeps tracking. The
// local visual value and the 100ms write throttle are the same ones
// VolumeRow uses: the service polls every 2s, and a read-back landing
// mid-drag would snap the handle back to the old value.
//
// Both controls sit on the content area's margins (80 left, 28 right —
// the volume page's rows), with a 120px label column so the pill and
// the slider share a left edge, rather than centred in the card.
//
// No MouseArea in here takes hover: a hover-enabled area would steal
// cardZone's hover in Bar.qml and collapse the island under a resting
// cursor. The segments are click-only and the slider is drag-only,
// like the session page's cells and the volume page's rows.
import QtQml
import QtQuick
import Quickshell
import "../../Services"
import "../../Theme"

Item {
    id: themeCard

    // the three modes, in switch order
    readonly property var modes: ["auto", "light", "dark"]

    // what the active mode resolves to — auto is the only one whose
    // outcome is not obvious from its label
    readonly property string caption: {
        if (Theme.themeMode === "light")
            return "Light pill"
        if (Theme.themeMode === "dark")
            return "Dark pill"
        return Theme.barUseMatugen
            ? "Following matugen's palette"
            : "Matugen is off — dark pill"
    }

    // The brightness service polls only while this page is on screen
    // — it is the service's only consumer, and the page is usually
    // closed. refresh() on the way in so the slider is live the
    // moment the card opens rather than one poll behind.
    onVisibleChanged: {
        Brightness.active = visible
        if (visible)
            Brightness.refresh()
    }

    // title row — header mark + "Theme", left-aligned. The 80px
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
            text: "THEME"
            color: Theme.cardForeground
            font.family: Theme.barFontFamily
            font.pixelSize: 20
            font.weight: Font.DemiBold
        }
    }

    // the controls, stacked — mode on top, brightness under it. Both
    // ride the content area's margins and share the 120px label
    // column, so the pill and the slider start on the same left edge.
    Column {
        id: controlColumn
        anchors.top: titleRow.bottom
        anchors.topMargin: 24
        anchors.left: parent.left
        anchors.leftMargin: 80
        anchors.right: parent.right
        anchors.rightMargin: 28
        spacing: 20

        // ---- mode: label + the three-way switch ----------------------
        Item {
            width: parent.width
            height: 40

            Text {
                id: modeLabel
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 120
                text: "Mode"
                color: Theme.cardForeground
                font.family: Theme.barFontFamily
                font.pixelSize: 14
            }

            // one pill — the workspace pill's surface, radius and
            // height, three buttons wide instead of one-per-workspace
            Rectangle {
                id: modePill
                anchors.left: modeLabel.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 40
                radius: height / 2
                color: Theme.cardPill

                Row {
                    id: modeRow
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 4

                    Repeater {
                        model: themeCard.modes

                        Rectangle {
                            required property var modelData
                            readonly property bool active: Theme.themeMode === modelData

                            // a third of the row, minus the two gaps —
                            // so the segments track the pill's width
                            width: (modeRow.width - 2 * modeRow.spacing) / 3
                            height: modeRow.height
                            // pill-shaped, the circle's analogue for a
                            // word: the workspace buttons are round
                            // because they hold one digit
                            radius: height / 2
                            // the active button is raised to the card's
                            // own surface, exactly as the workspace
                            // pill's active circle is raised to the bar
                            // it sits on; the inactive ones stay
                            // transparent so the track reads through
                            color: active ? Theme.cardBackground : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                                color: active ? Theme.cardForeground : Theme.cardDim
                                font.family: Theme.barFontFamily
                                font.pixelSize: 14
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: Theme.themeMode = modelData
                            }
                        }
                    }
                }
            }
        }

        // ---- brightness: label + slider + percent ---------------------
        // VolumeRow's layout and slider, one row of it.
        Item {
            id: brightnessRow
            width: parent.width
            height: 24

            // local drag state — see the header comment
            property real visual: 0
            property bool dragging: false
            readonly property real shown: dragging ? visual : Brightness.brightness
            readonly property real fraction: Math.max(0, Math.min(1, shown))

            function commit(v) {
                Brightness.setBrightness(v)
            }

            function nudge(delta) {
                commit(Math.max(0, Math.min(1, shown + delta)))
            }

            function setFromX(x) {
                visual = Math.max(0, Math.min(1, x / slider.width))
                if (!writeThrottle.running) {
                    commit(visual)
                    writeThrottle.restart()
                }
            }

            Timer {
                id: writeThrottle
                interval: 100
            }

            Text {
                id: brightnessLabel
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 120
                text: "Brightness"
                color: Theme.cardForeground
                font.family: Theme.barFontFamily
                font.pixelSize: 14
                elide: Text.ElideRight
            }

            // the MouseArea is taller than the track so a drag that
            // drifts a few pixels vertically keeps tracking
            Item {
                id: slider
                anchors.left: brightnessLabel.right
                anchors.leftMargin: 12
                anchors.right: pctText.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                height: 24

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 5
                    radius: 2.5
                    color: Theme.cardHighlight

                    Rectangle {
                        width: parent.width * brightnessRow.fraction
                        height: parent.height
                        radius: 2.5
                        color: Theme.cardDim
                    }
                }

                // handle rides the fill's edge — a horizontal rounded
                // rectangle: 32 wide against 8 tall, so the width is
                // the long axis, with radius 3 rounding the corners
                // without pill-ing the ends off. Clamped to the track:
                // mid-range the handle centers on the fill's edge, but
                // at 0% and max its edge aligns with the track's end
                // instead of its center overhanging into the label and
                // percent margins.
                Rectangle {
                    x: Math.max(0, Math.min(parent.width - width, parent.width * brightnessRow.fraction - width / 2))
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    height: 8
                    radius: 3
                    color: Theme.cardForeground
                }

                MouseArea {
                    anchors.fill: parent
                    onPressed: (mouse) => {
                        brightnessRow.dragging = true
                        brightnessRow.setFromX(mouse.x)
                    }
                    onPositionChanged: (mouse) => {
                        if (brightnessRow.dragging)
                            brightnessRow.setFromX(mouse.x)
                    }
                    onReleased: {
                        brightnessRow.dragging = false
                        brightnessRow.commit(brightnessRow.visual)
                    }
                    onWheel: (wheel) => brightnessRow.nudge(wheel.angleDelta.y > 0 ? 0.05 : -0.05)
                }
            }

            Text {
                id: pctText
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 48
                text: Math.round(brightnessRow.shown * 100) + "%"
                color: Theme.cardForeground
                font.family: Theme.barFontFamily
                font.pixelSize: 13
                horizontalAlignment: Text.AlignRight
            }
        }
    }

    // what the active mode resolves to, under the controls
    Text {
        anchors.top: controlColumn.bottom
        anchors.topMargin: 16
        anchors.left: parent.left
        anchors.leftMargin: 80
        text: themeCard.caption
        color: Theme.cardDim
        font.family: Theme.barFontFamily
        font.pixelSize: 13
    }
}
