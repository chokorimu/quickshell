// ToggleTile.qml — one quick-toggle tile on the notifications page:
// glyph, label, state line, on/off fill.
//
// The tile is the theme page's mode-switch language at tile size:
// cardHighlight at rest, the accent fill with near-black ink while
// on — the same accent the selected tab wears, so "on" reads the
// same way across the shell. The label sits left of the remaining
// band and the state on its right, the volume row's name/percent
// pattern, so the tile reads as one more settings row rather than a
// new idea.
//
// Click-only, like every other MouseArea on the card: a
// hover-enabled one would steal cardZone's hover in Bar.qml and
// collapse the island under a resting cursor.
import QtQml
import QtQuick
import "../../Theme"

Rectangle {
    id: tile

    property string glyph: ""
    property string label: ""
    property string stateText: ""
    property bool on: false
    // a dead backend (no bluetoothd, no PPD) reads as Unavailable and
    // the click is swallowed rather than firing into nothing
    property bool available: true

    signal clicked()

    height: 48
    radius: 10
    color: tile.on ? Theme.cardAccent : Theme.cardHighlight

    // the glyph, centred in the tile's own left icon zone
    Text {
        id: tileGlyph
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: tile.glyph
        color: tile.on ? Theme.cardAccentOn : Theme.cardForeground
        font.family: Theme.iconFont
        font.pixelSize: 18
    }

    Text {
        id: tileLabel
        anchors.left: tileGlyph.right
        anchors.leftMargin: 12
        anchors.right: tileState.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: tile.label
        color: tile.on ? Theme.cardAccentOn : Theme.cardForeground
        font.family: Theme.barFontFamily
        font.pixelSize: 13
        elide: Text.ElideRight
    }

    // the state takes what it needs — half the tile at most — and the
    // label gives up the rest
    Text {
        id: tileState
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(140, tile.width / 2)
        text: tile.available ? tile.stateText : "Unavailable"
        color: tile.on ? Theme.cardAccentOn : Theme.cardDim
        font.family: Theme.barFontFamily
        font.pixelSize: 12
        elide: Text.ElideRight
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        enabled: tile.available
        onClicked: tile.clicked()
    }
}
