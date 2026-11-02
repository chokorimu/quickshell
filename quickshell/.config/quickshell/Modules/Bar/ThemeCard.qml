// ThemeCard.qml — the island's second menu: the theme switch.
//
// Same card and pop as the media, volume and session pages; reached by
// hovering the second tab button in the column. One control: a
// three-way switch for the theme mode — auto / light / dark — held in
// Theme.themeMode and written to a state file, so the choice is still
// there after a reboot.
//
// The switch is one pill, not three: a single rounded container
// spanning the content width, with the three modes tiling it edge to
// edge. The pill's width is bound to the container, and each segment
// takes a third of what is left after the row's spacing, so the
// segments resize with the pill instead of sitting at a fixed width.
// The 2px gaps let the pill's own surface through as dividers, and
// the pill's clip rounds the end segments' outer corners, so the
// whole thing reads as one control rather than a row of buttons.
//
// The active segment takes the knockout pair the transport circles
// already use on this card (cardInk fill, cardOnInk label):
// barBackground, the workspace pill's own active fill, lands between
// the pill and cardHighlight in the dark palette, so a filled active
// segment would read as darker than its neighbours instead of
// selected. The inactive segments take cardHighlight, the card's
// subtle surface, with cardDim labels.
//
// The label and the switch sit top-left under the title, on the same
// 80px margin the volume page's rows use, rather than centred in the
// card — the page has one control, and a centred group floats.
//
// No MouseArea in here takes hover: a hover-enabled area would steal
// cardZone's hover in Bar.qml and collapse the island under a resting
// cursor. The segments are click-only, like the session page's cells.
import QtQml
import QtQuick
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

    // the control row — "Mode" label on the left, the switch filling
    // the rest of the container out to the right margin. Both ride
    // the title's 80px margin, so the page reads as a column rather
    // than a floating group.
    Item {
        id: controlRow
        anchors.top: titleRow.bottom
        anchors.topMargin: 24
        anchors.left: parent.left
        anchors.leftMargin: 80
        anchors.right: parent.right
        anchors.rightMargin: 80
        height: 40

        Text {
            id: modeLabel
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Mode"
            color: Theme.cardForeground
            font.family: Theme.barFontFamily
            font.pixelSize: 14
        }

        // one pill, spanning the container. clip rounds the end
        // segments' outer corners to the pill's own radius.
        Rectangle {
            id: modePill
            anchors.left: modeLabel.right
            anchors.leftMargin: 20
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 40
            radius: height / 2
            color: Theme.barWorkspacePill
            clip: true

            Row {
                id: modeRow
                anchors.fill: parent
                spacing: 2

                Repeater {
                    model: themeCard.modes

                    Rectangle {
                        required property var modelData
                        readonly property bool active: Theme.themeMode === modelData

                        // a third of the row, minus the two gaps — so
                        // the segments track the pill's width
                        width: (modeRow.width - 2 * modeRow.spacing) / 3
                        height: modeRow.height
                        color: active ? Theme.cardInk : Theme.cardHighlight

                        Text {
                            anchors.centerIn: parent
                            text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                            color: active ? Theme.cardOnInk : Theme.cardDim
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

    // what the active mode resolves to, under the switch
    Text {
        anchors.top: controlRow.bottom
        anchors.topMargin: 16
        anchors.left: parent.left
        anchors.leftMargin: 80
        text: themeCard.caption
        color: Theme.cardDim
        font.family: Theme.barFontFamily
        font.pixelSize: 13
    }
}
