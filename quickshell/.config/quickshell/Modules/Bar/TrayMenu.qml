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
    readonly property int minWidth: 180
    readonly property int maxWidth: 320
    // The bar window is ~507 tall and the menu hangs from the bar's bottom
    // edge, so a long menu is capped and scrolls rather than running past
    // the window's bounds and being clipped by them.
    readonly property int maxHeight: 420
    readonly property int plateRadius: 10

    // ---- the menu tree ---------------------------------------------------
    QsMenuOpener {
        id: opener
        menu: root.menuHandle
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
    // Measured off the real strings in the real font. A hidden Repeater of
    // Texts all parked at 0,0 yields the widest one through childrenRect —
    // exact, where a length-based guess truncates a proportional font, and
    // with no TextMetrics/Text disagreement to trip over (the bar's marquee
    // shows those two differing by ~1.4px on this same font).
    Item {
        id: measurer
        visible: false

        Repeater {
            model: opener.children
            Text {
                text: modelData ? (modelData.text || "") : ""
                font.family: Theme.barFontFamily
                font.pixelSize: 13
            }
        }
    }

    readonly property real labelWidth: measurer.childrenRect.width
    readonly property int contentWidth: Math.ceil(labelWidth) + padH * 2
        + checkSlot + iconSlot + chevronSlot
    readonly property int plateWidth: Math.max(minWidth, Math.min(maxWidth, contentWidth))

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

    implicitWidth: plateWidth
    implicitHeight: plateHeight
    width: implicitWidth
    height: implicitHeight
    visible: menuHandle !== null && rowCount > 0

    // a level that goes away must not reopen on the submenu it had showing
    onVisibleChanged: if (!visible) openEntry = null

    // ---- the plate -------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color: Theme.cardBackground
        radius: root.plateRadius
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
        active: root.openEntry !== null
        // The loaded level's geometry comes from the plate, so the Loader has
        // to take the item's implicit size for x/y below to have something to
        // measure against — a Loader's width/height default to the item's
        // implicit size, which is what plateWidth/plateHeight feed.
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
