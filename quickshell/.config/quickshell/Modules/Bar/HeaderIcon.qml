// HeaderIcon.qml — the menu-header mark: a white rectangle with a
// black diagonal arrow inside it, pointing to the bottom-right
// corner.
//
// Drawn in QML rather than shipped as an asset for two reasons: a
// Nerd Font glyph is a single color (the rectangle and the arrow
// need two), and Qt's SVG renderer bakes the fill (no currentColor),
// so neither route can carry a two-tone mark.
//
// The colors are fixed — white rectangle, black arrow — in both
// palettes, by design: the mark is a brand element, not palette
// content, so it does not invert with darkMode. (On the light card
// that makes the white plate subtle against the gray surface; the
// black arrow still reads crisp inside it.) With nothing bound to
// the Theme, the Canvas needs no repaint wiring.
import QtQuick

Rectangle {
    id: box

    width: 40
    height: 20
    color: "white"

    // the arrow: a stem from the top-left of its run down to the
    // bottom-right corner, with a chevron head opening back toward
    // the top-left. A 45° diagonal is height-constrained in the
    // 20px-tall plate, so it runs 10px with 5px of padding top and
    // bottom, and sits right-aligned against the same 5px padding on
    // the right edge.
    Canvas {
        anchors.centerIn: parent
        width: 40
        height: 20

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.strokeStyle = "black"
            ctx.lineWidth = 2.5
            ctx.lineCap = "round"
            ctx.lineJoin = "round"
            ctx.beginPath()
            ctx.moveTo(25, 5)
            ctx.lineTo(35, 15)
            ctx.moveTo(35, 8)
            ctx.lineTo(35, 15)
            ctx.lineTo(28, 15)
            ctx.stroke()
        }
    }
}
