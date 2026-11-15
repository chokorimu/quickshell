// TrayMenu.qml — a status-notifier menu rendered in the shell's own language.
//
// Replaces the platform menu that `SystemTrayItem.display()` opens: that
// path renders Qt's native menu at the cursor, unstyled and outside the
// bar's palette, and it only works because shell.qml carries
// `//@ pragma UseQApplication`. This reads the same dbusmenu tree through
// Quickshell's QsMenuOpener instead, so the menu is a normal QML item on
// the island card's surface and follows darkMode like everything else.
//
// The tree arrives pre-loaded: DBusMenuHandle calls
// setShowChildrenRecursive(true) when it creates the menu, so every level's
// children are present the moment the opener binds. That is what lets a
// submenu be a plain child of this component rather than an async fetch.
//
// One instance renders one level. A level whose rows haveChildren hosts
// exactly ONE nested TrayMenu for the submenu currently open, positioned to
// the left of the plate (the tray sits near the screen's right edge, so a
// submenu opening right would run off it).
//
// The plate opens with the island card's pop: one 0 -> 1 progress drives a
// clip's height (revealing the plate downward from the bar's bottom edge) and
// the plate's horizontal scale about its top centre (widening it from its own
// middle), on the card's two curves — 300ms tamed bezier in, 200ms OutCubic
// out. Only the root level does this; a submenu is hover-driven and appears at
// full size so it never lags the pointer.
//
// The nesting goes through a Loader, not a direct `TrayMenu {}` child:
// QML refuses a component instantiating itself ("TrayMenu is instantiated
// recursively"), and the two-file indirection that usually gets around that
// is caught too ("Cyclic dependency detected"). `source:` is a runtime URL
// the dependency scanner never follows, so the Loader route loads — with
// one condition that cost a probe: the loaded instance must NOT start
// loading its own child during construction. `openEntry` defaults to null,
// the Loader's `active` is `openEntry !== null`, so a freshly loaded level
// sits inert until `onLoaded` hands it its handle and host. Without that
// gate the level is born with `openEntry === null`... which is exactly the
// inert state, so the gate holds by construction rather than by a sentinel.
// (Probed: a self-loading component with an unset property sentinel recurses
// forever and hangs the shell before any log line; with the property default
// inert it terminates at the intended depth.)
import QtQml
import QtQuick
import Quickshell
import "../../Theme"

Item {
    id: root

    // the QsMenuHandle for this level: SystemTrayItem.menu at the root, the
    // parent entry (itself a menu handle) for a submenu
    property var menuHandle: null

    // the TrayMenu hosting this one, null at the root. hostRoot is what a
    // row calls to dismiss the whole chain — a submenu three levels deep
    // still closes the root, which owns the visible state.
    property var host: null
    readonly property var hostRoot: host ? host.hostRoot : root

    // emitted by the root when a row is clicked; Bar.qml drops the target
    signal closeRequested()

    // the entry whose submenu is showing at THIS level
    property var openEntry: null
    // that entry's row top, in this level's coordinates — taken from the
    // delegate rather than recomputed, because separators are 9px tall and
    // an index * rowHeight guess drifts as soon as one is present
    property real openRowY: 0

    // ---- metrics ---------------------------------------------------------
    readonly property int rowHeight: 28
    // A separator is not a row: it is a hairline in a 9px band, and the plate
    // height has to add these rather than count rows (see contentHeight).
    readonly property int separatorHeight: 9
    readonly property int padH: 10
    // Reserved on every row so the labels line up whether or not a given row
    // carries the decoration — the control-centre tiles' ink-width lesson,
    // at row scale. A Nerd Font glyph's Text width follows its ink, not its
    // advance, so an unpinned slot drags its neighbour's anchor.
    readonly property int checkSlot: anyCheckable ? 16 : 0
    readonly property int iconSlot: anyIcon ? 22 : 0
    readonly property int chevronSlot: anyChildren ? 18 : 0
    // One width for every level of every menu. It used to be measured off the
    // real strings in the real font (a hidden Repeater of Texts read through
    // childrenRect, exact where a length guess truncates a proportional
    // font) — but a measured width makes every app's menu a different box, and
    // switching tray icons then jumps the plate's left edge around. A fixed
    // width is the steady version of the same panel; a label that overruns it
    // elides, which is what the rows' elide was always there for.
    readonly property int menuWidth: 240
    // The bar window is ~507 tall and the menu hangs from the bar's bottom
    // edge, so a long menu is capped and scrolls rather than running past
    // the window's bounds and being clipped by them.
    readonly property int maxHeight: 420
    readonly property int plateRadius: 10

    // ---- the menu tree ---------------------------------------------------
    // Reads liveHandle, not menuHandle: the latched handle is what keeps the
    // tree in the opener through the pop-out (see liveHandle below).
    QsMenuOpener {
        id: opener
        menu: root.liveHandle
    }

    // `children` is a QAbstractListModel with a single `modelData` role, so
    // it feeds a Repeater directly. `.values` is the same content as a JS
    // array, which is what the flags below and the width measurement read —
    // a binding on model[i] would never update, .values re-notifies whole.
    readonly property var entries: opener.children ? opener.children.values : []

    // QsMenuButtonType: None = 0, CheckBox = 1, RadioButton = 2. Compared as
    // numbers rather than through the enum: the singleton is there, but the
    // digits are what the typeinfo guarantees.
    readonly property bool anyCheckable: {
        for (var i = 0; i < entries.length; i++) {
            var e = entries[i]
            if (e && !e.isSeparator && e.buttonType !== 0)
                return true
        }
        return false
    }
    readonly property bool anyIcon: {
        for (var i = 0; i < entries.length; i++) {
            var e = entries[i]
            if (e && !e.isSeparator && (e.icon || "").length > 0)
                return true
        }
        return false
    }
    readonly property bool anyChildren: {
        for (var i = 0; i < entries.length; i++) {
            var e = entries[i]
            if (e && !e.isSeparator && e.hasChildren)
                return true
        }
        return false
    }

    // ---- geometry --------------------------------------------------------
    // Fixed width (menuWidth above), content-driven height. Nothing here is
    // measured any more: the plate is one panel, so its size never depends on
    // which tree is showing.

    readonly property int rowCount: entries.length
    // Summed, not count * rowHeight: a separator is 9px against a row's 28, and
    // Discord's menu carries three of them — a count-based height left 57px of
    // empty plate below the last row (measured). This also has to be the sum
    // the delegate actually renders, or the ListView's content and the plate
    // disagree and a long menu's scroll range is wrong too.
    readonly property int contentHeight: {
        var h = 0
        for (var i = 0; i < entries.length; i++) {
            var e = entries[i]
            h += (e && e.isSeparator) ? separatorHeight : rowHeight
        }
        return h
    }
    readonly property int plateHeight: Math.min(contentHeight, maxHeight)

    // How much of the plate the clip has revealed — the plate's own visible
    // height, which is what the corner and fillet radii have to fit inside.
    readonly property real visibleHeight: plateHeight * reveal
    // The fillet that blends the plate's side edges into the bar's bottom
    // edge: the island pill's rolls at menu scale. Material-growing, not a
    // bite — the bar's own surface flows down into the plate's edges, so the
    // junction reads as one piece instead of a panel butted against a bar.
    //
    // Its depth tracks the reveal the way the plate's bottom corners do
    // (`over`/`rb`, the card's own formula), so a plate still growing out of
    // the bar has a smaller fillet and none at all while it is shorter than a
    // corner radius — otherwise the fillet would hang below the plate's
    // bottom edge and read as a blob rather than a junction.
    readonly property real filletRadius: {
        var over = visibleHeight - plateRadius
        var rb = Math.min(plateRadius, Math.max(0, over / 2))
        return Math.max(0, Math.min(plateRadius, over - rb * reveal))
    }

    implicitWidth: menuWidth
    implicitHeight: plateHeight
    width: implicitWidth
    height: implicitHeight
    // Visible on the handle the plate is rendering (liveHandle), not on the
    // live one: the pop-out needs a tree to shrink, and Bar.qml drops the
    // target the instant a row is clicked — which nulls menuHandle and would
    // empty the opener out from under the animation.
    visible: liveHandle !== null && rowCount > 0

    // a level that goes away must not reopen on the submenu it had showing
    onVisibleChanged: if (!visible) {
        openEntry = null
        hoverIndex = -1
    }

    // ---- the pointer -----------------------------------------------------
    // The index of the row under the cursor, or -1, reported up by the row
    // delegates. A delegate is exactly as wide as the plate and the rows tile
    // it (separators included — their MouseArea fills the whole delegate), so
    // "some row is hovered" IS "the cursor is on the plate". The alternative
    // was a plate-sized hover area of this level's own, and neither stacking
    // works: a hover-enabled area above the rows steals their hover (the
    // topmost accepting area wins, which would kill the submenu-on-hover and
    // the row fill), and one below them is never reached, because a hovered
    // MouseArea accepts the event and stops delivery to its ancestors.
    property int hoverIndex: -1
    // The cursor is on this level's plate, or on a submenu hanging off it.
    // What Bar.qml's leave-grace rides: a menu that stays up after the cursor
    // has gone reads as a stuck window.
    readonly property bool pointerInside: hoverIndex >= 0
        || (submenu.item !== null && submenu.item.pointerInside)
    // a tree swap while the plate stays up would otherwise carry the old
    // tree's row index over and read as "cursor inside" forever
    onLiveHandleChanged: hoverIndex = -1

    // ---- the pop ---------------------------------------------------------
    // The island card's pop, at menu scale: one 0 -> 1 progress drives the
    // clip's height and the plate's horizontal scale together, so the menu is
    // revealed downward from the bar's bottom edge while it widens from its
    // own centre line. Same curve, same two durations — the card's motion,
    // hung under the tray icon instead of the bar's centre.
    property real pop: 0
    // The island's headroom (Bar.qml's popOvershoot): the pop-in overshoots
    // ~1.02x, and a clip exactly the plate's width would shave that square.
    readonly property real popOvershoot: 1.12
    // Only the root level pops. A submenu is hover-driven and has to track the
    // row the cursor is on, so a 300ms growth would leave it lagging behind
    // the pointer; it appears at full size the moment its row is hovered, the
    // way it always has.
    readonly property bool popEnabled: host === null
    // What the geometry below actually reads. `pop` is the animation's alone
    // and stays 0 on a level that never animates, so a submenu would build
    // itself with a zero-height clip if the plate used it directly. Every
    // level is fully revealed except the root mid-pop.
    readonly property real reveal: root.popEnabled ? root.pop : 1
    // The handle the plate is rendering — the last non-null menuHandle. The
    // tray item owns the handle, so a latched reference costs nothing and
    // keeps the model alive through the shrink; it is released once the
    // plate has retracted.
    property var liveHandle: null

    onMenuHandleChanged: {
        if (menuHandle !== null) {
            liveHandle = menuHandle
            if (popEnabled) {
                popOut.stop()
                popIn.start()
            }
        } else if (popEnabled) {
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
        // the island's tamed back-ease (see Bar.qml): a flat bezier list in
        // Qt 6 — c1x, c1y, c2x, c2y, endX, endY — peaking at ~1.02x rather
        // than OutBack's 1.1x spring
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
        // Release the latched handle once the plate has retracted. Guarded on
        // menuHandle so a reopen mid-shrink — which stops this animation and
        // starts popIn from wherever the pop had got to — keeps its tree.
        onStopped: if (root.menuHandle === null) root.liveHandle = null
    }

    // ---- the plate -------------------------------------------------------
    // The clip is the island's cardClip at menu scale: a little wider than the
    // plate for the overshoot, and only as tall as the pop has revealed.
    Item {
        id: clip
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.width * root.popOvershoot
        height: root.height * root.reveal
        clip: true

        // ---- the junction fillets ---------------------------------------
        // A sibling of the plate rather than part of its canvas: the fillets
        // live OUTSIDE the plate's side edges, and the plate's canvas is
        // exactly the plate's width — a Canvas clips its own paint to its own
        // bounds, so it could never reach them. This one is the clip's full
        // width (the plate plus the pop overshoot on either side) and only as
        // tall as the fillet is deep, so it paints nothing but the two
        // corners.
        //
        // It is NOT inside the plate's Scale: it reads `reveal` itself for the
        // plate's popped edges (`cw`/`nx`/`cx`, the pill's own arithmetic), so
        // it follows the widening without being transformed twice.
        Canvas {
            id: filletCanvas
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: clip.width
            height: Math.max(1, root.filletRadius)
            visible: root.filletRadius > 0.5
            // its height is the fillet's depth, so a change means a repaint —
            // same reason as the plate canvas below
            onHeightChanged: requestPaint()
            Connections {
                // reveal moves every frame of the pop, and the plate's edges
                // move with it — a Canvas repaints only on request
                target: root
                function onRevealChanged() { filletCanvas.requestPaint() }
            }
            Connections {
                // the fillets are bar material, so a matugen regeneration
                // underneath them needs a repaint too
                target: Theme
                function onBarBackgroundChanged() { filletCanvas.requestPaint() }
            }
            onPaint: {
                var ctx = getContext("2d")
                var w = width
                var fr = height
                // the plate's edges at this frame's reveal. The plate scales
                // about its centre, so these are the visible edges, not the
                // item's own.
                var cw = root.width * root.reveal
                var nx = (w - cw) / 2
                var cx = nx + cw
                ctx.clearRect(0, 0, w, height)
                ctx.fillStyle = Theme.barBackground
                ctx.beginPath()
                // Right fillet: out along the bar's bottom edge, then the
                // quarter arc down to the plate's edge, then back up it. The
                // arc is tangent to both — horizontal where it leaves the bar,
                // vertical where it lands on the plate — so the junction is
                // one smooth S with no corner and no gap. Same traversal as
                // the pill's right roll, at this canvas's origin.
                //
                // Both subpaths start 1px INSIDE the plate: two abutting
                // antialiased edges leave a hairline of the surface behind
                // them showing through the seam, and the plate paints over
                // the overlap (it is declared after this canvas), so the
                // extra pixel is free.
                ctx.moveTo(cx - 1, 0)
                ctx.lineTo(cx + fr, 0)
                ctx.arc(cx + fr, fr, fr, -Math.PI / 2, -Math.PI, true)
                ctx.closePath()
                // left fillet, mirrored
                ctx.moveTo(nx + 1, 0)
                ctx.lineTo(nx - fr, 0)
                ctx.arc(nx - fr, fr, fr, -Math.PI / 2, 0, false)
                ctx.closePath()
                ctx.fill()
            }
        }

        Item {
            id: plate
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: root.width
            height: root.height
            // the width half of the pop, origin top-centre — the card's own
            // Scale, so the plate widens from its centre line as it descends
            transform: Scale { origin.x: plate.width / 2; origin.y: 0; xScale: root.reveal }
            // The rows keep their full-size geometry while the clip cuts them
            // off, so nothing re-lays out mid-pop. Gated on the handle rather
            // than on the progress, the way the island card's content item is
            // gated on `expanded`: a menu that swallowed its first 300ms of
            // hover would read as broken, and the clip already cuts the
            // cut-away band out of hit-testing. During the pop-out the rows go
            // dead at once, which is right — the menu is closing.
            enabled: root.menuHandle !== null

            // A Canvas rather than a Rectangle, for the island card's reason:
            // the bottom corners are the reveal edge, and a fixed radius on a
            // band the clip has not finished opening reads as a clipped
            // square. Same formula at menu scale — full radius once the band
            // can hold one, a semicircular cap while it is shorter.
            //
            // The TOP corners are square, because the plate now sits flush on
            // the bar's bottom edge: a radius up there would notch two bites
            // out of the seam and the menu would read as a card hovering near
            // the bar rather than as something hanging off it. This is the
            // island card's own trick inverted — that card tucks its rounded
            // top corners behind the bar, and the launcher tucks its bottom
            // ones below the screen edge; the edge that meets a boundary is
            // the edge that must not curve.
            Canvas {
                id: plateCanvas
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                width: root.width
                height: clip.height

                // Its height IS the clip's, so this is one repaint per frame of
                // the pop — a Canvas repaints only on request. Handled on the
                // canvas itself rather than through a Connections on the clip:
                // the handler has to run AFTER the new height is applied, and
                // a request made while the canvas was still 0 tall is dropped,
                // leaving the previous tree's texture on the plate (probed by
                // swapping trees while open — the swap passes through a
                // 0-height frame, and only the canvas's own signal is
                // guaranteed to see the height that follows it).
                onHeightChanged: requestPaint()
                Connections {
                    // a matugen regeneration rewrites the fill underneath
                    target: Theme
                    function onCardBackgroundChanged() { plateCanvas.requestPaint() }
                }

                onPaint: {
                    var ctx = getContext("2d")
                    var w = width
                    var h = height
                    // square top corners: the plate's top edge is the bar's
                    // bottom edge (see the comment above), so the outline runs
                    // straight into it at both ends
                    var rt = 0
                    var rb = Math.min(root.plateRadius, Math.max(0, (h - root.plateRadius) / 2))
                    ctx.clearRect(0, 0, w, h)
                    ctx.fillStyle = Theme.cardBackground
                    ctx.beginPath()
                    // one clockwise outline, every arc starting where the path
                    // already stands (canvas inserts a straight connector
                    // otherwise and the curve collapses)
                    ctx.moveTo(rt, 0)
                    ctx.lineTo(w - rt, 0)
                    if (rt > 0.5)
                        ctx.arc(w - rt, rt, rt, -Math.PI / 2, 0, false)       // top-right
                    ctx.lineTo(w, h - rb)
                    if (rb > 0.5)
                        ctx.arc(w - rb, h - rb, rb, 0, Math.PI / 2, false)    // bottom-right
                    ctx.lineTo(rb, h)
                    if (rb > 0.5)
                        ctx.arc(rb, h - rb, rb, Math.PI / 2, Math.PI, false)  // bottom-left
                    ctx.lineTo(0, rt)
                    if (rt > 0.5)
                        ctx.arc(rt, rt, rt, Math.PI, 3 * Math.PI / 2, false)  // top-left
                    ctx.closePath()
                    ctx.fill()
                }
            }

            // The rows ride a ListView rather than a Column so a menu longer than
            // maxHeight scrolls. Its height comes from the row count (plateHeight),
            // never from contentHeight — a view whose height binds to its own
            // contentHeight never instantiates a delegate and renders nothing.
            ListView {
                id: rowList
                anchors.fill: parent
                clip: true
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds
                model: opener.children

                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index

                    // A delegate can outlive its model row by a frame, and reading
                    // through a null modelData throws on every property. `e` is the
                    // same object reference when present, so triggered() and the
                    // submenu's identity check still see the real entry, and an
                    // empty object stands in for the frame where it is gone.
                    readonly property var e: row.modelData || ({})
                    readonly property bool separator: row.modelData ? !!row.modelData.isSeparator : false
                    // Short-circuited on the row's own object first: the delegate can
                    // outlive its model row, and `separator` reads false for a null
                    // modelData, so a bare `!separator && row.modelData.checkState`
                    // would dereference null on exactly the frame the row is leaving.
                    readonly property bool checked: !!row.modelData && !row.modelData.isSeparator
                        && row.modelData.checkState !== Qt.Unchecked

                    width: rowList.width
                    height: separator ? root.separatorHeight : root.rowHeight

                    // ---- separator: the lists' own hairline ----------------------
                    Rectangle {
                        visible: row.separator
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: root.padH
                        anchors.right: parent.right
                        anchors.rightMargin: root.padH
                        height: 2
                        color: Qt.rgba(Theme.cardDim.r, Theme.cardDim.g, Theme.cardDim.b, 0.1)
                    }

                    // ---- row body ------------------------------------------------
                    Rectangle {
                        id: rowBody
                        visible: !row.separator
                        anchors.fill: parent
                        color: rowMouse.containsMouse && row.e.enabled
                            ? Theme.cardHighlight : "transparent"
                        Behavior on color {
                            ColorAnimation { duration: 120 }
                        }

                        // check / radio mark. One glyph covers both: a row that is
                        // on reads as on, and the checkbox/radio distinction is not
                        // something the user acts on differently. Centred in its slot
                        // — an explicit width means the ink would otherwise sit left
                        // in it, and the two glyph shapes are different widths.
                        Text {
                            id: checkMark
                            visible: root.checkSlot > 0
                            anchors.left: parent.left
                            anchors.leftMargin: root.padH
                            anchors.verticalCenter: parent.verticalCenter
                            width: root.checkSlot
                            horizontalAlignment: Text.AlignHCenter
                            text: row.checked ? "\uF00C" : ""
                            color: Theme.cardForeground
                            font.family: Theme.iconFont
                            font.pixelSize: 11
                        }

                        // The icon slot collapses to nothing when no row in this level
                        // carries an icon: an invisible Image still occupies its width,
                        // so a fixed 16 here would indent every label by an empty
                        // column (checkSlot/chevronSlot are conditional for the same
                        // reason).
                        Image {
                            id: entryIcon
                            visible: root.iconSlot > 0 && (row.e.icon || "").length > 0
                            anchors.left: checkMark.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: root.iconSlot > 0 ? 16 : 0
                            height: width
                            sourceSize: Qt.size(16, 16)
                            source: row.e.icon || ""
                            fillMode: Image.PreserveAspectFit
                        }

                        Text {
                            id: label
                            anchors.left: entryIcon.right
                            anchors.leftMargin: root.iconSlot > 0 ? 6 : 0
                            anchors.right: chevron.left
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            text: row.e.text || ""
                            // disabled rows dim rather than vanish — the shape of the
                            // menu is information too
                            color: row.e.enabled ? Theme.cardForeground : Theme.cardDim
                            font.family: Theme.barFontFamily
                            font.pixelSize: 13
                        }

                        // The chevron points LEFT, because that is where the submenu
                        // opens: the tray sits at the screen's right edge, so the
                        // plate's submenus grow leftward (see the Loader below). A
                        // right-pointing glyph here would promise a menu that never
                        // appears in that direction.
                        Text {
                            id: chevron
                            visible: root.chevronSlot > 0 && row.e.hasChildren
                            anchors.right: parent.right
                            anchors.rightMargin: root.padH
                            anchors.verticalCenter: parent.verticalCenter
                            width: root.chevronSlot
                            horizontalAlignment: Text.AlignRight
                            text: "\uF053"
                            color: Theme.cardDim
                            font.family: Theme.iconFont
                            font.pixelSize: 10
                        }

                        // The row's own action zone. Hover is enabled so the fill and
                        // the submenu follow the cursor, and so a disabled row can
                        // swallow its click instead of passing it to whatever is
                        // underneath.
                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: row.e.enabled && !row.e.hasChildren
                                ? Qt.PointingHandCursor : Qt.ArrowCursor

                            // The row's top in THIS level's coordinates. Mapped rather
                            // than read off row.y, because the rows live in a ListView
                            // that scrolls a long menu — row.y is content-relative and
                            // the submenu would detach from its row as soon as the
                            // plate is scrolled. A separator is 9px tall, so even an
                            // unscrolled index * rowHeight guess drifts.
                            function openSubmenu() {
                                root.openRowY = row.mapToItem(root, 0, 0).y
                                root.openEntry = row.modelData
                            }

                            onClicked: {
                                // the delegate can outlive its row by a frame; a click
                                // in that window must do nothing rather than call
                                // triggered() on the stand-in object
                                if (!row.modelData || !row.e.enabled)
                                    return
                                if (row.e.hasChildren) {
                                    // a click on the row that already owns the open
                                    // submenu closes it, so the row toggles
                                    if (root.openEntry === row.modelData)
                                        root.openEntry = null
                                    else
                                        openSubmenu()
                                    return
                                }
                                // emitting the entry's own signal is what sends the
                                // dbus "clicked" event — DBusMenuItem wires
                                // triggered() to sendTriggered() internally
                                row.e.triggered()
                                root.hostRoot.closeRequested()
                            }

                            // Submenus open on hover, the way every desktop menu
                            // works, and a plain row clears whatever was open. Nothing
                            // happens on exit: the cursor has to cross the gap between
                            // the plate and the submenu, and a close-on-exit would
                            // slam the submenu shut before the cursor arrived.
                            onEntered: {
                                if (row.e.hasChildren && row.e.enabled)
                                    openSubmenu()
                                else
                                    root.openEntry = null
                            }
                            // "The cursor is on this plate" for Bar.qml's
                            // leave-grace. Only one row can be hovered at a
                            // time (they do not overlap), so a single index is
                            // the whole state; the guard on exit keeps a
                            // neighbouring row's enter from being undone by
                            // the previous row's exit landing afterwards.
                            onContainsMouseChanged: {
                                if (rowMouse.containsMouse)
                                    root.hoverIndex = row.index
                                else if (root.hoverIndex === row.index)
                                    root.hoverIndex = -1
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- the submenu -----------------------------------------------------
    // One instance for the level's currently-open child, not one per row:
    // only one submenu is ever on screen at a time.
    //
    // `active` is the whole open/closed state — closing destroys the loaded
    // level and with it everything below, so a chain never comes back with a
    // stale submenu of its own still showing. Opening re-loads it, which is
    // a component instantiation, not a fork: cheap, and it happens on a
    // hover or a click rather than per frame.
    Loader {
        id: submenu
        source: "TrayMenu.qml"
        // The pop is part of the open state: a submenu is a sibling of the
        // clip, not a child of it, so it would hang at full size through the
        // root's pop-out while the plate shrank away. Gating on the pop closes
        // it the instant the shrink starts; it is only ever open at rest
        // anyway, since the rows cannot be hovered until the plate is fully
        // out.
        active: root.openEntry !== null && root.reveal > 0.999
        // The loaded level's geometry comes from the plate, so the Loader has
        // to take the item's implicit size for x/y below to have something to
        // measure against — a Loader's width/height default to the item's
        // implicit size, which is what menuWidth/plateHeight feed.
        //
        // `host` is constant and can be a plain assignment. `menuHandle` must
        // NOT be: onLoaded fires once per load, so moving the cursor from one
        // child row to another would leave the submenu showing the first
        // row's tree. The binding keeps it on whichever entry is open.
        onLoaded: {
            item.host = root
            item.menuHandle = Qt.binding(function () { return root.openEntry })
        }
        // to the left of the plate: the tray lives near the screen's right
        // edge, so a submenu opening right would run off it
        x: -(width + 4)
        // line its top up with the row that opened it, then keep it inside
        // the plate's vertical span
        y: Math.max(0, Math.min(root.openRowY, root.plateHeight - height))
    }
}
