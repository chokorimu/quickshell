// Bar.qml — floating pill top bar with a dynamic island.
//   left:   "//" + now playing (circular art, scrolling "Artist - Song") + workspaces
//   center: clock — hover it and a media card pops open from the top center
//   right:  tray, network, volume, battery
//
// The window reserves the pill's band via exclusiveZone in shell.qml, so
// windows are pushed down while the pill still floats centered inside it.
// The card pops open past that band, which is why the window is taller
// than the reservation and carries an input mask tracking both the pill
// and the card: without the mask the transparent area around them would
// swallow every click meant for the windows underneath.
import QtQml
import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray
import "../../Theme"
import "../../Services"

Item {
    id: root

    // load-bearing: as a child of the PanelWindow, this Item does not get
    // resized to fill the window's content item on its own. Without this the
    // root is 0x0 and the pill's horizontalCenter anchor centers against
    // nothing, parking half the pill off the left edge.
    anchors.fill: parent

    readonly property int barHeight: 36
    readonly property int topMargin: 8
    readonly property int barWidth: 1200
    // the card is 4:3 at half the bar's width — 600x450
    readonly property int cardWidth: 600
    readonly property int cardHeight: 400
    readonly property int cardRadius: 24
    // the menu column's strip down the card's left edge — the tab
    // buttons' own region (40 wide, flush at the card's edge), painted
    // in the bar's color against the darker card body (see the card
    // canvas). The page content clears it with its left margins.
    readonly property int cardColumnWidth: 56
    readonly property int workspacePillHeight: 30
    readonly property int workspaceCircleSize: 22
    // the pop's overshoot headroom. OutBack peaks at ~1.1x, so the clip
    // runs wider than the card and the window runs taller than the card's
    // resting bottom — without both, the overshoot gets shaved off by the
    // clip's side edges and the window's bounds respectively.
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
    // Which menu the card shows: "media" (clock hover) or "volume"
    // (volume-icon hover). Resets to media whenever the island collapses,
    // so the clock always opens the media page fresh. Derived hover keeps
    // the card open while the cursor is over it regardless of page —
    // including on the tab buttons, which take hover events of their
    // own (they switch pages on enter) and so are OR'd in here directly
    // rather than relying on hover falling through to cardZone.
    property string islandPage: "media"

    property bool hovered: cardZone.containsMouse
        || mediaTab.containsMouse
        || volumeTab.containsMouse
        || sessionTab.containsMouse
        || (islandPage === "media" && clockZone.containsMouse)
        || (islandPage === "volume" && volumeIcon.containsMouse)

    readonly property bool expanded: hovered || collapseGrace.running

    onHoveredChanged: {
        if (hovered)
            collapseGrace.stop()
        else
            collapseGrace.restart()
    }

    Timer {
        id: collapseGrace
        interval: 350
        // a collapsed island always reopens on the media page, so the next
        // clock hover never inherits a stale volume menu
        onTriggered: root.islandPage = "media"
    }

    // The card pops open from the top center instead of swiping down: one
    // progress value drives the clip's height — and with it the window's
    // input mask and the pill's roll fillets — plus the card's own
    // horizontal scale, so the card grows outward from the top center,
    // height from the bar's bottom edge and width from the center line.
    // In with a slight overshoot for the pop; out faster and without one,
    // so the card never dips below zero (a negative scale would mirror it).
    property real pop: 0

    NumberAnimation {
        id: popIn
        target: root
        property: "pop"
        to: 1
        duration: 380
        easing.type: Easing.OutBack
    }

    NumberAnimation {
        id: popOut
        target: root
        property: "pop"
        to: 0
        duration: 240
        easing.type: Easing.OutCubic
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

            Connections {
                target: cardClip
                function onHeightChanged() { card.requestPaint() }
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
                ctx.fillRect(0, 0, root.cardColumnWidth, h)
                ctx.restore()
            }

            // the content lives in the visible band below the tucked strip
            Item {
                anchors.top: parent.top
                anchors.topMargin: root.cardRadius
                width: parent.width
                height: root.cardHeight
                enabled: root.expanded

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

                // ---- session page: avatar, user@host, power grid --------
                // Same card, same pop — reached by hovering the third
                // tab button in the column. Gated on the page like the
                // other two, so nothing paints underneath.
                SessionCard {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    visible: root.islandPage === "session"
                }

                // ---- page switcher: vertical tab column --------------------
                // Three buttons down the card's left edge, flush against
                // the card's edge and each other (no margin, no gaps) and
                // as wide as the column strip itself, so the block fills
                // the strip edge to edge with no dead space beside it.
                // The selected page takes the accent fill — square
                // corners, near-black glyph, and a black block down its
                // left edge taking the full height and the left 10% of
                // the button — so it reads as one solid lime slab; the
                // unselected one stays transparent. Hovering a button
                // switches pages outright — no click needed; the bar's
                // hover triggers (clock, volume icon) still select a
                // page on the way in. The block fills the 56px strip;
                // the pages' content keeps an 80px left margin to clear
                // it with 24px to spare.
                Column {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.topMargin: 28
                    anchors.leftMargin: 0
                    spacing: 0

                    Rectangle {
                        width: root.cardColumnWidth
                        height: 40
                        color: root.islandPage === "media" ? Theme.cardAccent : "transparent"

                        // the selected marker: a black block down the
                        // button's left edge, taking the full height
                        // and the left 10% of the width — no inset, so
                        // it reads as part of the button's silhouette
                        Rectangle {
                            x: 0
                            width: parent.width * 0.1
                            height: parent.height
                            color: "black"
                            visible: root.islandPage === "media"
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "\uF001" // music note
                            color: root.islandPage === "media" ? Theme.cardAccentOn : Theme.barDim
                            font.family: Theme.iconFont
                            font.pixelSize: 17
                        }

                        MouseArea {
                            id: mediaTab
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: root.islandPage = "media"
                        }
                    }

                    Rectangle {
                        width: root.cardColumnWidth
                        height: 40
                        color: root.islandPage === "volume" ? Theme.cardAccent : "transparent"

                        // the selected marker: a black block down the
                        // button's left edge, taking the full height
                        // and the left 10% of the width — no inset, so
                        // it reads as part of the button's silhouette
                        Rectangle {
                            x: 0
                            width: parent.width * 0.1
                            height: parent.height
                            color: "black"
                            visible: root.islandPage === "volume"
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "\uF028" // speaker
                            color: root.islandPage === "volume" ? Theme.cardAccentOn : Theme.barDim
                            font.family: Theme.iconFont
                            font.pixelSize: 17
                        }

                        MouseArea {
                            id: volumeTab
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: root.islandPage = "volume"
                        }
                    }

                    Rectangle {
                        width: root.cardColumnWidth
                        height: 40
                        color: root.islandPage === "session" ? Theme.cardAccent : "transparent"

                        // the selected marker: a black block down the
                        // button's left edge, taking the full height
                        // and the left 10% of the width — no inset, so
                        // it reads as part of the button's silhouette
                        Rectangle {
                            x: 0
                            width: parent.width * 0.1
                            height: parent.height
                            color: "black"
                            visible: root.islandPage === "session"
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "\uF08B" // sign-out
                            color: root.islandPage === "session" ? Theme.cardAccentOn : Theme.barDim
                            font.family: Theme.iconFont
                            font.pixelSize: 17
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
                Rectangle {
                    id: bigArt
                    anchors.horizontalCenter: parent.horizontalCenter
                    // center in the content area, not the full card —
                    // the column strip owns the left edge
                    anchors.horizontalCenterOffset: root.cardColumnWidth / 2
                    anchors.top: parent.top
                    anchors.topMargin: 28
                    visible: root.islandPage === "media"
                    width: 200
                    height: 200
                    radius: width / 2
                    color: Theme.cardHighlight
                    clip: true

                    Image {
                        anchors.fill: parent
                        sourceSize: Qt.size(200, 200)
                        fillMode: Image.PreserveAspectCrop
                        source: Media.artUrl
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

                // title / artist under the art, centered — elided so a long
                // name can't push the controls off the card
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

                // transport controls — light circles on the dark card, the
                // inverted language of the card's own palette, pinned to
                // the bottom of the card
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: root.cardColumnWidth / 2
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 28
                    spacing: 24
                    visible: root.islandPage === "media"

                    Rectangle {
                        width: 48
                        height: 48
                        radius: width / 2
                        color: Theme.cardInk

                        Text {
                            anchors.centerIn: parent
                            text: "prev"
                            color: Theme.cardOnInk
                            font.family: Theme.barFontFamily
                            font.pixelSize: 12
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: Media.previous()
                        }
                    }

                    Rectangle {
                        width: 60
                        height: 60
                        radius: width / 2
                        color: Theme.cardInk

                        Text {
                            anchors.centerIn: parent
                            text: Media.playing ? "pause" : "play"
                            color: Theme.cardOnInk
                            font.family: Theme.barFontFamily
                            font.pixelSize: 14
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: Media.toggle()
                        }
                    }

                    Rectangle {
                        width: 48
                        height: 48
                        radius: width / 2
                        color: Theme.cardInk

                        Text {
                            anchors.centerIn: parent
                            text: "next"
                            color: Theme.cardOnInk
                            font.family: Theme.barFontFamily
                            font.pixelSize: 12
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

    // ---- the pill -------------------------------------------------------
    // The bar never moves: it stays 1200x36 forever. The island is the
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
        // The bar is just this 36px strip — everything always-visible
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

                // decorative prefix — TEMPORARY dark-mode toggle (moves to
                // a menu later): click flips the bar between the fixed
                // light and fixed dark palettes
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "//"
                    color: Theme.barForeground
                    font.family: Theme.barFontFamily
                    font.pixelSize: Theme.barFontSize

                    MouseArea {
                        anchors.fill: parent
                        onClicked: Theme.darkMode = !Theme.darkMode
                    }
                }

                // ---- now playing: circular art + scrolling "Artist - Song" ---
                // Always visible — shows a dim "Not playing" when no player has a
                // track, so the left zone keeps a stable shape.
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    height: 26
                    width: artCircle.width + 10 + mediaScroll.width

                    Rectangle {
                        id: artCircle
                        width: 22
                        height: 22
                        anchors.verticalCenter: parent.verticalCenter
                        radius: width / 2
                        color: Theme.barHighlight
                        clip: true

                        Image {
                            anchors.fill: parent
                            sourceSize: Qt.size(22, 22)
                            fillMode: Image.PreserveAspectCrop
                            source: Media.artUrl
                        }
                    }

                    // marquee window: clips the text and scrolls it whenever the
                    // full "Artist - Song" string is wider than the window, so
                    // nothing is permanently cut off
                    Item {
                        id: mediaScroll
                        anchors.left: artCircle.right
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 180
                        height: mediaText.implicitHeight
                        clip: true

                        property real overflow: Math.max(0, mediaText.implicitWidth - width)
                        property bool needsScroll: overflow > 1

                        onNeedsScrollChanged: if (!needsScroll) mediaText.x = 0

                        Text {
                            id: mediaText
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                if (!Media.hasPlayer)
                                    return "Not playing"
                                var a = (Media.artist || "").trim()
                                var t = (Media.title || "").trim()
                                if (a && t)
                                    return a + " - " + t
                                return a || t || "Not playing"
                            }
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

                        SequentialAnimation {
                            id: scrollAnim
                            running: mediaScroll.needsScroll
                            loops: Animation.Infinite
                            NumberAnimation {
                                target: mediaText
                                property: "x"
                                from: 0
                                to: -mediaScroll.overflow
                                duration: mediaScroll.overflow * 30
                            }
                            PauseAnimation { duration: 1600 }
                            NumberAnimation {
                                target: mediaText
                                property: "x"
                                from: -mediaScroll.overflow
                                to: 0
                                duration: mediaScroll.overflow * 30
                            }
                            PauseAnimation { duration: 1600 }
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
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
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

                // tray — SNI icons tinted to the bar ink; left-click
                // activates, right-click opens the item's menu. Empty when
                // nothing registers, so the row stays compact on a clean
                // session.
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Repeater {
                        model: SystemTray.items
                        Image {
                            width: 20
                            height: 20
                            sourceSize: Qt.size(20, 20)
                            source: modelData.icon
                            fillMode: Image.PreserveAspectFit
                            // tint to the bar's ink so brand-colored icons
                            // match the monochrome status glyphs; the derived
                            // property flips with darkMode/matugen for free
                            layer.enabled: true
                            layer.effect: ColorOverlay {
                                color: Theme.barForeground
                            }

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

                // battery — icon only; bolt while charging, otherwise a
                // tiered cell
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        if (!Battery.present)
                            return ""
                        if (Battery.charging)
                            return "\uF0E7"                        // bolt
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
        // Opens the island. Narrow enough that it never reaches the workspace
        // pill on the left or the status readouts on the right, so those stay
        // clickable whether the island is open or not.
        MouseArea {
            id: clockZone
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: 320
            height: root.barHeight
            hoverEnabled: true
            onContainsMouseChanged: if (containsMouse) root.islandPage = "media"
        }


    }
}
