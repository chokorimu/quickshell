// Launcher.qml — app launcher (rofi drun replacement)
// toggle from hyprland:  qs ipc call launcher toggle
//
// The card pops up from the bottom center of the screen — the island
// card's pop mechanics (Bar.qml), mirrored: one `pop` progress value
// drives the clip's height and the card's horizontal scale, so the
// card grows upward out of the screen's bottom edge instead of fading
// in over it. In with a slight overshoot (OutBack), out faster and
// without one (OutCubic).
// metrics mirror rofi's config.rasi: 500px card, r22, 7 rows, r12 selection
import QtQml
import QtQuick
import Quickshell
import Quickshell.Io
import "../../Theme"

PanelWindow {
    id: root

    property bool open: false
    property string filter: ""
    property int selected: 0

    // ---- card metrics ----------------------------------------------------
    readonly property real cardWidth: 500
    readonly property real cardRadius: 22
    // the pop's overshoot headroom: OutBack peaks at ~1.1x, so the clip
    // runs wider than the card or the overshoot gets shaved off
    readonly property real popOvershoot: 1.12
    // the content column plus its 10px padding top and bottom — the
    // clip binds to this, so the card fits its results (7 rows max)
    readonly property real cardHeight: cardColumn.height + 20

    // ---- the pop ----------------------------------------------------------
    // Mirrored from the island card: one progress value drives the
    // clip's height (0 -> cardHeight + cardRadius) and the card's
    // horizontal scale, so the card grows out from the screen's bottom
    // edge. No `from` on either animation — each picks up from the
    // current value, which is what makes a toggle mid-pop interrupt
    // cleanly.
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
        // the filter clears only once the card has fully retracted —
        // clearing it in close() would visibly empty the card on its
        // way down
        onStopped: if (!root.open) root.reset()
    }

    onOpenChanged: {
        if (root.open) { popOut.stop(); popIn.start() }
        else { popIn.stop(); popOut.start() }
    }

    // The window stays mapped for the shell's whole life. Toggling
    // `visible` instead remaps the full-screen layer surface on every
    // open, and that remap costs the first ~56ms of the pop-in — 9
    // dropped frames at 165Hz, measured — which read as the card
    // hitching into motion. The bar's window is always mapped for the
    // same reason.
    //
    // An always-mapped full-screen surface would eat every click on
    // the desktop, so the input mask carries the open/closed state:
    // full extent while the card is up (the click-outside MouseArea
    // needs the whole surface), zero-sized once it has retracted
    // (click-through — exactly how the bar's island card region
    // collapses to nothing when the island is closed).
    visible: true
    focusable: true
    exclusionMode: ExclusionMode.Ignore

    mask: Region {
        x: 0
        y: 0
        width: (root.open || root.pop > 0.001) ? root.width : 0
        height: (root.open || root.pop > 0.001) ? root.height : 0
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"

    // ---- app list -------------------------------------------------------
    // DesktopEntries populates asynchronously; applicationsChanged is the
    // only reliable signal that the scan has finished.
    property var apps: []

    function reloadApps() {
        var all = DesktopEntries.applications.values
        var out = []
        for (var i = 0; i < all.length; i++) {
            var e = all[i]
            if (e.noDisplay) continue
            if (!e.name) continue
            out.push(e)
        }
        root.apps = out
        root.selected = 0
    }

    Component.onCompleted: reloadApps()

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { root.reloadApps() }
    }

    readonly property var filtered: {
        var f = root.filter.trim().toLowerCase()
        if (f.length === 0) return root.apps
        var out = []
        for (var i = 0; i < root.apps.length; i++) {
            if (root.apps[i].name.toLowerCase().indexOf(f) !== -1)
                out.push(root.apps[i])
        }
        return out
    }

    onFilterChanged: root.selected = 0

    // ---- actions --------------------------------------------------------
    function reset() {
        root.filter = ""
        root.selected = 0
        input.text = ""
    }

    function close() {
        root.open = false
    }

    function launch(entry) {
        if (!entry) return
        // DesktopEntry.command is a QStringList — hand it to Process as-is.
        proc.command = entry.command
        proc.running = true
        root.close()
    }

    Process { id: proc }

    // ---- ipc ------------------------------------------------------------
    IpcHandler {
        target: "launcher"
        function toggle(): void {
            if (root.open) root.close()
            else { root.reset(); root.open = true; input.forceActiveFocus() }
        }
        function open(): void {
            root.reset()
            root.open = true
            input.forceActiveFocus()
        }
        function close(): void { root.close() }
    }

    // ---- ui -------------------------------------------------------------
    // click outside the card dismisses
    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    // ---- the card: pops up from the screen's bottom edge -----------------
    // The clip is anchored to the window's bottom and its height tracks
    // the pop, so the card grows upward out of the screen's bottom edge.
    // Wider than the card by the overshoot headroom, or the pop's scale
    // would shave the card's side edges square against the boundary.
    Item {
        id: cardClip
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        // Tuck down behind the screen's bottom edge by the corner
        // radius — the island's card tucks up behind the bar the same
        // way (its clip's topMargin is barHeight - cardRadius), which
        // hides its rounded top corners and makes the junction
        // seamless. Here the screen's bottom edge plays the bar's
        // role: the card's rounded bottom corners hide below it, so
        // the card sticks out of the screen's bottom edge instead of
        // sitting on the edge with its corners notched into view.
        anchors.bottomMargin: -root.cardRadius
        width: root.cardWidth * root.popOvershoot
        height: root.pop * (root.cardHeight + root.cardRadius)
        clip: true

        // A Canvas, not a Rectangle: the card's TOP corners are the
        // reveal edge — the band grows upward, so they are the last part
        // of the card to appear — and must stay rounded through the
        // whole pop. A Rectangle's radius is fixed, so a 22px corner on
        // a band the clip hasn't finished revealing reads as a clipped
        // square; the rounding only "appears" once the card is fully
        // open. The island card is the mirror image of this structure:
        // tucked top corners behind the bar, reveal-edge bottom corners.
        //
        // The top radius tracks the visible height — square while the
        // band is shorter than the radius, a growing cap until it holds
        // a full corner. The bottom corners keep the full radius and
        // are never seen: they live a corner radius below the screen's
        // bottom edge, tucked the same way the island's top corners sit
        // behind the bar. (Below the screen edge the path may invert
        // while the band is shorter than the radius — the arc centers
        // fall under the canvas — but the window clips all of it, so
        // nothing inverted is ever visible.)
        Canvas {
            id: card
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.cardWidth

            // the pop's width: the whole card scales outward from the
            // bottom center. The height comes from the clip (pop-bound).
            transform: Scale { origin.x: card.width / 2; origin.y: card.height; xScale: root.pop }

            // the clip's height changes every frame of the pop — repaint
            // so the corner tracking follows
            Connections {
                target: cardClip
                function onHeightChanged() { card.requestPaint() }
            }

            // a matugen regeneration rewrites the palette underneath
            // the painted fill
            Connections {
                target: Theme
                function onCardBackgroundChanged() { card.requestPaint() }
            }

            onPaint: {
                var ctx = getContext("2d")
                var w = width
                var h = height
                var cr = root.cardRadius
                // the reveal edge (top)
                var rt = Math.min(cr, Math.max(0, (h - cr) / 2))
                // the tucked edge (bottom): full radius, always — the
                // corners sit below the screen's bottom edge and are
                // never visible, exactly like the island's tucked top
                // corners keep the full radius behind the bar
                var rb = cr

                ctx.clearRect(0, 0, w, h)
                ctx.fillStyle = Theme.cardBackground
                ctx.beginPath()

                // one clockwise outline from the top-left: top edge,
                // top-right cap, right edge, bottom-right cap, bottom
                // edge, bottom-left cap, left edge, top-left cap. Every
                // arc starts at the point the path is already standing
                // on, or canvas silently inserts a straight connector
                // and the curve collapses (Corners.qml learned this the
                // hard way).
                ctx.moveTo(rt, 0)
                ctx.lineTo(w - rt, 0)
                if (rt > 0.5)
                    ctx.arc(w - rt, rt, rt, -Math.PI / 2, 0, false)      // top-right
                else
                    ctx.lineTo(w, 0)
                ctx.lineTo(w, h - rb)
                if (rb > 0.5)
                    ctx.arc(w - rb, h - rb, rb, 0, Math.PI / 2, false)   // bottom-right
                else
                    ctx.lineTo(w, h)
                ctx.lineTo(rb, h)
                if (rb > 0.5)
                    ctx.arc(rb, h - rb, rb, Math.PI / 2, Math.PI, false) // bottom-left
                else
                    ctx.lineTo(0, h)
                ctx.lineTo(0, rt)
                if (rt > 0.5)
                    ctx.arc(rt, rt, rt, Math.PI, 3 * Math.PI / 2, false) // top-left
                else
                    ctx.lineTo(0, 0)
                ctx.closePath()
                ctx.fill()
            }

            // swallow clicks on the card so they don't reach the dismiss
            // layer; declared before the content so the content's own
            // controls keep their clicks
            MouseArea { anchors.fill: parent }

            // the content sits 10px above the card's visible bottom
            // edge — the screen's bottom edge. The canvas's own bottom
            // is a corner radius further down (tucked behind the screen
            // edge), so the margin is cardRadius + 10: the mirror of
            // the island content's topMargin (cardRadius + 4 below the
            // bar's bottom edge).
            Column {
                id: cardColumn
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.cardRadius + 10
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: 10
                spacing: 0
                // no interaction while the card is retracting
                enabled: root.open

                // search field
                Rectangle {
                    width: parent.width
                    height: 44
                    radius: 12
                    color: Theme.cardHighlight

                    TextInput {
                        id: input
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        verticalAlignment: Text.AlignVCenter
                        color: Theme.cardForeground
                        font.family: Theme.barFontFamily
                        font.pixelSize: Theme.launcherFontSize
                        selectByMouse: true
                        persistentSelection: true

                        // push user input into the filter; reset() clears both sides
                        onTextEdited: root.filter = input.text

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "Search Apps..."
                            color: Theme.cardDim
                            font.family: Theme.barFontFamily
                            font.pixelSize: Theme.launcherFontSize
                            visible: input.text.length === 0
                        }

                        Keys.onPressed: function(event) {
                            var n = root.filtered.length
                            if (event.key === Qt.Key_Escape) {
                                root.close()
                                event.accepted = true
                            } else if (event.key === Qt.Key_Down && n > 0) {
                                root.selected = (root.selected + 1) % n
                                list.positionViewAtIndex(root.selected, ListView.Contain)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Up && n > 0) {
                                root.selected = (root.selected - 1 + n) % n
                                list.positionViewAtIndex(root.selected, ListView.Contain)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (n > 0) root.launch(root.filtered[root.selected])
                                event.accepted = true
                            }
                        }
                    }
                }

                Item { width: parent.width; height: 10 }

                // results — 7 visible rows, matching rofi's listview.
                // Fixed height: the card must not resize when the
                // filter narrows the results, or the pop's target
                // moves under the animation and the card appears to
                // jitter as you type.
                ListView {
                    id: list
                    width: parent.width
                    height: 7 * 40
                    clip: true
                    model: root.filtered
                    currentIndex: root.selected
                    highlightFollowsCurrentItem: false
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                    boundsBehavior: Flickable.StopAtBounds
                    reuseItems: true

                    delegate: MouseArea {
                        required property int index
                        required property var modelData
                        width: list.width
                        height: 40
                        onClicked: root.launch(modelData)

                        Rectangle {
                            anchors.fill: parent
                            radius: 12
                            color: index === root.selected ? Theme.cardInk : "transparent"
                        }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 5
                            anchors.rightMargin: 5
                            spacing: 10

                            Image {
                                width: 30
                                height: 30
                                anchors.verticalCenter: parent.verticalCenter
                                sourceSize: Qt.size(30, 30)
                                fillMode: Image.PreserveAspectFit
                                source: Quickshell.iconPath(modelData.icon, "application-x-executable")
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name
                                color: index === root.selected ? Theme.cardOnInk : Theme.cardForeground
                                font.family: Theme.barFontFamily
                                font.pixelSize: Theme.launcherFontSize
                                elide: Text.ElideRight
                                width: list.width - 60
                            }
                        }
                    }
                }

                Item { width: parent.width; height: 10 }
            }
        }
    }
}
