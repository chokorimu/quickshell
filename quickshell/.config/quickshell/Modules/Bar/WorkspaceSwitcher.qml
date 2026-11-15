// WorkspaceSwitcher.qml — the workspace minimap menu.
//
// A separate pop-out, not an island page. It hangs off the bar's bottom edge
// at the top centre with the island's own pop, and it appears when the cursor
// rests on the workspace pill. It is wider than the island card (700 against
// 600) so the tiles can be big enough to read the windows in them.
//
// Each tile is a miniature of the monitor the workspace lives on, with that
// workspace's windows drawn at their real positions and sizes — so a glance
// says where things are, not just how many. The window geometry comes from
// `hyprctl clients -j`, NOT from the toplevel model: a toplevel opened after
// the model first built carries an empty `lastIpcObject` for good (see the
// `clients` property below). `at` / `size` are in LAYOUT (logical)
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
import Quickshell.Io
import Quickshell.Wayland
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
    // The island card's width, but NOT the island pages' margins. Those are
    // 80 on the left because the pages have to clear the tab column strip,
    // and 28 on the right because there is nothing to clear there — a
    // lopsided pair that is right on a card with a strip and wrong on a
    // standalone plate. This menu has no strip, so copying the pair left the
    // title and the tiles 80 from the left edge and 28 from the right, with
    // the whole menu reading shoved right. One padding, the same on all four
    // sides, is the honest shape here: the plate is its own surface.
    // 700, not the island card's 600: the tiles have to be big enough to read
    // the windows in them, and 600 could not hold five of the size they now
    // want. This is a separate pop-out, so it is not obliged to match the
    // card's width — the tray menu is 240 for the same reason. The width is
    // also chosen for its remainder: five 112px tiles and four 12px gaps come
    // to 608 of the 652px content width, which leaves 44px — 39% of a sixth
    // tile — peeking past the right edge, and that is the scroll affordance.
    // A rounder 720 left 64 (57%), which reads as a tile that got clipped
    // rather than as a hint that there are more.
    readonly property int menuWidth: 700
    readonly property int pad: 24
    // the title row's real height: a 20px DemiBold line box measures 25
    readonly property int titleHeight: 25
    // 20, the island's own title-to-first-control gap (VolumeCard's titleRow
    // to its master row), so the two headers read at one rhythm
    readonly property int titleGap: 20
    readonly property int tileWidth: 112
    readonly property int tileGap: 12
    // There is no tile container: the thumbnail IS the tile's width, and the
    // labels sit straight under it, so the only padding the tile has is the
    // gap between the screen and them — 6, the lists' label-to-list step.
    // `labelHeight` is the 12px label's own line box (measured 15), not a
    // round number, which keeps the rhythm exact instead of leaving a sliver
    // under the digits.
    readonly property int screenWidth: tileWidth
    // 112 x 70 is exactly 16:10, this machine's panel shape, so the minimap
    // reads as a picture of the screen it stands for.
    readonly property int screenHeight: 70
    readonly property int labelGap: 6
    // the 14px number's own line box (measured 18), so the tile's height is
    // exact and the digits do not sit in a box taller than their ink
    readonly property int labelHeight: 18
    readonly property int tileHeight: screenHeight + labelGap + labelHeight
    readonly property int contentWidth: menuWidth - pad * 2
    readonly property int stripTop: pad + titleHeight + titleGap
    readonly property int menuHeight: stripTop + tileHeight + pad
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
    // ---- live thumbnails -------------------------------------------------
    // Each window is captured by a `ScreencopyView` bound to the toplevel's
    // own wayland handle (`HyprlandToplevel.wayland`). That is the same
    // ext-image-copy path `grim -T` takes, so it works for windows on
    // workspaces that are NOT on screen — the whole point of this menu — but
    // it runs in-process, with no subprocess and no files on disk.
    //
    // It is also genuinely LIVE: with `live: true` the compositor pushes a
    // frame whenever the window's content changes, so a video, a scrolling
    // page or a terminal updates as it happens. Polling `grim` could not do
    // this at any sane cost — a sweep of five windows measured ~250ms wall and
    // ~870ms CPU, and that CPU is flat across `-s` scales and PNG levels
    // because the toplevel readback is what costs, not the encode. Five live
    // views at the 68x42 tile size measure ~14% of one core in isolation and
    // ~10% above the closed baseline inside the real bar (22.5% against
    // 12.2% of one core, self plus children) — against the 62.1% of one core
    // in grim children alone that the polling design cost, and it never polls
    // at all.
    //
    // Nothing is captured while the plate is down: the delegate's `live`
    // rides `root.open` directly, so a closed menu costs nothing.
    // ---- structure --------------------------------------------------------
    // The pixels are live for free, but the GEOMETRY is not — and it cannot
    // come from the toplevel model at all. `HyprlandToplevel.lastIpcObject` is
    // filled only when the model first builds: a toplevel created by an
    // `openwindow` event after that keeps an EMPTY object for good. Probed by
    // diffing addresses around a spawned window: 0 keys with `at` undefined at
    // +1.4s, +3s and +5.5s, and still empty after two workspace switches —
    // while the same toplevel's `title` and `wayland` handle arrive normally
    // (the title rides the event itself). So a window opened while the shell
    // runs had no block and the menu showed its workspace as empty: this is
    // the "didn't update in real time" bug.
    //
    // The compositor is therefore the geometry source: one `hyprctl clients -j`
    // read gives every window's `at`/`size`/`workspace` fresh. It is a fork,
    // but a cheap one — 5ms wall and 5ms CPU — so a 400ms tick while the menu
    // is up is about 1% of a core, against the 10% the live captures cost.
    property var clients: []
    function pollClients() {
        // `running = true` on a live Process is a silent no-op, so a poll
        // arriving while one is in flight is dropped rather than queued — the
        // one already running is about to deliver the same list.
        if (!clientPoll.running)
            clientPoll.running = true
    }
    Process {
        id: clientPoll
        command: ["hyprctl", "clients", "-j"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                try {
                    var a = JSON.parse(text)
                    for (var i = 0; i < a.length; i++) {
                        var c = a[i]
                        // an unmapped window is not on screen, so it has no
                        // place on the map
                        if (!c || !c.at || !c.size || !c.mapped)
                            continue
                        out.push({
                            // the IPC object's address carries a `0x` prefix
                            // that `HyprlandToplevel.address` does not, so the
                            // two are matched without it
                            addr: String(c.address).replace(/^0x/, ""),
                            ws: c.workspace ? c.workspace.id : -1,
                            at: c.at,
                            size: c.size
                        })
                    }
                } catch (e) {
                    // a truncated read leaves the previous list standing
                    return
                }
                root.clients = out
            }
        }
    }
    Timer {
        id: clientTick
        interval: 400
        repeat: true
        // `triggeredOnStart` so opening the menu reads immediately rather
        // than up to 400ms later, while the pop is still growing
        triggeredOnStart: true
        running: root.open
        onTriggered: root.pollClients()
    }
    // Windows opening and closing ARE announced — `Hyprland.toplevels` fires
    // for both, the same model that fails to hand them geometry. So a
    // structural change polls on the spot instead of waiting for the tick,
    // which is what makes an app appearing feel instant; the tick is left to
    // cover what nothing announces: a window moving or resizing.
    Connections {
        target: Hyprland.toplevels
        function onValuesChanged() { if (root.open) root.pollClients() }
    }

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
                anchors.topMargin: root.pad
                anchors.left: parent.left
                anchors.leftMargin: root.pad
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
                anchors.leftMargin: root.pad
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
                    // There is no container, so there is no resting fill: what
                    // you see is the thumbnail and its labels. Two cues carry
                    // the states, both the shell's existing language. The
                    // active workspace wears a thin accent ring around its
                    // thumbnail — the smallest form of the accent the selected
                    // tab and the toggle tiles wear, and enough to find at a
                    // glance without turning a whole tile yellow.
                    //
                    // Hover is the one cue that cannot come from the palette,
                    // and the reason is that it sits on a PICTURE: the island's
                    // soft inversion (cardHover) means lighten on the dark card
                    // and darken on the light one, and a dark veil over a dark
                    // capture is invisible — measured, the light palette's
                    // hover read exactly the same pixel as an untouched tile.
                    // A white veil at low alpha lifts the thumbnail's darks in
                    // BOTH palettes, which is what reads as the picture lighting
                    // up under the cursor rather than a slab appearing over it.
                    // It is a fixed value for the same reason cardAccent is:
                    // the thing under it is not palette content.
                    readonly property color ink: Theme.cardForeground
                    readonly property color hoverColor: Qt.rgba(1, 1, 1, 0.14)
                    // the lists' plate treatment, one step off the card, so
                    // the thumbnail reads as a screen rather than a hole
                    readonly property color screenColor: Theme.cardHighlight
                    readonly property color windowColor:
                        Qt.rgba(ink.r, ink.g, ink.b, 0.5)
                    readonly property color countColor:
                        Qt.rgba(ink.r, ink.g, ink.b, 0.6)
                    // ---- the minimap's geometry ------------------------------
                    // `at`/`size` are LAYOUT (logical) coordinates; the
                    // monitor's width/height are PHYSICAL, so the scale divide
                    // is what puts the two in one space. A rotated output
                    // reports its physical mode size, so its logical footprint
                    // has the axes swapped.
                    readonly property var geom: {
                        var mon = tile.monitor
                        var sc = (mon && mon.scale > 0) ? mon.scale : 1
                        var tf = (mon && mon.lastIpcObject)
                            ? (mon.lastIpcObject.transform || 0) : 0
                        var mw = mon ? (tf % 2 === 1 ? mon.height : mon.width) / sc : 16
                        var mh = mon ? (tf % 2 === 1 ? mon.width : mon.height) / sc : 10
                        return {
                            mw: mw > 0 ? mw : 16,
                            mh: mh > 0 ? mh : 10,
                            mx: mon ? mon.x : 0,
                            my: mon ? mon.y : 0
                        }
                    }
                    // One block per window, in mini-monitor pixels, clamped to
                    // the screen so a window hanging off the output cannot
                    // paint outside it. The block is the capture's placement
                    // and the fallback drawn until the first frame arrives, so
                    // the two can never disagree.
                    //
                    // This is a plain property fed by `syncBlocks()` rather
                    // than a binding, and that is the whole reason the
                    // thumbnails do not flicker: the array is only reassigned
                    // when its CONTENT changes, so the Repeater keeps its
                    // delegates (and their live captures) across a structural
                    // tick. A binding would hand over a fresh array on every
                    // tick, rebuilding every delegate four times a second and
                    // restarting every capture.
                    property var blocks: []
                    property string blockSig: ""
                    // The compositor's own list, not the toplevel model: a
                    // toplevel created after startup carries an empty
                    // `lastIpcObject` for good, so the model has no geometry
                    // for it (see `clients` on root).
                    function syncBlocks() {
                        var g = tile.geom
                        var w = root.screenWidth
                        var h = root.screenHeight
                        var list = root.clients
                        var out = []
                        for (var i = 0; i < list.length; i++) {
                            var c = list[i]
                            if (c.ws !== tile.ws.id)
                                continue
                            var x = (c.at[0] - g.mx) / g.mw * w
                            var y = (c.at[1] - g.my) / g.mh * h
                            var bw = c.size[0] / g.mw * w
                            var bh = c.size[1] / g.mh * h
                            var x0 = Math.max(0, x)
                            var y0 = Math.max(0, y)
                            var x1 = Math.min(w, x + bw)
                            var y1 = Math.min(h, y + bh)
                            if (x1 - x0 < 0.5 || y1 - y0 < 0.5)
                                continue
                            out.push({
                                x: x0,
                                y: y0,
                                w: x1 - x0,
                                h: y1 - y0,
                                addr: c.addr
                            })
                        }
                        var sig = JSON.stringify(out.map(function (b) {
                            return [b.x.toFixed(2), b.y.toFixed(2),
                                    b.w.toFixed(2), b.h.toFixed(2), b.addr]
                        }))
                        if (sig !== tile.blockSig) {
                            tile.blockSig = sig
                            tile.blocks = out
                        }
                    }
                    // The capture source is the toplevel's wayland handle,
                    // which the model DOES have (it is set off the
                    // `openwindow` event) — only its geometry is missing. So
                    // the two halves are resolved separately: the block comes
                    // from the compositor's list, the handle from the model,
                    // matched on address (the IPC object carries a `0x` the
                    // model does not).
                    //
                    // Reading `tile.toplevels` inside the function is what
                    // makes a delegate's `captureSource` binding re-evaluate
                    // when the model gains the toplevel.
                    function handleFor(addr) {
                        var list = tile.toplevels
                        for (var i = 0; i < list.length; i++)
                            if (list[i].address === addr)
                                return list[i].wayland
                        return null
                    }
                    Component.onCompleted: syncBlocks()
                    // the geometry poll — see `clients` on root
                    Connections {
                        target: root
                        function onClientsChanged() { tile.syncBlocks() }
                    }
                    // a monitor change rescales every block
                    onGeomChanged: syncBlocks()
                    width: root.tileWidth
                    height: root.tileHeight
                    // ---- the mini monitor ------------------------------------
                    // Square-cornered, because a screen is, and it is what
                    // lets the thumbnails be clipped by a plain `clip: true`
                    // — a rounded plate under square images would show their
                    // corners poking out of it the moment a window is
                    // fullscreen.
                    Item {
                        id: screenBox
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root.screenWidth
                        height: root.screenHeight
                        clip: true
                        // The screen plate and the window blocks. The blocks are
                        // the fallback: a real thumbnail is drawn over its block
                        // at exactly the same rect, so the tile reads correctly
                        // the instant it appears and fills in as the captures
                        // land.
                        Canvas {
                            id: screen
                            anchors.fill: parent
                            onPaint: {
                                var ctx = getContext("2d")
                                var w = width
                                var h = height
                                ctx.clearRect(0, 0, w, h)
                                // the lists' plate, one palette step off the
                                // card in either mode, which is what makes the
                                // thumbnail read as a screen rather than a
                                // hole in the plate
                                ctx.fillStyle = tile.screenColor
                                ctx.fillRect(0, 0, w, h)
                                ctx.fillStyle = tile.windowColor
                                var list = tile.blocks
                                for (var i = 0; i < list.length; i++) {
                                    var b = list[i]
                                    tile.roundRect(ctx, b.x, b.y, b.w, b.h, 1.5)
                                    ctx.fill()
                                }
                            }
                        }
                        // the live capture, over its block
                        Repeater {
                            model: tile.blocks
                            delegate: ScreencopyView {
                                required property var modelData
                                x: modelData.x
                                y: modelData.y
                                width: modelData.w
                                height: modelData.h
                                // the toplevel's own wayland handle — the same
                                // ext-image-copy route `grim -T` takes, so
                                // off-screen workspaces capture too, but
                                // in-process and continuous. Resolved off the
                                // block's address, because the compositor's
                                // list has the geometry and the model has the
                                // handle.
                                captureSource: tile.handleFor(modelData.addr)
                                // continuous while the plate is up, nothing at
                                // all once it closes
                                live: root.open
                                paintCursor: false
                                // the capture delivers at the tile's size
                                // rather than decoding a full 2560x1600 surface
                                // per window: 2x the slot is enough for the 1.6
                                // DPR and keeps the readback small
                                constraintSize: Qt.size(width * 2, height * 2)
                                // until the first frame lands the block
                                // underneath stands in, exactly as the old
                                // thumbnails did
                                visible: hasContent
                            }
                        }
                        onWidthChanged: screen.requestPaint()
                        onHeightChanged: screen.requestPaint()
                    }
                    // Hover lifts the THUMBNAIL, not a box around it: a veil
                    // sized to the screen and declared over the captures, so it
                    // tints them too. There is no container at rest, so there
                    // is nothing for a hover fill to redraw — the picture
                    // itself lights up. (The veil is a fixed white rather than
                    // a palette value; see the note on `hoverColor` above.)
                    Rectangle {
                        anchors.fill: screenBox
                        visible: tile.hovered
                        color: tile.hoverColor
                    }
                    // The active workspace's ring: a 2px accent outline on the
                    // thumbnail's own boundary. It is anchored to `fill:
                    // screenBox` rather than wrapped around it, for two
                    // reasons: the strip clips its children, so a ring hanging
                    // outside the screen would lose its top and bottom edges,
                    // and a Rectangle paints its border INSIDE its own bounds,
                    // so filling the screen puts the stroke exactly on the
                    // screen's edge. Declared after the box so it paints over
                    // the captures' outermost 2px; there is no fill, so the
                    // thumbnail is not dimmed by it. The 4px radius is small
                    // enough that the screen still reads square.
                    Rectangle {
                        anchors.fill: screenBox
                        radius: 4
                        visible: tile.active
                        color: "transparent"
                        border.width: 2
                        border.color: Theme.cardAccent
                    }
                    onInkChanged: screen.requestPaint()
                    onScreenColorChanged: screen.requestPaint()
                    onWindowColorChanged: screen.requestPaint()
                    onCountChanged: screen.requestPaint()
                    onMonitorChanged: screen.requestPaint()
                    onBlocksChanged: screen.requestPaint()
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
                    Text {
                        id: numberText
                        // the labels sit on the thumbnail's own edges now —
                        // there is no container to inset them from
                        anchors.left: parent.left
                        anchors.top: screenBox.bottom
                        anchors.topMargin: root.labelGap
                        height: root.labelHeight
                        verticalAlignment: Text.AlignVCenter
                        text: tile.ws.id
                        color: tile.ink
                        font.family: Theme.barFontFamily
                        // 14, up from 12 with the thumbnails: the tile grew 56%
                        // and a 12px number under a 112px screen read as a
                        // caption for a different, smaller thing
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: numberText.verticalCenter
                        // nothing on an empty workspace: a bare "0" reads as a
                        // count of something
                        visible: tile.count > 0
                        text: tile.count
                        color: tile.countColor
                        font.family: Theme.barFontFamily
                        // the number's step down, 12 against its 14
                        font.pixelSize: 12
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
