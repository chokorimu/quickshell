// Bar.qml — floating pill top bar with a dynamic island.
//   left:   "//" + now playing (circular art, scrolling "Artist - Song") + workspaces
//   center: clock — hover it and a media card pops open from the top center
//   right:  tray, network, volume, battery
//
// SUPER+L opens the island straight on the session page (hyprland runs
// `qs ipc call island session`); SUPER+L again, or leaving the active
// area, closes it. The rofi powermenu that used to live on SUPER+L
// moved to SUPER+SHIFT+L.
//
// The window reserves the pill's band via exclusiveZone in shell.qml, so
// windows are pushed down while the pill still floats centered inside it.
// The card pops open past that band, which is why the window is taller
// than the reservation and carries an input mask tracking both the pill
// and the card: without the mask the transparent area around them would
// swallow every click meant for the windows underneath.
import QtQml
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray
import "../../Theme"
import "../../Services"
// Capture lives in its own directory (Modules/Capture), so it needs an
// import of its own — QML imports do not propagate between files, and
// a sibling type like SessionCard resolves only because it sits in
// this same directory.
import "../Capture"

Item {
    id: root

    // load-bearing: as a child of the PanelWindow, this Item does not get
    // resized to fill the window's content item on its own. Without this the
    // root is 0x0 and the pill's horizontalCenter anchor centers against
    // nothing, parking half the pill off the left edge.
    anchors.fill: parent

    readonly property int barHeight: 40
    readonly property int topMargin: 8
    readonly property int barWidth: 1000
    // the card is 3:2 at half the bar's width — 600x400
    readonly property int cardWidth: 600
    readonly property int cardHeight: 400
    readonly property int cardRadius: 24
    // the menu column's strip down the card's left edge — the tab
    // buttons' own region (40 wide, flush at the card's edge), painted
    // in the bar's color against the darker card body (see the card
    // canvas). The page content clears it with its left margins.
    readonly property int cardColumnWidth: 56
    // the column's width while expanded — wide enough for a glyph plus
    // each menu's label. The card never resizes to accommodate it; the
    // expanded column simply overlays the page content underneath.
    readonly property int columnExpandedWidth: 150
    readonly property int workspacePillHeight: 30
    readonly property int workspaceCircleSize: 22
    // the workspace pill's right edge in bar coordinates — the left
    // boundary the clock and its hover zone must clear. The pill is
    // the last item in the left row, so its right edge is where the
    // row's content ends; it grows ~26px per workspace past the four
    // placeholders, reaching ~x530 at ten workspaces — well past
    // where a clock centered in the 1000px pill would start (~x430).
    readonly property real workspaceRight: leftRow.x + workspacePill.x + workspacePill.width
    // the pop's overshoot headroom. The pop-in bezier peaks at ~1.02x, so
    // the clip runs wider than the card and the window runs taller than
    // the card's resting bottom — without both, the overshoot gets shaved
    // off by the clip's side edges and the window's bounds respectively.
    readonly property real popOvershoot: 1.12

    // window geometry for shell.qml — the card's resting bottom plus
    // slack for the pop's overshoot (the 8 is the original clearance)
    readonly property int windowHeight: topMargin + barHeight + cardHeight + 8 + (cardHeight + cardRadius) * (popOvershoot - 1)

    // the pill and the card, so shell.qml can point its input mask at both
    readonly property Item pillItem: pill
    readonly property Item cardItem: cardClip

    // dynamic island state. Derived from the two hover zones below rather
    // than stored, so there is no signal ordering to get wrong.
    //
    // The grace timer matters more than it looks: the card lives outside
    // the window's input mask until it has finished swiping down, so a
    // cursor moving quickly from the clock toward the card can outrun the
    // growing container, slip out of the mask, and close the island on
    // its way in. Holding `expanded` for a moment after the cursor leaves
    // gives the container time to finish and the cursor time to land.
    // Which menu the card shows: "media" (clock hover), "volume"
    // (volume-icon hover), "session" (SUPER+L), or one of the tab
    // column's pages. Resets to media whenever the island collapses,
    // so the clock always opens the media page fresh.
    property string islandPage: "media"

    // The tab column expands on hover: 56px of icon-only strip at rest,
    // widening to columnExpandedWidth to reveal each menu's label.
    // columnWidth is what everything binds to; columnExpand is the
    // animated 0 -> 1 progress driving it. The card never resizes to
    // accommodate the expansion — the column overlays the page content
    // underneath, and only while the cursor is on it, so nothing stays
    // covered.
    property real columnExpand: 0
    readonly property real columnWidth: cardColumnWidth
        + (columnExpandedWidth - cardColumnWidth) * columnExpand

    Behavior on columnExpand {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    // hovering anywhere on the column — the strip itself or any of the
    // six buttons — holds the island open and the column expanded
    property bool columnHovered: columnZone.containsMouse
        || mediaTab.containsMouse
        || usageTab.containsMouse
        || themeTab.containsMouse
        || volumeTab.containsMouse
        || captureTab.containsMouse
        || sessionTab.containsMouse

    onColumnHoveredChanged: columnExpand = columnHovered ? 1 : 0

    // Derived hover keeps the card open while the cursor is over it
    // regardless of page. The tab buttons take hover events of their
    // own (they switch pages on enter), so they arrive here through
    // columnHovered rather than relying on hover falling through to
    // cardZone — the same OR-in that keeps a resting cursor on a
    // button from reading as a mouse-exit. The session page's power
    // cells are the third case: they take hover so a hold cancels when
    // the cursor walks off, which would otherwise steal cardZone's
    // hover and collapse the island under a resting cursor, so they
    // report up through SessionCard.hovered.
    property bool hovered: cardZone.containsMouse
        || columnHovered
        || (islandPage === "media" && clockZone.containsMouse)
        || (islandPage === "volume" && volumeIcon.containsMouse)
        || (islandPage === "session" && sessionPage.hovered)
        || (islandPage === "capture" && capturePage.hovered)

    // ---- the keyboard-opened session menu ---------------------------------
    // SUPER+L pins the island open on the session page with the cursor
    // nowhere near it. The pin is released the moment the cursor
    // reaches the island (onHoveredChanged), from which point the
    // ordinary hover rules apply — so "hover, then leave the active
    // area" closes it exactly like a hover-opened card. SUPER+L again
    // dismisses it outright.
    property bool sessionPinned: false

    // Set when the toggle closes the island while the cursor is resting
    // on it: without the latch the hover zones would reopen the card
    // under a stationary cursor. Cleared the moment the cursor actually
    // leaves, so the next hover behaves normally.
    property bool keyboardDismissed: false

    readonly property bool expanded: (hovered && !keyboardDismissed)
        || collapseGrace.running
        || sessionPinned

    onHoveredChanged: {
        if (hovered) {
            // handoff: the cursor has arrived, the pin is no longer needed
            root.sessionPinned = false
            collapseGrace.stop()
        } else {
            // a capture in flight must not restart the grace timer:
            // the cursor leaves the collapsing card, and the reopen
            // that follows would put the island back under the
            // cursor — and into the shot — before slurp has grabbed
            // it. See captureDismissing below.
            if (!root.captureDismissing) {
                root.keyboardDismissed = false
                collapseGrace.restart()
            }
        }
    }

    onSessionPinnedChanged: {
        if (sessionPinned)
            root.islandPage = "session"
    }

    Timer {
        id: collapseGrace
        interval: 350
        // Holds the card open through the linger after the cursor leaves.
        // The page is deliberately not touched here — it survives the
        // collapse and resets once the card is fully gone (popOut below),
        // so the shrink animates the menu the user was last looking at
        // instead of flashing the default mid-animation.
    }

    // ---- the capture dismissal ------------------------------------------
    // The capture page dismisses the island before firing its shot:
    // slurp takes the input grab, and the card would be in the
    // frame. The dismissal latches the island shut under the resting
    // cursor the way dismissSession does, but it runs into the grace
    // timer on the way out — the cursor leaves the shrinking card,
    // hovered goes false, and collapseGrace holds `expanded` long
    // enough for the card to pop back open under a stationary
    // cursor. captureDismissing is Capture.qml's `dismissing`, held
    // from the pill click until the shot is on its way, and it gates
    // that reopen (see the guard in onHoveredChanged above).
    property bool captureDismissing: capturePage.dismissing

    onCaptureDismissingChanged: {
        if (captureDismissing) {
            // the click: latch the island shut under the resting
            // cursor
            root.keyboardDismissed = root.hovered
        } else if (!root.hovered) {
            // the shot is on its way and the cursor is off the card:
            // release the latch so the next hover opens normally. If
            // the cursor somehow made it back onto the card, the
            // latch holds until it leaves again — the same sticky
            // behaviour the keyboard toggle has.
            root.keyboardDismissed = false
        }
    }

    // ---- the session menu over IPC ----------------------------------------
    // hyprland binds SUPER+L to `qs ipc call island session`; the rofi
    // powermenu that used to live on SUPER+L moved to SUPER+SHIFT+L.
    // The toggle closes an island already showing the session page and
    // opens one otherwise. One handler per bar: with several monitors
    // the IPC registry keeps the first registration and warns about the
    // rest, so exactly one island ever answers the call.
    function openSession() {
        root.keyboardDismissed = false
        root.sessionPinned = true
    }

    function dismissSession() {
        root.sessionPinned = false
        // hold hover off while the cursor rests on the card, or the
        // hover zones reopen the island the instant it is dismissed
        root.keyboardDismissed = root.hovered
    }

    IpcHandler {
        target: "island"
        function session(): void {
            if (root.expanded && root.islandPage === "session")
                root.dismissSession()
            else
                root.openSession()
        }
        function close(): void { root.dismissSession() }
    }

    // The card pops open from the top center instead of swiping down: one
    // progress value drives the clip's height — and with it the window's
    // input mask and the pill's roll fillets — plus the card's own
    // horizontal scale, so the card grows outward from the top center,
    // height from the bar's bottom edge and width from the center line.
    // In with a slight overshoot for the pop; out faster and without one,
    // so the card never dips below zero (a negative scale would mirror it).
    // The overshoot is a tamed bezier (~1.02x), not OutBack's 1.1x spring.
    property real pop: 0

    NumberAnimation {
        id: popIn
        target: root
        property: "pop"
        to: 1
        duration: 300
        // a tamed back-ease: the bezier's first control point lifts the
        // curve to ~1.02x before it settles, so the card keeps a hint of
        // life without the spring OutBack's 10% overshoot gave it
        // (measured: 1.0204 vs 1.1000). Qt 6 exposes the curve as a
        // flat list — c1x, c1y, c2x, c2y, endX, endY — not as
        // controlPoint1/2, and Easing is not creatable standalone.
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
        // The page outlives the collapse: it holds the last active menu
        // through the whole shrink and resets to the default only once
        // the card is fully gone, so the flip happens behind nothing and
        // the shrink animates the menu the user was last looking at
        // instead of flashing media mid-animation. The next open either
        // claims its own page (clock, volume icon, tab buttons, SUPER+L)
        // or starts from this default. onStopped rather than onFinished
        // so a degenerate no-op collapse still resets, with the !expanded
        // guard dropping the interrupted case — the cursor coming back
        // mid-shrink stops popOut with the card on its way open, and
        // that must leave the page alone.
        onStopped: if (!root.expanded) root.islandPage = "media"
    }

    onExpandedChanged: root.expanded ? popIn.start() : popOut.start()

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    function launch(cmd) {
        proc.command = cmd
        proc.running = true
    }

    Process { id: proc }

    // ---- workspaces -----------------------------------------------------
    // Hyprland.workspaces carries the special workspace (-98), is unordered,
    // and only lists workspaces that actually exist. Workspaces 1-4 are
    // persistent — always shown, with plain placeholder entries when empty —
    // and any real workspace above 4 is appended after them, sorted.
    property var workspaces: []

    function reloadWorkspaces() {
        var all = Hyprland.workspaces.values
        var real = {}
        var extra = []
        for (var i = 0; i < all.length; i++) {
            if (all[i].id <= 0)
                continue
            if (all[i].id <= 4)
                real[all[i].id] = all[i]
            else
                extra.push(all[i])
        }
        extra.sort(function (a, b) { return a.id - b.id })

        var out = []
        for (var id = 1; id <= 4; id++) {
            if (real[id])
                out.push(real[id])
            else
                out.push({ id: id, active: false })
        }
        root.workspaces = out.concat(extra)
    }

    // Quickshell 0.3.2 interpolates the request raw into a Lua call
    // (hl.dispatch(<request>)). With this Hyprland's Lua config the legacy
    // string form ("workspace N") is a syntax error and the quoted form is
    // rejected as "expected a dispatcher" — the working request is a real
    // dispatcher object: hl.dsp.focus({workspace = N}). This also creates
    // the workspace on demand, which is what makes the 1-4 placeholders
    // clickable. Native workspace.activate() works too, but only for
    // workspaces that already exist.
    function activateWorkspace(id) {
        Hyprland.dispatch("hl.dsp.focus({workspace = " + id + "})")
    }

    // load-bearing: forces the lazy Hyprland service to populate
    Connections {
        target: Hyprland.workspaces
        function onValuesChanged() { root.reloadWorkspaces() }
    }

    Component.onCompleted: root.reloadWorkspaces()

    // ---- hover: the card column ----------------------------------------
    // Keeps the island open while the cursor is anywhere over the card,
    // including on the transport buttons — those don't take hover events
    // themselves (a MouseArea only accepts hover when hoverEnabled is
    // true), so hover falls through to this zone underneath. The tab
    // buttons DO take hover (they switch pages on enter), so they are
    // OR'd into `hovered` directly instead of relying on fall-through.
    //
    // Declared before the card so the card's buttons keep their clicks;
    // the window's input mask clips this zone to the card's real area.
    MouseArea {
        id: cardZone
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: root.topMargin + root.barHeight
        width: root.cardWidth
        height: root.cardHeight
        hoverEnabled: true
    }

    // ---- the card: its own element, flush under the bar -----------------
    // Declared before the pill so the pill paints over the card's top
    // strip: the card tucks up behind the bar by its corner radius, which
    // hides its rounded top corners and makes the junction seamless — no
    // gap between the two shapes. The clipped container's height tracks
    // the pop progress (0 -> cardHeight + cardRadius) while the card
    // scales outward from the top center, so the card grows out from
    // behind the bar's bottom edge instead of fading in over it.
    Item {
        id: cardClip
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: root.topMargin + root.barHeight - root.cardRadius
        // wider than the card by the overshoot headroom: the card scales
        // past its resting width on the way in, and a clip at exactly
        // cardWidth would shave the overshoot off and flash the card's
        // side edges square against the boundary
        width: root.cardWidth * root.popOvershoot
        height: root.pop * (root.cardHeight + root.cardRadius)
        clip: true

        // no fade — the clip does all the work: the card pops out
        // from behind the bar fully opaque, and retracts back into it
        // on collapse

        // ---- the media backdrop's blur, rendered once ----------------
        // The blurred wash cannot be recomputed per frame: 13 full-card
        // taps is ~3M pixels of blending, and the card canvas repaints on
        // every frame of the pop (its bottom corner radius tracks the
        // visible height). So the blur lives here, and the card composites
        // it with a single drawImage.
        //
        // This canvas is the card's exact geometry — same size, same
        // center, same top-center scale — and is declared before it, so the
        // card paints over it and it is never visible on its own. Its
        // paint is deliberately static: the art at the card's resting
        // size, so the canvas's own bounds do the revealing as the clip
        // shrinks and the pop needs no repaint here.
        //
        // "Never visible on its own" needs the clip in the paint to be
        // true: the card's paint is TRANSPARENT outside its rounded
        // outline, so a full-square buffer shows through in exactly those
        // four corner regions and the card reads as having square corners
        // (verified by composite readback — see the paint). The card's own
        // drawImage clips the wash to the card's LIVE silhouette; this
        // clips the buffer itself to the same silhouette at rest, which is
        // what the card shows at pop 1. The one divergence is the bottom
        // corners' radius while the card is shorter than 2*cardRadius —
        // the first ~40ms of the pop, when it is under 100px wide.
        //
        // The taps average additively ('lighter', one Nth of each copy):
        // source-over cannot reach an exact average, and measuring it
        // showed why — the last copy drawn survives at (1 - a/N)^(N-1) and
        // takes ~37% of the result, while the per-step 8-bit truncation
        // costs another ~20% of the intended opacity. Adding avoids both.
        // The opaque black fill before them is the other load-bearing part
        // — see the paint.
        Canvas {
            id: artBuffer
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.cardWidth
            transform: Scale { origin.x: artBuffer.width / 2; origin.y: 0; xScale: root.pop }

            // The blur's tune-here lines, HyprlablurSizend-style — edit either
            // and the file watcher reloads the shell:
            //   blurSize   — the disc's radius in logical px (Hyprland's
            //                blur `size`). The wash spreads this far
            //                from every art pixel; bigger = stronger.
            //                0 = no blur: the generator degenerates to a
            //                single tap at (0,0), so the wash shows the
            //                raw art at full strength (measured SD 127.3
            //                against the unblurred 127.5) — the wash
            //                itself only goes away at artBackdropAlpha 0.
            //   blurStep   — tap spacing inside the disc. Smaller = more
            //                taps = a smoother average at proportionally
            //                more draws (13 at 10/5, 16 at 10/4, 29 at
            //                12/4).
            //   blurPasses — how many times the disc is applied. Each
            //                pass blurs the previous result, so the
            //                effective radius grows as size*sqrt(passes)
            //                and the tap count grows with it — 13 at
            //                passes 1, 22 at 2, 49 at 4 — the same order
            //                of draws as running the 13-tap disc that
            //                many times. 1 is the shipped look. More taps
            //                also dims the wash slightly ('lighter' loses
            //                energy as N grows); raise artBackdropAlpha on
            //                the card below to compensate.
            readonly property real blurSize: 0
            readonly property real blurStep: 1
            readonly property int blurPasses: 1

            // the tap set: a disc of offsets at blurStep spacing inside
            // blurSize*sqrt(blurPasses). Averaging one full-card copy of
            // the art per offset is a box blur — cheap, isotropic, and
            // smooth enough behind the page's content. Computed once;
            // the paint reads it per artwork.
            property var artTaps: []
            Component.onCompleted: {
                var r = blurSize * Math.sqrt(blurPasses), s = blurStep, t = []
                for (var dy = -r; dy <= r; dy += s)
                    for (var dx = -r; dx <= r; dx += s)
                        if (dx * dx + dy * dy <= r * r + 0.001)
                            t.push([dx, dy])
                artTaps = t
            }

            // The art source for the wash. An Image element rather than the
            // canvas's own loadImage because it loads asynchronously and
            // repaints on arrival. Children of a Canvas render above its
            // paint, so this one stays invisible and is only ever a pixmap
            // source. (sourceSize would be the usual way to cap a big
            // cover's decode, but canvas drawImage ignores it — a 1px line
            // survived an 8x downscale request — so it is not set here.)
            Image {
                id: mediaArtBackdrop
                visible: false
                asynchronous: true
                source: Media.artUrl
                onStatusChanged: { artBuffer.requestPaint() }
            }

            onPaint: {
                var ctx = getContext("2d")
                // the resting size, not the canvas's: the canvas's height is
                // the pop height, and the paint has to outrun it so the
                // bounds do the revealing
                var w = root.cardWidth
                var h = root.cardHeight + root.cardRadius
                ctx.clearRect(0, 0, w, h)
                // transparent when there is no art, so the card's composite
                // is a no-op rather than a black wash
                if (mediaArtBackdrop.status !== Image.Ready)
                    return

                // Opaque black before the taps is load-bearing: with a
                // transparent destination the accumulated alpha only reaches
                // ~55% and the colour is then divided by that alpha on read,
                // which composites at the wrong strength (measured: a 1.3x
                // colour over-delivery under a 55% alpha). Filled opaque, the
                // alpha stays 1 for every tap and 'lighter' only adds colour.
                //
                // Everything from here is clipped to the card's own rounded
                // silhouette — the same outline the card paints, at the
                // resting size this canvas paints at. Without it the buffer
                // is a full square, and because it sits BELOW the card (whose
                // paint is transparent outside its outline) its square
                // corners show through and the card reads as square-cornered.
                // Probed by composite readback: unclipped, the corner outside
                // the card's arc samples the buffer's art; clipped, it is
                // transparent and falls through to the wallpaper.
                var r = root.cardRadius
                ctx.beginPath()
                ctx.moveTo(r, 0)
                ctx.lineTo(w - r, 0)
                ctx.arc(w - r, r, r, -Math.PI / 2, 0, false)          // top-right
                ctx.lineTo(w, h - r)
                ctx.arc(w - r, h - r, r, 0, Math.PI / 2, false)       // bottom-right
                ctx.lineTo(r, h)
                ctx.arc(r, h - r, r, Math.PI / 2, Math.PI, false)     // bottom-left
                ctx.lineTo(0, r)
                ctx.arc(r, r, r, Math.PI, 3 * Math.PI / 2, false)     // top-left
                ctx.closePath()
                ctx.save()
                ctx.clip()

                ctx.fillStyle = "#000000"
                ctx.fillRect(0, 0, w, h)

                // Cover-fit, not stretch: the art is scaled until it
                // fills the card in BOTH axes and the overflow is
                // cropped, so a square cover keeps its aspect ratio on
                // the 600x424 card instead of being squashed to fit.
                // The crop is centred, which also keeps every blur tap
                // inside the drawn copy — the copy is at least as large
                // as the card on both axes, so a tap shifted off one
                // edge still has the copy's own margin behind it (the
                // stretch version had no margin at all, so its edge
                // pixels relied on the taps shifted toward them).
                var iw = mediaArtBackdrop.implicitWidth
                var ih = mediaArtBackdrop.implicitHeight
                var scale = (iw > 0 && ih > 0) ? Math.max(w / iw, h / ih) : 1
                var dw = iw * scale
                var dh = ih * scale
                var dx = (w - dw) / 2
                var dy = (h - dh) / 2

                var n = artTaps.length
                ctx.globalCompositeOperation = "lighter"
                ctx.globalAlpha = 1 / n
                for (var i = 0; i < n; i++)
                    ctx.drawImage(mediaArtBackdrop, dx + artTaps[i][0], dy + artTaps[i][1], dw, dh)
                ctx.globalCompositeOperation = "source-over"
                ctx.globalAlpha = 1
                ctx.restore()

                // The card composites this canvas, so it must repaint
                // AFTER this paint lands, not merely alongside it. The
                // art's onStatusChanged used to request both canvases in
                // the same pass, and a same-pass pair paints the card
                // before the buffer's new texture is committed, so the
                // card's drawImage read the buffer's PREVIOUS texture:
                // the wash sat a full track behind on every prev/next.
                // Requesting the card from the end of this paint defers
                // it one pass, by which time the texture is committed.
                // No loop: the card's paint never requests this one.
                card.requestPaint()
            }
        }

        // A Canvas, not a Rectangle: the bottom corners stay rounded
        // through the whole pop. A Rectangle's radius is fixed, so an
        // 18px corner on a card the clip hasn't finished revealing reads
        // as a clipped square — the rounding only "appears" once the
        // card is fully open. Here the bottom radius tracks the card's
        // visible height: full cardRadius once there's room for one, a
        // semicircular cap while the card is shorter than that, and zero
        // before the card clears the bar's bottom edge. The top corners
        // keep the full radius — they're tucked behind the bar anyway.
        // The canvas fills the clip's height, so it repaints every frame
        // of the pop (same per-frame repaint the pill's roll uses).
        Canvas {
            id: card
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.cardWidth

            // the pop: the whole card — painted background and content
            // alike — scales outward from the top center. The height
            // comes from the clip (pop-bound); this handles the width.
            transform: Scale { origin.x: card.width / 2; origin.y: 0; xScale: root.pop }

            // How much of the media page's surface is the artwork wash.
            // THE tune-here line: 0 is the plain card, 1 is the art at
            // full strength (with the card's ink and the visualizer
            // lines fighting it for legibility). The buffer is opaque, so
            // this is the wash's exact fraction of the blurred art —
            // modulo the blur's own 8-bit rounding, which measures within
            // a few percent of the art's channels on a real cover
            // (verified end to end: the card lands 2-4% under the
            // intent).
            readonly property real artBackdropAlpha: 0.1

            Connections {
                target: cardClip
                function onHeightChanged() { card.requestPaint() }
            }

            // the column's hover expansion repaints the strip's width
            // every frame of the animation. A page switch repaints the
            // media backdrop in or out — it is the media page's material,
            // and the other pages keep the plain card surface.
            Connections {
                target: root
                function onColumnExpandChanged() { card.requestPaint() }
                function onIslandPageChanged() { card.requestPaint() }
            }

            // a matugen regeneration rewrites the palette underneath
            // the painted fill — repaint when either color changes
            Connections {
                target: Theme
                function onBarBackgroundChanged() { card.requestPaint() }
                function onCardBackgroundChanged() { card.requestPaint() }
            }

            onPaint: {
                var ctx = getContext("2d")
                var w = width
                var h = height
                var rt = root.cardRadius
                var rb = Math.min(root.cardRadius, Math.max(0, (h - root.cardRadius) / 2))

                ctx.clearRect(0, 0, w, h)
                ctx.fillStyle = Theme.cardBackground
                ctx.beginPath()

                // one clockwise outline: top edge, top-right cap, right
                // edge, bottom-right cap, bottom edge, bottom-left cap,
                // left edge, top-left cap. Every arc starts at the point
                // the path is already standing on, or canvas silently
                // inserts a straight connector and the curve collapses.
                ctx.moveTo(rt, 0)
                ctx.lineTo(w - rt, 0)
                ctx.arc(w - rt, rt, rt, -Math.PI / 2, 0, false)          // top-right
                ctx.lineTo(w, h - rb)
                if (rb > 0.5)
                    ctx.arc(w - rb, h - rb, rb, 0, Math.PI / 2, false)   // bottom-right
                ctx.lineTo(rb, h)
                if (rb > 0.5)
                    ctx.arc(rb, h - rb, rb, Math.PI / 2, Math.PI, false) // bottom-left
                ctx.lineTo(0, rt)
                ctx.arc(rt, rt, rt, Math.PI, 3 * Math.PI / 2, false)     // top-left
                ctx.closePath()
                ctx.fill()

                // ---- media page backdrop: blurred album art --------------
                // A low-opacity wash of the current artwork behind the
                // media page's content — the art disc, the title, the
                // transport pill and the visualizer lines all paint above
                // it, since the content Item renders above this canvas.
                //
                // The blur itself is computed once, in artBuffer: 13
                // full-card taps is ~3M pixels of blending, and this canvas
                // repaints on every frame of the pop (its bottom corner
                // radius tracks the visible height). All that is left here
                // is one drawImage at the wash's alpha, which is what makes
                // the constant above exact.
                //
                // The clip is still current after the fill, so the
                // composite is masked to the card's own silhouette and
                // never reaches past the rounded corners into the desktop.
                // It is drawn at the card's resting height, not the
                // visible one, so the art does not squash as the card
                // pops — the clip reveals it instead. No art loaded means
                // the buffer painted clear, and this is a no-op.
                if (root.islandPage === "media" && h > 1) {
                    ctx.save()
                    ctx.clip()
                    ctx.globalAlpha = artBackdropAlpha
                    ctx.drawImage(artBuffer, 0, 0)
                    ctx.restore()
                }

                // the menu column strip down the left edge takes the
                // bar's color — the bar's material extends down into
                // the card, and the card body is the darker surface
                // around it. The path is still current after the
                // fill, so clipping to it hands the strip the card's
                // own rounded left corners for free. It scales with
                // the pop like everything else here. (A drop shadow
                // to the strip's right lived here once and was cut —
                // at any opacity that still read as a shadow it read
                // as a smudge against the card.)
                ctx.save()
                ctx.clip()
                ctx.fillStyle = Theme.barBackground
                ctx.fillRect(0, 0, root.columnWidth, h)
                ctx.restore()
            }

            // the content lives in the visible band below the tucked strip
            Item {
                anchors.top: parent.top
                anchors.topMargin: root.cardRadius
                width: parent.width
                height: root.cardHeight
                enabled: root.expanded

                // ---- media page background: the cava visualizer ----------
                // The bottom-most child of the content item, so the lines
                // paint behind the art, the title and the transport
                // pill. It starts past the column strip: that strip is
                // painted by the card canvas *below* this item, so lines
                // reaching under it would paint over the bar's own
                // material.
                //
                // One Canvas rather than a Repeater of Rectangles — a
                // single paint call per frame instead of 32 binding
                // updates, and it matches how the pill, the card and the
                // art disc are drawn. The levels come from
                // Services/Cava.qml, which runs a headless cava in raw
                // mode; see that file's header for why SplitParser and
                // not StdioCollector.
                //
                // Thin lines, not bars: a fixed 2px stem with the gap
                // absorbing whatever width is left, so the row fills the
                // card at any width. They run the full height of the page
                // — behind the disc, the title and the transport pill —
                // which is what makes them read as a backdrop rather than
                // a widget sitting on the card. In silence the whole row
                // is one unbroken 2px line.
                //
                // The color is the card's own ink, not the fixed accent:
                // near-black lines on the light card, near-white on the
                // dark one, so the visualizer follows the theme switch
                // instead of sitting on top of the palette. The right
                // margin keeps the stems clear of the card's rounded
                // bottom-right corner — nothing in here is clipped to
                // the card's silhouette (a Canvas clips only its own
                // paint), so a line running to the card's right edge
                // would paint onto the wallpaper in the corner. At 24
                // the last stem's corner lands exactly on the arc's
                // bottom point, tangent to it, which is why the lines
                // can sit flush to the bottom edge without spilling.
                Canvas {
                    id: visualizer
                    anchors.left: parent.left
                    anchors.leftMargin: root.cardColumnWidth + 20
                    anchors.right: parent.right
                    anchors.rightMargin: 24
                    anchors.bottom: parent.bottom
                    height: 300
                    visible: root.islandPage === "media"

                    Connections {
                        target: Cava
                        // cava runs for the shell's whole life now, so
                        // frames arrive while this card is closed too.
                        // Guard on visibility: an invisible canvas does
                        // not need repainting, and a collapsed island
                        // should stay idle rather than wake 60 times a
                        // second for a backdrop nobody is looking at.
                        function onFrame() {
                            if (visualizer.visible)
                                visualizer.requestPaint()
                        }
                    }

                    // the lines take the card's ink, which flips with the
                    // palette — repaint when it moves (theme switch or
                    // matugen regeneration)
                    Connections {
                        target: Theme
                        function onCardForegroundChanged() { visualizer.requestPaint() }
                    }

                    onPaint: {
                        var ctx = getContext("2d")
                        var w = width
                        var h = height
                        ctx.clearRect(0, 0, w, h)

                        var levels = Cava.levels
                        if (!levels || levels.length === 0)
                            return

                        // fixed 2px stem, gap absorbs the rest — the row
                        // fills whatever width the card has
                        var bw = 2
                        var n = levels.length
                        var gap = (w - bw * n) / (n - 1)
                        if (gap < 1)
                            return

                        ctx.fillStyle = Theme.cardForeground
                        ctx.globalAlpha = 0.7
                        for (var i = 0; i < n; i++) {
                            // a 2px floor, so the row reads as part of
                            // the card's design in silence instead of
                            // vanishing and looking broken
                            var bh = Math.max(2, levels[i] * h)
                            ctx.fillRect(i * (bw + gap), h - bh, bw, bh)
                        }
                        ctx.globalAlpha = 1
                    }
                }

                // ---- usage page: cpu / gpu / memory / disk / battery ------
                // Same card, same pop — reached by hovering the second
                // tab button in the column. Gated on the page like the
                // others, so nothing paints underneath.
                UsageCard {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    visible: root.islandPage === "usage"
                }

                // ---- volume page: per-app sliders, pavucontrol style -------
                // Same card, same pop — the volume icon in the bar's right
                // row hovers this page open. Gated on the page so the media
                // content below never paints underneath it.
                VolumeCard {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    visible: root.islandPage === "volume"
                }

                // ---- theme page: the auto/light/dark switch ---------------
                // Same card, same pop — reached by hovering the third
                // tab button in the column. Gated on the page like the
                // others, so nothing paints underneath.
                ThemeCard {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    visible: root.islandPage === "theme"
                }

                // ---- capture page: screenshot / clipboard / record -------
                // Same card, same pop — reached by hovering the fifth
                // tab button in the column. Gated on the page like the
                // others, so nothing paints underneath.
                Capture {
                    id: capturePage
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    visible: root.islandPage === "capture"
                }

                // ---- session page: avatar, user@host, power grid --------
                // Same card, same pop — reached by hovering the sixth
                // tab button in the column. Gated on the page like the
                // other five, so nothing paints underneath.
                SessionCard {
                    id: sessionPage
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    visible: root.islandPage === "session"
                }

                // ---- page switcher: vertical tab column --------------------
                // Six buttons down the card's left edge, flush against
                // the card's edge and each other (no margin, no gaps) and
                // as wide as the column strip itself, so the block fills
                // the strip edge to edge with no dead space beside it.
                // Order is media, usage, theme, volume, capture, session. The
                // selected page takes the accent fill — square
                // corners, near-black glyph, and a black block down its
                // left edge taking the full height and the left 10% of
                // the button — so it reads as one solid lime slab; the
                // unselected one stays transparent. Hovering a button
                // switches pages outright — no click needed; the bar's
                // hover triggers (clock, volume icon) still select a
                // page on the way in.
                //
                // The whole column expands on hover: the buttons widen
                // from the resting 56px strip to columnExpandedWidth,
                // revealing each menu's name beside its glyph, and the
                // card canvas repaints the strip to match. The card
                // itself never resizes — the expanded column overlays
                // whatever page content sits under it, and only while
                // the cursor is on the column.

                // hover zone over the whole column strip — expands the
                // column wherever the cursor lands on it, and keeps the
                // island open (OR'd into hovered via columnHovered).
                // Its width tracks the expansion so the revealed label
                // area stays live. Declared before the buttons so they
                // keep their own hover; being a MouseArea it paints
                // nothing itself — the cover Rectangle below is what
                // sits above the pages.
                MouseArea {
                    id: columnZone
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.topMargin: 28
                    width: root.columnWidth
                    height: root.cardHeight - 28
                    hoverEnabled: true
                }

                // the expansion's cover. The card canvas paints the
                // strip across the full columnWidth, but the pages
                // render above the canvas — so without this the
                // revealed 56..columnWidth region would show page
                // content through the transparent buttons. This
                // Rectangle carries z:1, which puts it above the
                // media content too (the art/title/transport are
                // declared before it, so the strip now covers them
                // properly instead of the title painting over the
                // accordion). It starts past cardColumnWidth so it
                // never touches the card's rounded left corners (the
                // canvas keeps those) and every edge it does have
                // lands on a straight card edge. Zero width at rest,
                // and a plain Rectangle takes no hover, so columnZone
                // and the buttons keep their input.
                Rectangle {
                    z: 1
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    x: root.cardColumnWidth
                    width: root.columnWidth - root.cardColumnWidth
                    color: Theme.barBackground
                }

                Column {
                    z: 2
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.topMargin: 28
                    anchors.leftMargin: 0
                    spacing: 0

                    Rectangle {
                        width: root.columnWidth
                        height: 40
                        color: root.islandPage === "media" ? Theme.cardAccent : "transparent"

                        // the selected marker: a black block down the
                        // button's left edge, taking the full height
                        // and the left 10% of the resting strip — no
                        // inset, so it reads as part of the silhouette
                        Rectangle {
                            x: 0
                            width: root.cardColumnWidth * 0.1
                            height: parent.height
                            color: "black"
                            visible: root.islandPage === "media"
                        }

                        // the glyph holds the resting 56px icon zone —
                        // it does not drift right as the column opens
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.horizontalCenterOffset: -(parent.width - root.cardColumnWidth) / 2
                            text: "\uF001" // music note
                            color: root.islandPage === "media" ? Theme.cardAccentOn : Theme.barDim
                            font.family: Theme.iconFont
                            font.pixelSize: 17
                        }

                        // the menu's name, revealed by the expansion —
                        // clipped to the button so it can't spill onto
                        // the card mid-animation
                        Item {
                            anchors.left: parent.left
                            anchors.leftMargin: root.cardColumnWidth
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            clip: true
                            visible: root.columnExpand > 0.01

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                x: 10
                                width: Math.max(0, parent.width - 20)
                                text: "Media"
                                color: root.islandPage === "media" ? Theme.cardAccentOn : Theme.barDim
                                font.family: Theme.barFontFamily
                                font.pixelSize: 13
                                elide: Text.ElideRight
                                opacity: root.columnExpand
                            }
                        }

                        MouseArea {
                            id: mediaTab
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: root.islandPage = "media"
                        }
                    }

                    // ---- usage: cpu / gpu / memory / disk / battery ---------
                    // Second in the column, between media and theme.
                    Rectangle {
                        width: root.columnWidth
                        height: 40
                        color: root.islandPage === "usage" ? Theme.cardAccent : "transparent"

                        // the selected marker: a black block down the
                        // button's left edge, taking the full height
                        // and the left 10% of the resting strip — no
                        // inset, so it reads as part of the silhouette
                        Rectangle {
                            x: 0
                            width: root.cardColumnWidth * 0.1
                            height: parent.height
                            color: "black"
                            visible: root.islandPage === "usage"
                        }

                        // the glyph holds the resting 56px icon zone —
                        // it does not drift right as the column opens
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.horizontalCenterOffset: -(parent.width - root.cardColumnWidth) / 2
                            text: "\uF2DB" // microchip
                            color: root.islandPage === "usage" ? Theme.cardAccentOn : Theme.barDim
                            font.family: Theme.iconFont
                            font.pixelSize: 17
                        }

                        // the menu's name, revealed by the expansion —
                        // clipped to the button so it can't spill onto
                        // the card mid-animation
                        Item {
                            anchors.left: parent.left
                            anchors.leftMargin: root.cardColumnWidth
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            clip: true
                            visible: root.columnExpand > 0.01

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                x: 10
                                width: Math.max(0, parent.width - 20)
                                text: "Usage"
                                color: root.islandPage === "usage" ? Theme.cardAccentOn : Theme.barDim
                                font.family: Theme.barFontFamily
                                font.pixelSize: 13
                                elide: Text.ElideRight
                                opacity: root.columnExpand
                            }
                        }

                        MouseArea {
                            id: usageTab
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: root.islandPage = "usage"
                        }
                    }

                    // ---- theme: the auto/light/dark switch -------------------
                    // Third in the column, between usage and volume.
                    Rectangle {
                        width: root.columnWidth
                        height: 40
                        color: root.islandPage === "theme" ? Theme.cardAccent : "transparent"

                        // the selected marker: a black block down the
                        // button's left edge, taking the full height
                        // and the left 10% of the resting strip — no
                        // inset, so it reads as part of the silhouette
                        Rectangle {
                            x: 0
                            width: root.cardColumnWidth * 0.1
                            height: parent.height
                            color: "black"
                            visible: root.islandPage === "theme"
                        }

                        // the glyph holds the resting 56px icon zone —
                        // it does not drift right as the column opens
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.horizontalCenterOffset: -(parent.width - root.cardColumnWidth) / 2
                            text: "\uF185" // sun
                            color: root.islandPage === "theme" ? Theme.cardAccentOn : Theme.barDim
                            font.family: Theme.iconFont
                            font.pixelSize: 17
                        }

                        // the menu's name, revealed by the expansion —
                        // clipped to the button so it can't spill onto
                        // the card mid-animation
                        Item {
                            anchors.left: parent.left
                            anchors.leftMargin: root.cardColumnWidth
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            clip: true
                            visible: root.columnExpand > 0.01

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                x: 10
                                width: Math.max(0, parent.width - 20)
                                text: "Theme"
                                color: root.islandPage === "theme" ? Theme.cardAccentOn : Theme.barDim
                                font.family: Theme.barFontFamily
                                font.pixelSize: 13
                                elide: Text.ElideRight
                                opacity: root.columnExpand
                            }
                        }

                        MouseArea {
                            id: themeTab
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: root.islandPage = "theme"
                        }
                    }

                    Rectangle {
                        width: root.columnWidth
                        height: 40
                        color: root.islandPage === "volume" ? Theme.cardAccent : "transparent"

                        // the selected marker: a black block down the
                        // button's left edge, taking the full height
                        // and the left 10% of the resting strip — no
                        // inset, so it reads as part of the silhouette
                        Rectangle {
                            x: 0
                            width: root.cardColumnWidth * 0.1
                            height: parent.height
                            color: "black"
                            visible: root.islandPage === "volume"
                        }

                        // the glyph holds the resting 56px icon zone —
                        // it does not drift right as the column opens
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.horizontalCenterOffset: -(parent.width - root.cardColumnWidth) / 2
                            text: "\uF028" // speaker
                            color: root.islandPage === "volume" ? Theme.cardAccentOn : Theme.barDim
                            font.family: Theme.iconFont
                            font.pixelSize: 17
                        }

                        // the menu's name, revealed by the expansion —
                        // clipped to the button so it can't spill onto
                        // the card mid-animation
                        Item {
                            anchors.left: parent.left
                            anchors.leftMargin: root.cardColumnWidth
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            clip: true
                            visible: root.columnExpand > 0.01

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                x: 10
                                width: Math.max(0, parent.width - 20)
                                text: "Volume"
                                color: root.islandPage === "volume" ? Theme.cardAccentOn : Theme.barDim
                                font.family: Theme.barFontFamily
                                font.pixelSize: 13
                                elide: Text.ElideRight
                                opacity: root.columnExpand
                            }
                        }

                        MouseArea {
                            id: volumeTab
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: root.islandPage = "volume"
                        }
                    }

                    // ---- capture: screenshot / clipboard / record ---------
                    // Fifth in the column, between volume and session.
                    Rectangle {
                        width: root.columnWidth
                        height: 40
                        color: root.islandPage === "capture" ? Theme.cardAccent : "transparent"

                        // the selected marker: a black block down the
                        // button's left edge, taking the full height
                        // and the left 10% of the resting strip — no
                        // inset, so it reads as part of the silhouette
                        Rectangle {
                            x: 0
                            width: root.cardColumnWidth * 0.1
                            height: parent.height
                            color: "black"
                            visible: root.islandPage === "capture"
                        }

                        // the glyph holds the resting 56px icon zone —
                        // it does not drift right as the column opens
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.horizontalCenterOffset: -(parent.width - root.cardColumnWidth) / 2
                            text: "\uF030" // camera (body + lens)
                            color: root.islandPage === "capture" ? Theme.cardAccentOn : Theme.barDim
                            font.family: Theme.iconFont
                            font.pixelSize: 17
                        }

                        // the menu's name, revealed by the expansion —
                        // clipped to the button so it can't spill onto
                        // the card mid-animation
                        Item {
                            anchors.left: parent.left
                            anchors.leftMargin: root.cardColumnWidth
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            clip: true
                            visible: root.columnExpand > 0.01

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                x: 10
                                width: Math.max(0, parent.width - 20)
                                text: "Capture"
                                color: root.islandPage === "capture" ? Theme.cardAccentOn : Theme.barDim
                                font.family: Theme.barFontFamily
                                font.pixelSize: 13
                                elide: Text.ElideRight
                                opacity: root.columnExpand
                            }
                        }

                        MouseArea {
                            id: captureTab
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: root.islandPage = "capture"
                        }
                    }

                    Rectangle {
                        width: root.columnWidth
                        height: 40
                        color: root.islandPage === "session" ? Theme.cardAccent : "transparent"

                        // the selected marker: a black block down the
                        // button's left edge, taking the full height
                        // and the left 10% of the resting strip — no
                        // inset, so it reads as part of the silhouette
                        Rectangle {
                            x: 0
                            width: root.cardColumnWidth * 0.1
                            height: parent.height
                            color: "black"
                            visible: root.islandPage === "session"
                        }

                        // the glyph holds the resting 56px icon zone —
                        // it does not drift right as the column opens
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.horizontalCenterOffset: -(parent.width - root.cardColumnWidth) / 2
                            text: "\uDB82\uDC1C" // door-open
                            color: root.islandPage === "session" ? Theme.cardAccentOn : Theme.barDim
                            font.family: Theme.iconFont
                            font.pixelSize: 17
                        }

                        // the menu's name, revealed by the expansion —
                        // clipped to the button so it can't spill onto
                        // the card mid-animation
                        Item {
                            anchors.left: parent.left
                            anchors.leftMargin: root.cardColumnWidth
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            clip: true
                            visible: root.columnExpand > 0.01

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                x: 10
                                width: Math.max(0, parent.width - 20)
                                text: "Session"
                                color: root.islandPage === "session" ? Theme.cardAccentOn : Theme.barDim
                                font.family: Theme.barFontFamily
                                font.pixelSize: 13
                                elide: Text.ElideRight
                                opacity: root.columnExpand
                            }
                        }

                        MouseArea {
                            id: sessionTab
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: root.islandPage = "session"
                        }
                    }
                }

                // big circular art — click toggles, wheel skips. Anchored
                // near the top of the card, centered.
                //
                // The disc is a Canvas, not a masked Image: clip:true on a
                // Rectangle only rounds the Rectangle's OWN paint — its
                // children still render square, which is why the art used
                // to show square corners, and OpacityMask against a
                // circular Rectangle did not clip either (the mask never
                // masked the source — the art stayed square). A Canvas
                // clips its own paint with an arc path, which always
                // works, and the whole disc spins clockwise while a track
                // plays — a rotating circle is rotation-invariant, so only
                // the art inside moves. Pausing freezes it mid-turn; a
                // track change keeps the angle, like a record.
                Item {
                    id: bigArt
                    anchors.horizontalCenter: parent.horizontalCenter
                    // center in the content area, not the full card —
                    // the column strip owns the left edge
                    anchors.horizontalCenterOffset: root.cardColumnWidth / 2
                    // hung from its bottom edge rather than its top: the
                    // size switch's "big" grows the disc upward from here,
                    // so the title and the transport pill below it never
                    // move and the top is the end the card's clip cuts off
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: parent.height - bottomEdge
                    visible: root.islandPage === "media"

                    // the disc's resting geometry: 28 from the top of the
                    // content area and 200 tall, so its bottom edge sits
                    // at content y228
                    readonly property real restingSize: 200
                    readonly property real bottomEdge: 28 + restingSize
                    // "big" grows the disc until a third of it sits above
                    // the bar's bottom edge (content y0), where the bar
                    // itself and the card's clip hide it: the visible band
                    // runs from there down to bottomEdge — 228px — and 228
                    // is two thirds of 342. The centre rises with the
                    // growth, which is what puts the disc's top-right arc
                    // under the size switch.
                    readonly property real discSize: mediaSizeSwitch.size === "big"
                                                   ? bottomEdge * 3 / 2
                                                   : restingSize
                    width: discSize
                    height: discSize

                    // one revolution per 10s, clockwise (rotation
                    // increases — Qt's positive direction is clockwise).
                    // The 0 → 360 loop snap is invisible: 360 ≡ 0.
                    //
                    // Pausing SUSPENDS the animation; it does not stop it.
                    // A stopped QML animation restarts from `from` on its
                    // next run, which is what snapped the disc back to 0
                    // on every unpause. A paused one freezes the target at
                    // the angle it reached and continues from exactly
                    // there (probed: 217.80 held across three samples,
                    // then 254.88 — no jump, no reset). So `running`
                    // tracks the player and `paused` tracks playback: the
                    // animation only stops when the player itself goes
                    // away, where restarting from 0 is right (a fresh
                    // record), and it survives any number of
                    // pause/unpause cycles mid-turn.
                    //
                    // Two details that keep that true: `setPaused()` is a
                    // no-op before the animation is running, so a player
                    // that appears ALREADY paused would spin anyway —
                    // onRunningChanged pauses it in that one case; and
                    // `paused` is gated on hasPlayer so the boot-time
                    // evaluation never calls setPaused() on a stopped
                    // animation (which logs a scene warning on every
                    // shell start).
                    RotationAnimation {
                        id: discSpin
                        target: bigArt
                        property: "rotation"
                        from: 0
                        to: 360
                        duration: 10000
                        loops: Animation.Infinite
                        running: Media.hasPlayer
                        paused: Media.hasPlayer && !Media.playing
                        onRunningChanged: if (running && !Media.playing) pause()
                    }

                    // placeholder disc while no art is loaded — the canvas
                    // paints the art over it once there is one
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Theme.cardHighlight
                    }

                    Canvas {
                        id: artDisc
                        anchors.fill: parent

                        // the art URL, tracked so the canvas can (re)load
                        // it; loadImage is async, so the paint waits for
                        // imageLoaded. An empty URL repaints the canvas
                        // clear so a track without art falls back to the
                        // placeholder instead of keeping the old one.
                        property url artSource: Media.artUrl
                        onArtSourceChanged: {
                            if (artSource.toString().length > 0) {
                                artDisc.loadImage(artSource)
                                // repaint on the URL change itself, not
                                // only on imageLoaded: loadImage does NOT
                                // re-emit imageLoaded for an already-seen
                                // URL (verified by probe), so pressing
                                // prev — back to art this canvas has
                                // already loaded — would never repaint and
                                // would keep showing the previous track's
                                // art. The paint draws straight from the
                                // URL through the canvas's pixmap cache,
                                // so a cached URL paints immediately and a
                                // fresh one completes when imageLoaded
                                // fires.
                                artDisc.requestPaint()
                            } else {
                                requestPaint()
                            }
                        }
                        Component.onCompleted: if (artSource.toString().length > 0) loadImage(artSource)
                        onImageLoaded: requestPaint()

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            if (artSource.toString().length === 0)
                                return
                            ctx.save()
                            ctx.beginPath()
                            ctx.arc(width / 2, height / 2, width / 2, 0, 2 * Math.PI)
                            ctx.clip()
                            ctx.drawImage(artSource, 0, 0, width, height)
                            ctx.restore()
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: Media.toggle()
                        onWheel: function (wheel) {
                            if (wheel.angleDelta.y > 0)
                                Media.next()
                            else
                                Media.previous()
                        }
                    }
                }

                // media size switch — the theme page's mode switch, scaled
                // down and parked in the media page's top right corner.
                // Same design: one pill on cardPill, two rounded segments
                // at a half each, the active one raised to the card's own
                // surface with a cardForeground label, the inactive one
                // transparent with a cardDim label. The theme pill runs 40
                // tall with a 14px label because it sits under a 120px
                // label column; this is a standalone corner control, so it
                // drops to 26 tall with an 11px label and fixed 40px
                // segments — equal halves, like the theme switch's, rather
                // than a fraction of a row that has to span the card.
                //
                // small — the disc as it has always been. big — the disc
                // grows upward from its bottom edge until a third of it is
                // behind the bar. No label: the two words say what it is,
                // and the corner has no room for a label column anyway.
                //
                // Declared after the disc, not before it: "big" grows the
                // disc's top-right arc into this corner, and the switch is
                // chrome — it has to paint over the art, not under it.
                //
                // Click-only, like every other MouseArea on the card: a
                // hover-enabled one here would steal cardZone's hover and
                // collapse the island under a resting cursor.
                Rectangle {
                    id: mediaSizeSwitch
                    anchors.top: parent.top
                    anchors.topMargin: 28
                    anchors.right: parent.right
                    anchors.rightMargin: 28
                    visible: root.islandPage === "media"
                    height: 26
                    radius: height / 2
                    color: Theme.cardPill
                    // the row's implicit width plus both margins — the
                    // transport pill's idiom, and loop-free here because
                    // the segments are a fixed width rather than a
                    // fraction of the row's
                    width: mediaSizeRow.implicitWidth + 6

                    readonly property var sizes: ["small", "big"]
                    property string size: "small"

                    Row {
                        id: mediaSizeRow
                        anchors.fill: parent
                        anchors.margins: 3
                        spacing: 3

                        Repeater {
                            model: mediaSizeSwitch.sizes

                            Rectangle {
                                required property var modelData
                                readonly property bool active: mediaSizeSwitch.size === modelData

                                width: 40
                                height: mediaSizeRow.height
                                radius: height / 2
                                color: active ? Theme.cardBackground : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                                    color: active ? Theme.cardForeground : Theme.cardDim
                                    font.family: Theme.barFontFamily
                                    font.pixelSize: 11
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: mediaSizeSwitch.size = modelData
                                }
                            }
                        }
                    }
                }

                // title / artist under the art, centered — elided so a long
                // name can't push the controls off the card. The expanded
                // accordion covers the title's left end like it covers the
                // other pages: the cover Rectangle below carries z:1, so
                // the strip paints over this content (declared before it)
                // while the tab buttons stay above at z:2.
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: root.cardColumnWidth / 2
                    anchors.top: bigArt.bottom
                    anchors.topMargin: 15
                    spacing: 6
                    visible: root.islandPage === "media"

                    Text {
                        width: 520
                        horizontalAlignment: Text.AlignHCenter
                        text: Media.hasPlayer ? (Media.title || "Unknown title") : "Not playing"
                        color: Media.hasPlayer ? Theme.cardForeground : Theme.cardDim
                        font.family: Theme.barFontFamily
                        font.pixelSize: 22
                        elide: Text.ElideRight
                    }

                    Text {
                        width: 520
                        horizontalAlignment: Text.AlignHCenter
                        text: Media.hasPlayer ? (Media.artist || "Unknown artist") : "nothing playing right now"
                        color: Theme.cardDim
                        font.family: Theme.barFontFamily
                        font.pixelSize: 15
                        elide: Text.ElideRight
                    }
                }

                // transport controls — the workspace pill's design,
                // properly this time rather than translated away from
                // it. The pill takes the workspace pill's own surface:
                // cardPill is that material on the card (the same value
                // as barWorkspacePill, one step darker than the card so
                // the pill reads against it). The active circle takes
                // the surface one step lighter — cardBackground, the
                // card's own color showing through, exactly the
                // active-workspace treatment — with a cardForeground
                // glyph, and the inactive circles stay transparent with
                // cardDim glyphs like the inactive workspace numbers.
                // All three circles are the same size, as they are in
                // the workspace pill: the fill marks the active one,
                // not the scale.
                //
                // This replaces an inverted cardInk pill. A slab of the
                // card's opposite color is far heavier than the material
                // the workspace pill uses, and it forced the inactive
                // glyphs to cardOnInk just to read on it. The workspace
                // pill's own surface sits in the same family as what it
                // stands on, and that is what these buttons should do.
                //
                // Glyphs, not labels — Nerd Font is set explicitly, since
                // the bar's UI font would render them as tofu.
                Rectangle {
                    id: transportPill
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: root.cardColumnWidth / 2
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 28
                    visible: root.islandPage === "media"
                    height: 56
                    radius: height / 2
                    color: Theme.cardPill
                    width: transportRow.implicitWidth + 16

                    Row {
                        id: transportRow
                        anchors.centerIn: parent
                        spacing: 8

                        // prev — inactive circle, transparent
                        Rectangle {
                            width: 46
                            height: 46
                            radius: width / 2
                            color: "transparent"

                            Text {
                                anchors.fill: parent
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: "\uF048" // fa-step-backward
                                color: Theme.cardDim
                                font.family: Theme.iconFont
                                font.pixelSize: 20
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: Media.previous()
                            }
                        }

                        // play / pause — the active circle, the card's
                        // own surface showing through the pill
                        Rectangle {
                            width: 46
                            height: 46
                            radius: width / 2
                            color: Theme.cardBackground

                            Text {
                                anchors.fill: parent
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: Media.playing ? "\uF04C" : "\uF04B" // fa-pause / fa-play
                                color: Theme.cardForeground
                                font.family: Theme.iconFont
                                font.pixelSize: 22
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: Media.toggle()
                            }
                        }

                        // next — inactive circle, transparent
                        Rectangle {
                            width: 46
                            height: 46
                            radius: width / 2
                            color: "transparent"

                            Text {
                                anchors.fill: parent
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: "\uF051" // fa-step-forward
                                color: Theme.cardDim
                                font.family: Theme.iconFont
                                font.pixelSize: 20
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: Media.next()
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- the pill -------------------------------------------------------
    // The bar never moves: it stays 1000x40 forever. The island is the
    // card below it — its own element, flush against the bar's bottom
    // edge — so the side zones stay exactly where they are and stay live
    // the whole time.
    //
    // A Canvas, not a Rectangle: a Rectangle's outline is fixed, and the
    // bottom edge needs to roll where the card emerges. The card's side
    // edges meet the bar's bottom edge at a hard 270° corner; the roll
    // replaces it with a tangent fillet — the bar's edge curves down and
    // flows into the card's side, so the card reads as sticking out of
    // the bar rather than butting against it. The fillet is one arc per
    // side, tangent to the bottom edge (horizontal) at its start and to
    // the card's side edge (vertical) at its end, centered in the empty
    // region outside the corner. It is material-growing, not a bite: no
    // gap opens, and the card's tucked corners stay hidden behind the
    // roll — which is why the smoothing lives here and not on the card.
    // `radius` is declared (not inherited — Canvas has none) because
    // shell.qml's input mask reads pillItem.radius.
    //
    // The Canvas is taller than the bar by exactly the roll's depth: the
    // rolls hang below the bottom edge and a Canvas clips its painting to
    // its own bounds, so a 36-tall canvas would cut them off. The extra
    // strip is transparent except for the rolls themselves, and the mask
    // in shell.qml pins the pill's region to the bar's own 36px band so
    // the strip never swallows clicks.
    //
    // The roll is not tied to `expanded`: its radius tracks the card's
    // visible overhang (see onPaint), so the junction stays smooth
    // through the entire pop in both directions. Tying it to the
    // boolean instead would pop the rolls off the moment a collapse
    // starts, leaving the sharp corner bare for the full 240ms the card
    // takes to retreat — and on the way in the rolls would flash before
    // the card's edges had grown into them.
    Canvas {
        id: pill

        anchors.top: parent.top
        anchors.topMargin: root.topMargin
        anchors.horizontalCenter: parent.horizontalCenter

        width: root.barWidth
        height: root.barHeight + root.cardRadius
        readonly property real radius: root.barHeight / 2

        // the roll's radius tracks the card's height, so repaint on
        // every frame of the pop — the fillet shrinks and grows with
        // the card instead of popping with the expanded boolean
        Connections {
            target: cardClip
            function onHeightChanged() { pill.requestPaint() }
        }

        // a matugen regeneration rewrites the palette underneath the
        // painted fill — repaint when the bar color changes
        Connections {
            target: Theme
            function onBarBackgroundChanged() { pill.requestPaint() }
        }

        onPaint: {
            var ctx = getContext("2d")
            var w = width
            var bh = root.barHeight   // the bar's bottom edge — not the
                                      // canvas height, which runs past it
                                      // by the roll's depth
            var r = radius

            ctx.clearRect(0, 0, w, height)
            ctx.fillStyle = Theme.barBackground
            ctx.beginPath()

            // one clockwise outline: top edge, right cap, bottom edge
            // (with the roll detours when expanded), left cap. Every arc
            // starts at the point the path is already standing on, or
            // canvas silently inserts a straight connector and the curve
            // collapses (Corners.qml learned this the hard way).
            ctx.moveTo(r, 0)
            ctx.lineTo(w - r, 0)
            ctx.arc(w - r, r, r, -Math.PI / 2, 0, false)               // right cap, top
            ctx.arc(w - r, r, r, 0, Math.PI / 2, false)                // right cap, bottom

            // the fillet radius tracks the card's visible overhang. The
            // card's bottom edge sits cardRadius below the bar's bottom
            // edge once fully expanded (that distance is the tuck), and
            // rises toward the bar as the card collapses — so the roll's
            // depth is the card's height past its tucked strip, minus
            // whatever the card's own bottom corner is rounding off,
            // clamped to the card's corner radius. The roll's tip then
            // lands exactly where the card's corner arc begins at every
            // height, and both curves are tangent-vertical there: the
            // junction reads as one smooth S instead of a roll that
            // stops short of the corner or overshoots it. No window
            // where the corner is bare, and no tab hanging off the bar
            // with the card short of it.
            var over = cardClip.height - root.cardRadius
            var rb = Math.min(root.cardRadius, Math.max(0, over / 2))
            // the card's painted corner radius is rb scaled by the pop,
            // so the roll's tip lands where that arc begins
            var fr = Math.max(0, Math.min(root.cardRadius, over - rb * root.pop))

            if (fr > 0.5) {
                // the rolls, one fillet per card edge. Traversing the
                // bottom edge right-to-left, each detour dives down
                // around the added material and comes back up along the
                // card's edge, which the roll shares. The visible
                // boundary is smooth at both ends: each arc is tangent
                // to the bottom edge where it leaves it and tangent to
                // the card's edge where it lands, and the corner where
                // the detour rejoins the bottom edge is interior — the
                // card's material fills it. Mid-pop the fillet is just
                // a smaller version of the same curve.
                var cw = root.cardWidth * root.pop                    // card's popped width
                var nx = (w - cw) / 2                                 // card's left edge
                var cx = nx + cw                                      // card's right edge

                // right roll: bottom edge -> outer curve down -> card's edge back up
                ctx.lineTo(cx + fr, bh)                               // bottom edge, to the roll's start
                ctx.arc(cx + fr, bh + fr, fr, -Math.PI / 2, -Math.PI, true) // roll down to the card's edge
                ctx.lineTo(cx, bh)                                    // back up along the card's edge

                // left roll: mirrored — down the card's edge, then the
                // outer curve back up to the bottom edge
                ctx.lineTo(nx, bh)                                    // bottom edge, to the card's edge
                ctx.lineTo(nx, bh + fr)                               // down along the card's edge
                ctx.arc(nx - fr, bh + fr, fr, 0, -Math.PI / 2, true)  // roll back up to the bottom edge
            }

            ctx.lineTo(r, bh)                                          // rest of the bottom edge
            ctx.arc(r, r, r, Math.PI / 2, Math.PI, false)              // left cap, bottom
            ctx.arc(r, r, r, Math.PI, 3 * Math.PI / 2, false)          // left cap, top
            ctx.closePath()
            ctx.fill()
        }

        // ---- top band: the bar itself ------------------------------------
        // The bar is just this 40px strip — everything always-visible
        // lives here, and nothing about the island ever changes it.
        Item {
            id: topBand
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.barHeight

            // ---- left: // + now playing + workspaces ------------------------
            Row {
                id: leftRow
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                // decorative prefix — visual only. This used to be the
                // TEMPORARY dark-mode toggle: a click flipped the fixed
                // palette. The island's Theme page owns that now and
                // Theme.darkMode is readonly, so a click here would
                // throw; the glyph stays because the bar's left row
                // reads better with it.
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: ""
                    color: Theme.barForeground
                    font.family: Theme.barFontFamily
                    font.pixelSize: Theme.barFontSize
                }

                // ---- now playing: circular art + scrolling "Artist - Song" ---
                // Always visible — shows a dim "Not playing" when no player has a
                // track, so the left zone keeps a stable shape.
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    height: 26
                    width: artCircle.width + 10 + mediaScroll.width

                    // same square-corner trap as the card's art: a
                    // Rectangle's clip does not round its children, and
                    // OpacityMask did not clip either — so the circular
                    // art is a Canvas with an arc clip here too
                    Item {
                        id: artCircle
                        width: 22
                        height: 22
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: Theme.barHighlight
                        }

                        Canvas {
                            id: barArtDisc
                            anchors.fill: parent

                            property url artSource: Media.artUrl
                            onArtSourceChanged: {
                                if (artSource.toString().length > 0) {
                                    barArtDisc.loadImage(artSource)
                                    // same trap as the card's disc: repaint
                                    // on the URL change, not only on
                                    // imageLoaded — loadImage never re-fires
                                    // imageLoaded for an already-loaded URL,
                                    // so prev would leave stale art on screen
                                    barArtDisc.requestPaint()
                                } else {
                                    requestPaint()
                                }
                            }
                            Component.onCompleted: if (artSource.toString().length > 0) loadImage(artSource)
                            onImageLoaded: requestPaint()

                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                if (artSource.toString().length === 0)
                                    return
                                ctx.save()
                                ctx.beginPath()
                                ctx.arc(width / 2, height / 2, width / 2, 0, 2 * Math.PI)
                                ctx.clip()
                                ctx.drawImage(artSource, 0, 0, width, height)
                                ctx.restore()
                            }
                        }
                    }

                    // marquee window: clips the text and scrolls it whenever the
                    // full "Artist - Song" string is wider than the window, so
                    // nothing is permanently cut off. The scroll is infinite:
                    // the text renders as repeated copies, which makes the
                    // content periodic, so the loop wraps with no visible
                    // reset and never runs out of string.
                    Item {
                        id: mediaScroll
                        anchors.left: artCircle.right
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 180
                        height: mediaText.implicitHeight
                        clip: true

                        // the raw string, before any repetition
                        property string baseText: {
                            if (!Media.hasPlayer)
                                return "Not playing"
                            var a = (Media.artist || "").trim()
                            var t = (Media.title || "").trim()
                            if (a && t)
                                return a + " - " + t
                            return a || t || "Not playing"
                        }

                        // gap between copies while scrolling
                        property string separator: "  •  "

                        // measured from the same strings the text renders
                        // from, so the period is exact
                        property real baseWidth: baseMetrics.width
                        property real unitWidth: unitMetrics.width

                        property real overflow: Math.max(0, baseWidth - width)
                        property bool needsScroll: overflow > 1

                        // scroll distance that brings the string's tail to
                        // the window's right edge — the first leg of every
                        // loop. Clamped so the animation's duration never
                        // goes negative while the string fits and the
                        // animation sits idle.
                        property real tailScroll: Math.max(0, baseWidth - width)

                        onNeedsScrollChanged: if (!needsScroll) mediaText.x = 0

                        TextMetrics {
                            id: baseMetrics
                            font: mediaText.font
                            text: mediaScroll.baseText
                        }

                        TextMetrics {
                            id: unitMetrics
                            font: mediaText.font
                            text: mediaScroll.baseText + mediaScroll.separator
                        }

                        Text {
                            id: mediaText
                            anchors.verticalCenter: parent.verticalCenter
                            // three copies separated by the gap — enough that
                            // the window never runs out of string (the loop
                            // only ever scrolls within one period), and the
                            // repetition is what makes the wrap invisible.
                            // A single static copy when it fits.
                            text: mediaScroll.needsScroll
                                ? mediaScroll.baseText + mediaScroll.separator + mediaScroll.baseText + mediaScroll.separator + mediaScroll.baseText
                                : mediaScroll.baseText
                            color: Media.hasPlayer ? Theme.barForeground : Theme.barDim
                            font.family: Theme.barFontFamily
                            font.pixelSize: Theme.barFontSize
                            width: implicitWidth

                            onTextChanged: {
                                mediaText.x = 0
                                if (mediaScroll.needsScroll)
                                    scrollAnim.restart()
                            }
                        }

                        // infinite right-to-left scroll, one hold — at the
                        // tail. Each loop is exactly one period (unitWidth):
                        //   1. scroll until the string's tail reaches the
                        //      window's right edge, so the whole "Artist -
                        //      Song" has passed through, and hold there;
                        //   2. scroll the rest of the period — the tail
                        //      exits left, the gap flows through, and the
                        //      next copy's head arrives at the left edge.
                        // The loop's `from: 0` then snaps x back to the top,
                        // invisibly: the content one period over is
                        // identical, so the snap lands on the same picture.
                        // No return leg and no hold at the top — the only
                        // stillness is at the tail.
                        SequentialAnimation {
                            id: scrollAnim
                            running: mediaScroll.needsScroll
                            loops: Animation.Infinite
                            NumberAnimation {
                                target: mediaText
                                property: "x"
                                from: 0
                                to: -mediaScroll.tailScroll
                                duration: mediaScroll.tailScroll * 30
                            }
                            PauseAnimation { duration: 1600 }
                            NumberAnimation {
                                target: mediaText
                                property: "x"
                                from: -mediaScroll.tailScroll
                                to: -mediaScroll.unitWidth
                                duration: (mediaScroll.unitWidth - mediaScroll.tailScroll) * 30
                            }
                        }
                    }

                    // click toggles playback, wheel skips — waybar's media bindings
                    MouseArea {
                        anchors.fill: parent
                        onClicked: Media.toggle()
                        onWheel: function (wheel) {
                            if (wheel.angleDelta.y > 0)
                                Media.next()
                            else
                                Media.previous()
                        }
                    }
                }

                // ---- workspaces: pill with circular buttons ------------------
                // The pill flips with the palette — near-black ink in dark
                // mode, light gray in light mode. The active circle takes
                // barBackground (a shade lighter than the ink in dark mode,
                // white in light mode) with a barForeground number, so the
                // button reads in both palettes.
                Rectangle {
                    id: workspacePill
                    anchors.verticalCenter: parent.verticalCenter
                    height: root.workspacePillHeight
                    radius: height / 2
                    color: Theme.barWorkspacePill
                    width: workspaceRow.implicitWidth + 8

                    Row {
                        id: workspaceRow
                        anchors.centerIn: parent
                        spacing: 4

                        Repeater {
                            model: root.workspaces
                            Rectangle {
                                required property var modelData
                                implicitWidth: root.workspaceCircleSize
                                implicitHeight: root.workspaceCircleSize
                                radius: implicitWidth / 2
                                color: modelData.active ? Theme.barBackground : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.id
                                    color: modelData.active ? Theme.barForeground : Theme.barWorkspaceDim
                                    font.family: Theme.barFontFamily
                                    font.pixelSize: Theme.barFontSizeSmall
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.activateWorkspace(modelData.id)
                                }
                            }
                        }
                    }
                }
            }

            // ---- center: clock ------------------------------------------------
            // Flows between the two groups rather than pinned to the
            // pill's center: centered while the left row is short,
            // sliding right once the workspace pill grows into it (at
            // ten workspaces the pill ends ~x530 and a centered clock
            // would start ~x430 — a 100px overlap), and never past the
            // right row. Up to ~7 workspaces this is the exact same
            // centered position as before.
            Text {
                id: clockText
                x: Math.min(Math.max(parent.width / 2 - width / 2,
                                     root.workspaceRight + 16),
                            rightRow.x - width - 16)
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(clock.date, "ddd, MMM d  hh:mm")
                color: Theme.barForeground
                font.family: Theme.barFontFamily
                font.pixelSize: Theme.barFontSize
            }

            // ---- right: tray, network, volume, battery --------------------
            Row {
                id: rightRow
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                // tray — all SNI icons in ONE pill, cut from the same
                // cloth as the workspace pill: same barWorkspacePill
                // surface, same height and height/2 radius, same 4px side
                // padding. Icons ride in their own brand colors; left-click
                // activates, right-click opens the item's menu. Hidden when
                // nothing registers, so the row stays compact on a clean
                // session.
                Rectangle {
                    id: trayPill
                    anchors.verticalCenter: parent.verticalCenter
                    height: root.workspacePillHeight
                    radius: height / 2
                    color: Theme.barWorkspacePill
                    width: trayRow.implicitWidth + 8
                    visible: trayRow.implicitWidth > 0

                    Row {
                        id: trayRow
                        anchors.centerIn: parent
                        spacing: 8

                        Repeater {
                            model: SystemTray.items
                            Image {
                                width: 20
                                height: 20
                                sourceSize: Qt.size(20, 20)
                                source: modelData.icon
                                fillMode: Image.PreserveAspectFit

                                // the MouseArea stays on the icon: mouse.x/y
                                // feed modelData.display() and must keep the
                                // icon-relative origin
                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: function (mouse) {
                                        if (mouse.button === Qt.RightButton)
                                            modelData.display(root, mouse.x, mouse.y)
                                        else
                                            modelData.activate()
                                    }
                                }
                            }
                        }
                    }
                }

                // network — icon only, no SSID; click opens impala
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        if (!Network.connected)
                            return "\uF05E"                        // ban
                        return Network.kind === "wifi" ? "\uF1EB" : "\uF0AC" // wifi / globe
                    }
                    color: Network.connected ? Theme.barForeground : Theme.barDim
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.barFontSize

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.launch(["kitty", "-e", "impala"])
                    }
                }

                // volume — icon only; hover opens the island's app-volume
                // page, click still opens pavucontrol for the full mixer,
                // wheel adjusts the master
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Audio.muted ? "\uF026" : (Audio.volume < 0.5 ? "\uF027" : "\uF028")
                    color: Audio.muted ? Theme.barDim : Theme.barForeground
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.barFontSize

                    MouseArea {
                        id: volumeIcon
                        anchors.fill: parent
                        hoverEnabled: true
                        onContainsMouseChanged: if (containsMouse) root.islandPage = "volume"
                        onClicked: root.launch(["pavucontrol"])
                        onWheel: function (wheel) {
                            Audio.nudge(wheel.angleDelta.y > 0 ? 0.05 : -0.05)
                        }
                    }
                }

                // battery — icon only; a tiered cell at every level,
                // charging included. The bolt swap is gone: the tier
                // already reads as the level, and a bolt told you
                // nothing the tier did not.
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        if (!Battery.present)
                            return ""
                        var p = Battery.percentage
                        if (p > 0.75) return "\uF240"
                        if (p > 0.5)  return "\uF241"
                        if (p > 0.25) return "\uF242"
                        if (p > 0.10) return "\uF243"
                        return "\uF244"
                    }
                    color: !Battery.present ? Theme.barDim : (Battery.charging || Battery.percentage > 0.15 ? Theme.barForeground : Theme.barUrgent)
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.barFontSize
                }
            }
        }

        // ---- hover: the clock ----------------------------------------------
        // Opens the island. Follows the clock text and is bounded by
        // both groups: its left edge clears the workspace pill's right
        // edge (the old fixed 320px zone centered in the pill reached
        // back over the workspace pill — at ten workspaces it covered
        // two circles' worth of dead clicks, and even at four it ate
        // the last circle's right sliver) and its right edge clears
        // the status readouts, so those stay clickable whether the
        // island is open or not. The zone shrinks toward a 160px floor
        // when the gap between the groups tightens; the clock text
        // always fits inside it.
        MouseArea {
            id: clockZone
            x: Math.min(Math.max(clockText.x + clockText.width / 2 - width / 2,
                                 root.workspaceRight + 8),
                        rightRow.x - width - 8)
            anchors.top: parent.top
            width: Math.max(160, Math.min(320, rightRow.x - root.workspaceRight - 16))
            height: root.barHeight
            hoverEnabled: true
            onContainsMouseChanged: if (containsMouse) root.islandPage = "media"
        }


    }
}
