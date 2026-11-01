// HeaderIcon.qml — the menu-header mark: a filled rounded box with a
// diagonal arrow inside it, pointing to the bottom-right corner.
//
// Drawn in QML rather than shipped as an asset for two reasons: a
// Nerd Font glyph is a single color (the box and the arrow need two),
// and Qt's SVG renderer bakes the fill (no currentColor), so neither
// route can carry a knockout mark.
//
// The box takes Theme.cardInk and the arrow Theme.cardOnInk — the
// same knockout pair the transport circles use — so the mark inverts
// with the palette: a near-white box with a near-black arrow in dark
// mode, the reverse in light. The box is a plain Rectangle binding
// and needs no wiring; the arrow is a Canvas and repaints on
// cardOnInkChanged so it follows palette flips.
import QtQuick
import Quickshell
import "../../Theme"

Rectangle {
    id: box

    width: 20
    height: 20
    radius: 5
    color: Theme.cardInk

    // the arrow: a stem from the top-left padding to the bottom-right
    // corner with a chevron head opening back toward the top-left —
    // 5px of padding on every side keeps it inside the box
    Canvas {
        anchors.centerIn: parent
        width: 20
        height: 20

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.strokeStyle = Theme.cardOnInk
            ctx.lineWidth = 2
            ctx.lineCap = "round"
            ctx.lineJoin = "round"
            ctx.beginPath()
            ctx.moveTo(5, 5)
            ctx.lineTo(15, 15)
            ctx.moveTo(15, 8)
            ctx.lineTo(15, 15)
            ctx.lineTo(8, 15)
            ctx.stroke()
        }

        Connections {
            target: Theme
            function onCardOnInkChanged() { parent.requestPaint() }
        }
    }
}
