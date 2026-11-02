// ThemeCard.qml — the island's second menu: the theme switch.
//
// Same card and pop as the media, volume and session pages; reached by
// hovering the second tab button in the column. Three controls: a
// three-way switch for the theme mode — auto / light / dark — held in
// Theme.themeMode and written to a state file, so the choice is still
// there after a reboot; a brightness slider; and a wallpaper grid.
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
// The grid is three columns of thumbnails from the Wallpapers service,
// scrolling when the directory holds more than the card can show — a
// third of a row peeks past the bottom edge, which is what says
// "scrollable" without a scrollbar. Each thumbnail is a plate in
// cardHighlight with the image cropped to fill it, and the current
// wallpaper — the one awww reports as displayed — carries a cardAccent
// frame. Clicking one applies it exactly the way the rofi wallpaper
// menu (SUPER+G) does: awww for the grow transition, then matugen to
// regenerate the palette from the new image.
//
// Both controls sit on the content area's margins (80 left, 28 right —
// the volume page's rows), with a 120px label column so the pill and
// the slider share a left edge, rather than centred in the card. The
// grid rides the same margins under them.
//
// No MouseArea in here takes hover: a hover-enabled area would steal
// cardZone's hover in Bar.qml and collapse the island under a resting
// cursor. The segments are click-only, the slider is drag-only and the
// thumbnails are click-only, like the session page's cells and the
// volume page's rows.
import QtQml
import QtQuick
import Quickshell
import "../../Services"
import "../../Theme"

Item {
    id: themeCard

    // the three modes, in switch order
    readonly property var modes: ["auto", "light", "dark"]

    // The brightness service polls only while this page is on screen
    // — it is the service's only consumer, and the page is usually
    // closed. refresh() on the way in so the slider is live the
    // moment the card opens rather than one poll behind. The wallpaper
    // listing is a one-shot find plus an awww query, driven the same
    // way: nothing here polls, so the grid costs nothing while the
    // page is closed.
    onVisibleChanged: {
        Brightness.active = visible
        if (visible) {
            Brightness.refresh()
            Wallpapers.refresh()
        }
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
        spacing: 4

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

    // wallpaper grid — three columns, scrolling when the directory
    // holds more than the card can show. Anchored between the controls
    // and the card's bottom edge so it takes whatever height is left:
    // a GridView whose height binds to its own contentHeight never
    // renders anything (it starts at zero, instantiates no delegates,
    // and can never grow), so the height has to come from the card.
    GridView {
        id: wallGrid
        anchors.top: controlColumn.bottom
        anchors.topMargin: 4
        anchors.left: parent.left
        anchors.leftMargin: 80
        anchors.right: parent.right
        anchors.rightMargin: 28
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        clip: true
        // three columns across the content width
        cellWidth: width / 3
        // a third of the next row peeks past the bottom edge — the
        // scroll affordance, since there is no scrollbar
        cellHeight: 96
        cacheBuffer: 200
        boundsBehavior: Flickable.StopAtBounds
        model: Wallpapers.paths

        delegate: Item {
            id: thumb
            required property var modelData
            readonly property bool selected: modelData === Wallpapers.current

            // wallGrid.cellWidth, never GridView.width: with no id on
            // the view, `GridView` resolves to the TYPE object (typeof
            // "object"), whose .width is undefined — the delegate's
            // width silently becomes 0 and the thumbnail collapses.
            // No error is logged, which is how it shipped in the
            // volume card once.
            width: wallGrid.cellWidth
            height: wallGrid.cellHeight

            // the current wallpaper's frame — the accent, rounded,
            // and only drawn for the selected thumb
            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: 7
                color: "transparent"
                border.width: 2
                border.color: Theme.cardAccent
                visible: thumb.selected
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                color: Theme.cardHighlight

                Image {
                    anchors.fill: parent
                    source: thumb.modelData
                    fillMode: Image.PreserveAspectCrop
                    // a thumbnail never needs the full-size file — the
                    // cell is ~160px wide, so this keeps a 4K wallpaper
                    // from being decoded at full size, and 52 of them
                    // from being held at once
                    sourceSize: Qt.size(180, 120)
                    asynchronous: true
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: Wallpapers.set(thumb.modelData)
                }
            }
        }
    }
}
