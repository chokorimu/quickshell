// WorkspaceSwitcher.qml — the workspace minimap menu.
//
// A separate pop-out, not an island page. It hangs off the bar's bottom edge
// at the top centre, in the island's own 600px box and with the island's own
// pop, and it appears when the cursor rests on the workspace pill.
//
// Each tile is a miniature of the monitor the workspace lives on, with that
// workspace's windows drawn at their real positions and sizes — so a glance
// says where things are, not just how many. The window geometry comes from
// each toplevel's `lastIpcObject.at` / `.size`, which are in LAYOUT (logical)
// coordinates while `HyprlandMonitor.width/height` are PHYSICAL, hence the
// divide by the monitor's scale; a rotated output swaps its axes first, the
// same way the displays page does.
//
// The island and this menu share one footprint, so Bar.qml suppresses the
// island while the switcher is showing (see `expanded` there). The switcher
// is hover-driven like the tray menu: it closes when the cursor leaves it,
// and a click on a tile switches workspace but leaves the menu up, so
// several can be picked in a row without the card dropping out from under
// the cursor.
import QtQml
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../../Theme"
Item {
    id: root
    // ---- the model -------------------------------------------------------
    // Bar.qml's own workspace list — the same array the bar's pill renders,
    // so the two can never disagree about which workspaces exist. Entries are
    // HyprlandWorkspace objects for real workspaces and plain
    // `{ id, active }` placeholders for the empty 1-4 slots.
    property var workspaces: []
    // the logical open state, driven by Bar.qml's hover chain
    property bool open: false
    // ---- metrics ---------------------------------------------------------
    // The island card's width, and the pages' own content margins: 80 on the
    // left (the tab column strip plus its padding), 28 on the right, 16 at
    // the foot. There is no column strip on this menu, but the same margins
    // put the title row on exactly the x the pages put theirs, which is what
    // makes the two read as one system when they appear in the same place.
    readonly property int menuWidth: 600
    readonly property int padLeft: 80
    readonly property int padRight: 28
    readonly property int padBottom: 16
    readonly property int titleTop: 28
    readonly property int titleHeight: 24
    readonly property int titleGap: 16
    // 84 + 12 fits five tiles across the 492px content width with 24px of a
    // sixth peeking past the right edge — the partial tile is the scroll
    // affordance, the way the lists use a partial row (there is no
    // scrollbar).
    readonly property int tileWidth: 84
    readonly property int tileHeight: 84
    readonly property int tileGap: 12
    // the tile's own padding, and the mini monitor's height inside it: 68 x
    // 42 is ~16:10, close to this machine's 2560x1600 panel and close enough
    // to every other common shape that the minimap reads right.
    readonly property int tilePad: 8
    readonly property int screenHeight: 42
    readonly property int contentWidth: menuWidth - padLeft - padRight
    readonly property int stripTop: titleTop + titleHeight + titleGap
    readonly property int menuHeight: stripTop + tileHeight + padBottom
    readonly property int plateRadius: 10
    implicitWidth: menuWidth
    implicitHeight: menuHeight
    width: implicitWidth
    height: implicitHeight
    // ---- the pop ---------------------------------------------------------
    // The island card's pop verbatim: one 0 -> 1 progress drives the clip's
    // height and the content's horizontal scale together, so the menu is
    // revealed downward from the bar's bottom edge while it widens from its
    // own centre line. Same curves, same durations.
    property real pop: 0
    // the pop-in overshoots ~1.02x, so the clip runs wider than the plate or
    // the scaled edges get shaved square against it (Bar.qml's headroom)
    readonly property real popOvershoot: 1.12
    readonly property real reveal: pop
    // How much of the plate the clip has revealed — what the bottom-corner
    // radius has to fit inside.
    readonly property real visibleHeight: menuHeight * reveal
    readonly property real plateBottomRadius:
        Math.min(plateRadius, Math.max(0, (visibleHeight - plateRadius) / 2))
    // the fillet that blends the plate's side edges into the bar's bottom
    // edge — the island pill's rolls at menu scale, and TrayMenu's own
    // junction. Its depth tracks the reveal so a plate still growing out of
    // the bar gets a shallower gusset and none at all while it is shorter
    // than a corner radius.
    readonly property real filletRadius: {
        var over = visibleHeight - plateRadius
        var rb = Math.min(plateRadius, Math.max(0, over / 2))
        return Math.max(0, Math.min(plateRadius, over - rb * reveal))
    }
    onOpenChanged: {
        if (open) {
            popOut.stop()
            popIn.start()
            // callLater, not a direct call: on the frame `open` flips, the
            // delegates at the far end of the strip may not exist yet
            Qt.callLater(root.revealActive)
        } else {
            popIn.stop()
            popOut.start()
        }
    }
    NumberAnimation {
        id: popIn
        target: root
        property: "pop"
        to: 1
        duration: 300
        // the island's tamed back-ease — a flat bezier list in Qt 6
        // (c1x, c1y, c2x, c2y, endX, endY), peaking at ~1.02x
        easing.type: Easing.Bezier
        easing.bezierCurve: [0.34, 1.25, 0.64, 1.0, 1.0, 1.0]
    }
    NumberAnimation {
        id: popOut
        target: root
        property: "pop"
        to: 0
        duration: 200
        easing.type: Easing.OutCubic
    }
    // ---- the pointer -----------------------------------------------------
    // The index of the tile under the cursor, or -1. Reported up by the
    // delegates so Bar.qml's leave-grace can tell a departure from a move
    // across the menu. The plate-wide area below is the other half: the tiles
    // do not tile the plate (there is a title row and margins around them), so
    // "some tile is hovered" alone would read the title row as outside and
    // close the menu under a cursor that is plainly on it.
    property int hoverIndex: -1
    readonly property bool pointerInside: hoverIndex >= 0 || plateHover.containsMouse
    // ---- the plate -------------------------------------------------------
    Item {
        id: clip
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.width * root.popOvershoot
        height: root.height * root.reveal
        clip: true
        // ---- the junction fillets ---------------------------------------
        // A sibling of the plate, not part of its canvas: the fillets live
        // OUTSIDE the plate's side edges and a Canvas clips its paint to its
        // own bounds. Full clip width (plate plus the pop overshoot either
        // side), only as tall as the fillet is deep.
        Canvas {
            id: filletCanvas
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: clip.width
            height: Math.max(1, root.filletRadius)
            visible: root.filletRadius > 0.5
            onHeightChanged: requestPaint()
            Connections {
                target: root
                function onRevealChanged() { filletCanvas.requestPaint() }
            }
            Connections {
                target: Theme
                function onBarBackgroundChanged() { filletCanvas.requestPaint() }
            }
            onPaint: {
                var ctx = getContext("2d")
                var w = width
                var fr = height
                // the plate's visible edges at this frame's reveal — the plate
                // scales about its centre, so these are not its item bounds
                var cw = root.width * root.reveal
                var nx = (w - cw) / 2
                var cx = nx + cw
                ctx.clearRect(0, 0, w, height)
                ctx.fillStyle = Theme.barBackground
                ctx.beginPath()
                // right fillet: out along the bar's bottom edge, the quarter
                // arc down to the plate's edge, then back up it. Tangent to
                // both, so the junction is one smooth S. Both subpaths start
                // 1px INSIDE the plate: two abutting antialiased edges leave
                // a hairline of the surface behind them, and the plate paints
                // over the overlap.
                ctx.moveTo(cx - 1, 0)
                ctx.lineTo(cx + fr, 0)
                ctx.arc(cx + fr, fr, fr, -Math.PI / 2, -Math.PI, true)
                ctx.closePath()
                ctx.moveTo(nx + 1, 0)
                ctx.lineTo(nx - fr, 0)
                ctx.arc(nx - fr, fr, fr, -Math.PI / 2, 0, false)
                ctx.closePath()
                ctx.fill()
            }
        }
        Item {
            id: content
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: root.width
            height: root.height
            // the width half of the pop, origin top-centre
            transform: Scale { origin.x: content.width / 2; origin.y: 0; xScale: root.reveal }
            // Tiles stay live through the pop-IN (they are fully usable long
            // before the 300ms is up) and go dead the instant the menu
            // closes, so a click landing on a tile that is already retracting
            // cannot switch workspace — the tray menu's own gate.
            enabled: root.open
            // The plate is a Canvas for the island card's reason: the bottom
            // corners are the reveal edge and must track the visible height.
            // The TOP corners are square — the plate's top edge IS the bar's
            // bottom edge, so a radius up there would notch two bites out of
            // the seam (the island card tucks its rounded top corners behind
            // the bar; the edge that meets a boundary is the edge that must
            // not curve).
            Canvas {
                id: plateCanvas
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                width: root.width
                height: clip.height
                // its height IS the clip's, so this is one repaint per frame
                // of the pop. On the canvas itself rather than through a
                // Connections: a request made while the canvas was still 0
                // tall is dropped, and only the canvas's own signal is
                // guaranteed to see the height that follows it (TrayMenu).
                onHeightChanged: requestPaint()
                Connections {
                    target: Theme
                    function onCardBackgroundChanged() { plateCanvas.requestPaint() }
                }
                onPaint: {
                    var ctx = getContext("2d")
                    var w = width
                    var h = height
                    var rt = 0
                    var rb = root.plateBottomRadius
                    ctx.clearRect(0, 0, w, h)
                    ctx.fillStyle = Theme.cardBackground
                    ctx.beginPath()
                    // one clockwise outline, every arc starting where the path
                    // already stands (canvas inserts a straight connector
                    // otherwise and the curve collapses)
                    ctx.moveTo(rt, 0)
                    ctx.lineTo(w - rt, 0)
                    if (rt > 0.5)
                        ctx.arc(w - rt, rt, rt, -Math.PI / 2, 0, false)
                    ctx.lineTo(w, h - rb)
                    if (rb > 0.5)
                        ctx.arc(w - rb, h - rb, rb, 0, Math.PI / 2, false)
                    ctx.lineTo(rb, h)
                    if (rb > 0.5)
                        ctx.arc(rb, h - rb, rb, Math.PI / 2, Math.PI, false)
                    ctx.lineTo(0, rt)
                    if (rt > 0.5)
                        ctx.arc(rt, rt, rt, Math.PI, 3 * Math.PI / 2, false)
                    ctx.closePath()
                    ctx.fill()
                }
            }
            // ---- "is the cursor on the plate" ---------------------------
            // Declared before everything else so the tiles sit above it and
            // keep their own hover and clicks. A tile steals this area's
            // `containsMouse` while it is hovered (a hover-enabled area above
            // wins), which is why pointerInside ORs the tile index in as
            // well. No buttons at all: this area is a hover reader, never a
            // click target — the plate is not a dismiss surface.
            MouseArea {
                id: plateHover
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
            }
            // ---- title ---------------------------------------------------
            Row {
                id: titleRow
                anchors.top: parent.top
                anchors.topMargin: root.titleTop
                anchors.left: parent.left
                anchors.leftMargin: root.padLeft
                spacing: 12
                HeaderIcon {
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "// WORKSPACES"
                    color: Theme.cardForeground
                    font.family: Theme.barFontFamily
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                }
            }
            // ---- the strip -----------------------------------------------
            // One row that scrolls sideways. Its height is the tile's, never
            // its content's — a view whose height binds to its own content
            // never instantiates a delegate at all.
            ListView {
                id: strip
                anchors.left: parent.left
                anchors.leftMargin: root.padLeft
                anchors.top: parent.top
                anchors.topMargin: root.stripTop
                width: root.contentWidth
                height: root.tileHeight
                orientation: ListView.Horizontal
                spacing: root.tileGap
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentWidth > width
                model: root.workspaces
                delegate: Item {
                    id: tile
                    required property var modelData
                    required property int index
                    // A delegate can outlive its model row by a frame, and
                    // reading through a null modelData throws on every
                    // property. An empty object stands in for that frame.
                    readonly property var ws: tile.modelData || ({})
                    readonly property bool active: !!tile.ws.active
                    // the workspace's toplevels, as a JS array (the workspace
                    // exposes an UntypedObjectModel). A 1-4 placeholder has no
                    // model at all, which reads as an empty workspace.
                    readonly property var toplevels:
                        tile.ws.toplevels ? tile.ws.toplevels.values : []
                    readonly property int count: tile.toplevels.length
                    // the monitor the workspace lives on. A placeholder has
                    // none, so it borrows the focused one — an empty
                    // workspace is still drawn on a screen.
                    readonly property var monitor:
                        tile.ws.monitor ? tile.ws.monitor : Hyprland.focusedMonitor
                    readonly property bool hovered: root.hoverIndex === tile.index
                    // ---- the tile's palette ----------------------------------
                    // Three states, three fills, all the shell's existing
                    // language: the active workspace wears the accent with
                    // near-black ink (the toggle tiles' "on" treatment, and the
                    // bar's own inverted active-workspace circle at tile
                    // scale); a hovered one takes the session cells' soft
                    // inversion; everything else sits on the lists' plate.
                    readonly property color plateColor: tile.active ? Theme.cardAccent
                        : (tile.hovered ? Theme.cardHover : Theme.cardHighlight)
                    readonly property color ink: tile.active ? Theme.cardAccentOn
                        : (tile.hovered ? Theme.cardHoverOn : Theme.cardForeground)
                    readonly property color screenColor: (tile.active || tile.hovered)
                        ? Qt.rgba(tile.ink.r, tile.ink.g, tile.ink.b, 0.12)
                        : Theme.cardBackground
                    readonly property color windowColor:
                        Qt.rgba(tile.ink.r, tile.ink.g, tile.ink.b, 0.5)
                    readonly property color countColor:
                        Qt.rgba(tile.ink.r, tile.ink.g, tile.ink.b, 0.6)
                    width: root.tileWidth
                    height: root.tileHeight
                    onInkChanged: screen.requestPaint()
                    onScreenColorChanged: screen.requestPaint()
                    onWindowColorChanged: screen.requestPaint()
                    onCountChanged: screen.requestPaint()
                    onMonitorChanged: screen.requestPaint()
                    // a rounded-rect path helper, used by the minimap's plate
                    // and its window blocks. Canvas has no roundedRect.
                    function roundRect(ctx, x, y, w, h, r) {
                        r = Math.min(r, w / 2, h / 2)
                        ctx.beginPath()
                        ctx.moveTo(x + r, y)
                        ctx.lineTo(x + w - r, y)
                        ctx.arc(x + w - r, y + r, r, -Math.PI / 2, 0, false)
                        ctx.lineTo(x + w, y + h - r)
                        ctx.arc(x + w - r, y + h - r, r, 0, Math.PI / 2, false)
                        ctx.lineTo(x + r, y + h)
                        ctx.arc(x + r, y + h - r, r, Math.PI / 2, Math.PI, false)
                        ctx.lineTo(x, y + r)
                        ctx.arc(x + r, y + r, r, Math.PI, 3 * Math.PI / 2, false)
                        ctx.closePath()
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: root.plateRadius
                        color: tile.plateColor
                    }
                    Canvas {
                        id: screen
                        anchors.top: parent.top
                        anchors.topMargin: root.tilePad
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root.tileWidth - root.tilePad * 2
                        height: root.screenHeight
                        onPaint: {
                            var ctx = getContext("2d")
                            var w = width
                            var h = height
                            ctx.clearRect(0, 0, w, h)
                            // ---- the monitor ----------------------------
                            // The screen plate. cardBackground against the
                            // tile's cardHighlight is one palette step in
                            // either mode, which reads as the recessed
                            // surface the windows sit on.
                            ctx.fillStyle = tile.screenColor
                            tile.roundRect(ctx, 0, 0, w, h, 4)
                            ctx.fill()
                            // ---- the windows ----------------------------
                            // `at`/`size` are LAYOUT (logical) coordinates;
                            // the monitor's width/height are PHYSICAL, so the
                            // scale divide is what puts the two in one space.
                            // A rotated output reports its physical mode size,
                            // so its logical footprint has the axes swapped.
                            var mon = tile.monitor
                            var sc = (mon && mon.scale > 0) ? mon.scale : 1
                            var tf = (mon && mon.lastIpcObject)
                                ? (mon.lastIpcObject.transform || 0) : 0
                            var mw = mon
                                ? (tf % 2 === 1 ? mon.height : mon.width) / sc : 16
                            var mh = mon
                                ? (tf % 2 === 1 ? mon.width : mon.height) / sc : 10
                            var mx = mon ? mon.x : 0
                            var my = mon ? mon.y : 0
                            var list = tile.toplevels
                            ctx.fillStyle = tile.windowColor
                            for (var i = 0; i < list.length; i++) {
                                var ipc = list[i].lastIpcObject
                                if (!ipc || !ipc.at || !ipc.size)
                                    continue
                                var x = (ipc.at[0] - mx) / mw * w
                                var y = (ipc.at[1] - my) / mh * h
                                var bw = ipc.size[0] / mw * w
                                var bh = ipc.size[1] / mh * h
                                // keep every block inside the screen plate
                                var x0 = Math.max(0, x)
                                var y0 = Math.max(0, y)
                                var x1 = Math.min(w, x + bw)
                                var y1 = Math.min(h, y + bh)
                                if (x1 - x0 < 0.5 || y1 - y0 < 0.5)
                                    continue
                                tile.roundRect(ctx, x0, y0, x1 - x0, y1 - y0, 1.5)
                                ctx.fill()
                            }
                        }
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: root.tilePad
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: root.tilePad
                        text: tile.ws.id
                        color: tile.ink
                        font.family: Theme.barFontFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: root.tilePad
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: root.tilePad
                        // nothing on an empty workspace: a bare "0" reads as a
                        // count of something
                        visible: tile.count > 0
                        text: tile.count
                        color: tile.countColor
                        font.family: Theme.barFontFamily
                        font.pixelSize: 11
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activateWorkspace(tile.ws.id)
                        // The strip scrolls sideways on the wheel. Qt's own
                        // wheel-to-horizontal mapping is not relied on: the
                        // tile's own area drives contentX, which is one line
                        // and behaves the same on a notched wheel and a
                        // touchpad. The clamp mirrors StopAtBounds, since a
                        // direct assignment bypasses the flick's own bounds
                        // handling. Clicks and hover are untouched.
                        onWheel: function (wheel) {
                            root.scrollStrip(-wheel.angleDelta.y)
                        }
                        // "the cursor is on this tile" for the leave-grace.
                        // Only one tile can be hovered at a time, and the guard
                        // on exit keeps a neighbour's enter from being undone
                        // by the previous tile's exit landing afterwards.
                        onContainsMouseChanged: {
                            if (containsMouse)
                                root.hoverIndex = tile.index
                            else if (root.hoverIndex === tile.index)
                                root.hoverIndex = -1
                        }
                    }
                }
            }
        }
    }
    // ---- switching -------------------------------------------------------
    // The bar's own dispatcher call, in the same shape: Quickshell
    // interpolates the request raw into a Lua call, and this Hyprland runs a
    // Lua config, so the legacy string forms are syntax errors. The object
    // form is what creates the workspace on demand, which is what makes the
    // 1-4 placeholders clickable.
    function activateWorkspace(id) {
        Hyprland.dispatch("hl.dsp.focus({workspace = " + id + "})")
    }

    // ---- the strip's scrolling -------------------------------------------
    // A function rather than the delegate's wheel handler inline, so the rule
    // is probeable: the handler itself is one call, and the arithmetic below
    // is what a wheel actually does.
    //
    // The strip has to drive contentX itself. Qt's Flickable maps a mouse
    // wheel's angleDelta to the axis it flicks on (qquickflickable.cpp:
    // yDelta drives a vertical flick, xDelta a horizontal one), and a
    // physical wheel only ever sends y — so a horizontal-only view ignores it
    // entirely and the strip would never scroll.
    //
    // The clamp mirrors StopAtBounds, since a direct contentX assignment
    // bypasses the flick's own bounds handling.
    function scrollStrip(delta) {
        var max = Math.max(0, strip.contentWidth - strip.width)
        strip.contentX = Math.max(0, Math.min(max, strip.contentX + delta))
    }

    // Bring the workspace that is actually up into view on open: with more
    // workspaces than the strip holds, the interesting tile is otherwise the
    // one past the right edge. Contain, not Center, so a strip that already
    // shows everything does not move at all.
    function revealActive() {
        for (var i = 0; i < workspaces.length; i++) {
            if (workspaces[i].active) {
                strip.positionViewAtIndex(i, ListView.Contain)
                return
            }
        }
    }
    // callLater, not a direct call: on the frame `open` flips, the delegates
    // for the far end of the strip may not exist yet.
}
