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
//
// Both buttons are accepted, the tray icon's own split: the left one
// lands on `clicked()` (the toggle) and the right one on
// `secondaryClicked()`, which is something more than a toggle — the
// Wi-Fi tile uses it to reach the wifi picker. A tile with nothing
// connected to the secondary signal simply does nothing on a
// right-click, which is the same as before, when the button was not
// accepted at all.
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
    // the chevron is the visible half of `secondaryClicked()`: a tile
    // whose right-click does something more than toggle says so with a
    // ">" beside its state, and a left-click on that ">" does the same
    // thing. A tile that leaves this false is exactly the tile it was
    // before — no glyph, and its MouseArea still takes the full width.
    property bool chevron: false

    signal clicked()
    signal secondaryClicked()

    height: 48
    radius: 10
    color: tile.on ? Theme.cardAccent : Theme.cardHighlight

    // The glyph zone: a fixed 18px box, and the label anchors to its
    // right edge so the label's left edge never moves. The pin is
    // load-bearing — a Nerd Font glyph's Text width follows its ink
    // rather than its advance (measured 12.8 for bluetooth against
    // 20.8 for wifi at 18px), so an unpinned item drags the label's
    // anchor along with it and every tile's label lands at a
    // different x (38.8 to 46.8 across the four).
    //
    // The glyph is centred in the box rather than left-aligned, and
    // that is the whole fix: with no width of its own the Text's
    // implicit width IS its ink, so centring the item centres the
    // ink. Left-aligned inside a fixed box, every icon's ink sat at
    // its own offset — and the DND tile swaps between two of them,
    // bell and bell-slash, whose inks are 3.11px apart, so the icon
    // slid right on every toggle. Pixel-verified by rendering each
    // glyph and reading the ink back: the four icons' centres
    // scattered over 4.04px before and 0.31px after, and the toggle
    // jump falls from 3.11px to 0.31px — half a device pixel at this
    // monitor's 1.6 scale, which is as close as this font gets. The
    // vertical ink centre is identical for every glyph (6.48px at
    // 18px, off the outlines), so a swap only ever moved an icon
    // sideways.
    Item {
        id: glyphBox
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        width: 18
        height: 18

        Text {
            id: tileGlyph
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            text: tile.glyph
            color: tile.on ? Theme.cardAccentOn : Theme.cardForeground
            font.family: Theme.iconFont
            font.pixelSize: 18
        }
    }

    Text {
        id: tileLabel
        anchors.left: glyphBox.right
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
    // label gives up the rest. Right-aligned within that band, the
    // volume row's own percent: the box is a fixed width anchored to
    // the tile's right edge, so left alignment would start every value
    // at the same x and leave the gap on the outside — "Off" and
    // "Not connected" would begin together and stop at different
    // places. Aligning right puts every value's last character on the
    // same edge instead, which is what makes a column of them read as
    // one column.
    Text {
        id: tileState
        anchors.right: chevronBox.visible ? chevronBox.left : parent.right
        anchors.rightMargin: chevronBox.visible ? 6 : 14
        anchors.verticalCenter: parent.verticalCenter
        // the band gives up the chevron's footprint rather than sliding
        // left with it, so a tile that grows one keeps its state column
        // starting where it did and its label keeps its width — 12 for
        // the glyph and 6 for the gap, the same 18 the margin above
        // spends
        width: Math.min(140, tile.width / 2) - (chevronBox.visible ? 18 : 0)
        text: tile.available ? tile.stateText : "Unavailable"
        color: tile.on ? Theme.cardAccentOn : Theme.cardDim
        font.family: Theme.barFontFamily
        font.pixelSize: 12
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
    }

    // The ">" — the secondary action made visible. A 12px glyph in an
    // 18px-tall box on the tile's own 10px right inset, centred like
    // the control-centre glyphs so its ink (not its advance) is what
    // lands on the box's centre. It takes both buttons, since a
    // right-click here means the same thing a right-click anywhere
    // else on the tile does — a MouseArea that accepted only the left
    // one would leave the right button dead over its own 12px.
    Item {
        id: chevronBox
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 12
        height: 18
        visible: tile.chevron

        Text {
            anchors.centerIn: parent
            text: "\uF054" // chevron-right
            color: tile.on ? Theme.cardAccentOn : Theme.cardDim
            font.family: Theme.iconFont
            font.pixelSize: 12
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            enabled: tile.available
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: tile.secondaryClicked()
        }
    }

    MouseArea {
        anchors.fill: parent
        // the chevron's own area is declared above this one, so this
        // one sits on top of it and has to stop at its left edge — the
        // network row's inset past its trash box, the same trap
        anchors.rightMargin: chevronBox.visible ? 10 + chevronBox.width : 0
        cursorShape: Qt.PointingHandCursor
        enabled: tile.available
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function (mouse) {
            if (mouse.button === Qt.RightButton)
                tile.secondaryClicked()
            else
                tile.clicked()
        }
    }
}
