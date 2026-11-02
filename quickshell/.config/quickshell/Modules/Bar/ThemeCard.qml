// ThemeCard.qml — the island's second menu: the theme switch.
//
// Same card and pop as the media, volume and session pages; reached by
// hovering the second tab button in the column. One control: a
// three-way switch for the theme mode — auto / light / dark — held in
// Theme.themeMode and written to a state file, so the choice is still
// there after a reboot.
//
// The switch is the workspace pill's design, scaled up for labels: one
// pill on barWorkspacePill, three rounded buttons inside it, the
// inactive ones left transparent so the pill's own surface shows
// through, and the active one raised in barBackground with a
// barForeground label — the same surfaces, radius logic and
// active/inactive contrast as the workspace numbers, three segments
// wide instead of one-per-workspace. The workspace buttons are
// circles because they hold a single digit; these hold a word, so they
// are pill-shaped (radius = height / 2) rather than round.
//
// The pill spans the container — from the "Mode" label out to the
// content width's right margin — and each segment takes a third of
// the row after its spacing, so the segments resize with the pill
// instead of sitting at a fixed width. The 4px inset and 4px spacing
// are the workspace pill's own padding, so the buttons sit inside it
// exactly as the circles do.
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

        // one pill, spanning the container — the workspace pill's
        // surface, radius and height, three buttons wide instead of
        // one-per-workspace
        Rectangle {
            id: modePill
            anchors.left: modeLabel.right
            anchors.leftMargin: 20
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 40
            radius: height / 2
            color: Theme.barWorkspacePill

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

                        // a third of the row, minus the two gaps — so
                        // the segments track the pill's width
                        width: (modeRow.width - 2 * modeRow.spacing) / 3
                        height: modeRow.height
                        // pill-shaped, the circle's analogue for a
                        // word: the workspace buttons are round
                        // because they hold one digit
                        radius: height / 2
                        // the active button is raised in barBackground
                        // exactly as the active workspace circle is;
                        // the inactive ones stay transparent so the
                        // pill's surface reads through
                        color: active ? Theme.barBackground : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                            color: active ? Theme.barForeground : Theme.barWorkspaceDim
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
