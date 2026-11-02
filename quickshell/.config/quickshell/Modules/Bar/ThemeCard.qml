// ThemeCard.qml — the island's second menu: the theme switch.
//
// Same card and pop as the media, volume and session pages; reached by
// hovering the second tab button in the column. One control: a
// three-way switch for the theme mode — auto / light / dark — held in
// Theme.themeMode and written to a state file, so the choice is still
// there after a reboot.
//
// The switch speaks the workspace pill's language: one rounded pill on
// the workspace pill's surface, with the active segment filled in
// barBackground and labelled in barForeground, and the inactive ones
// left transparent with barWorkspaceDim labels — the same surfaces,
// radius logic and active/inactive contrast as the workspace numbers
// in the bar, three segments wide instead of one-per-workspace.
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

    // the switch, centred in the content area — the 28px offset is
    // cardColumnWidth / 2, the same centering the session page uses,
    // so the group sits clear of the menu column strip
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: 28
        anchors.verticalCenter: parent.verticalCenter
        spacing: 16

        Rectangle {
            id: modePill
            anchors.horizontalCenter: parent.horizontalCenter
            height: 40
            radius: height / 2
            color: Theme.barWorkspacePill
            width: modeRow.implicitWidth + 8

            Row {
                id: modeRow
                anchors.centerIn: parent
                spacing: 4

                Repeater {
                    model: themeCard.modes

                    Rectangle {
                        required property var modelData
                        implicitWidth: 80
                        implicitHeight: 32
                        radius: implicitHeight / 2
                        color: Theme.themeMode === modelData
                            ? Theme.barBackground : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                            color: Theme.themeMode === modelData
                                ? Theme.barForeground : Theme.barWorkspaceDim
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

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: themeCard.caption
            color: Theme.cardDim
            font.family: Theme.barFontFamily
            font.pixelSize: 13
        }
    }
}
