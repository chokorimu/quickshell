// CardDropdown.qml — the island's select control.
//
// A 26px field on cardBackground showing the current value, with a
// chevron-down at its right; clicking it opens a list just below the
// field, on a cardPill plate — one step off the panel's cardHighlight
// in either palette, the theme page's mode-switch track at list scale.
// The list is a ListView capped at `maxRows`, so a monitor reporting
// twenty modes cannot push the popup past the bottom of the card; the
// partial row is the scroll affordance, as on every other list here,
// and the wheel scrolls it (a click-only MouseArea in a delegate
// blocks dragging, which is the price of the card's no-hover rule).
//
// `open` is bound by the page, not owned here: only one select may be
// open at a time, so the page holds the id of the open one and this
// control only asks to toggle itself (`toggleRequested()`). The page
// also carries the click-away catcher that closes it, which is the
// other reason the state cannot live here. The page likewise lifts the
// ROW the open control sits in (`z: 1`): a child's z reorders it among
// its own siblings, not among its parent's, so a z here would leave the
// popup painting under the rows below it.
//
// Options arrive as `{ value, label }` and are copied into `rows` only
// when their CONTENT changes. The service reassigns its monitor array
// on every 2s poll, so a model bound straight through would hand the
// ListView a new array twice a second and reset its scroll position
// under the cursor. The comparison is a JSON string of the array —
// a few dozen short strings, cheap, and exact.
//
// Every MouseArea is click-only: a hover-enabled one inside the card
// would steal cardZone's hover in Bar.qml and collapse the island
// under a resting cursor, like every other control on these pages.
import QtQml
import QtQuick
import Quickshell
import "../../Theme"

Item {
    id: root

    // [{ value, label }]
    property var options: []
    // the VALUE of the current option, not its label — the label is
    // looked up out of the options so the two cannot drift apart
    property string current: ""
    property string placeholder: "\u2014"
    property bool open: false
    // rows the popup shows before it scrolls. 5 × 26 + 8 of padding is
    // 138: probed on the displays panel, the lowest field's plate (Scale
    // at y209) ends at 377 in a panel that ends at 384, so even the last
    // dropdown stays inside the card.
    property int maxRows: 5

    signal toggleRequested()
    signal picked(string value)

    readonly property int rowHeight: 26
    readonly property int fieldHeight: 26

    readonly property string currentLabel: {
        for (var i = 0; i < root.rows.length; i++) {
            if (root.rows[i].value === root.current)
                return root.rows[i].label
        }
        return root.placeholder
    }

    implicitHeight: root.fieldHeight
    implicitWidth: 160

    // ---- the options, held steady across polls --------------------------
    property var rows: []
    property string rowsKey: ""

    function syncRows() {
        var key = JSON.stringify(root.options)
        if (key === root.rowsKey)
            return
        root.rowsKey = key
        root.rows = root.options
    }

    onOptionsChanged: root.syncRows()
    Component.onCompleted: root.syncRows()

    // ---- the field -------------------------------------------------------
    Rectangle {
        id: field
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.fieldHeight
        radius: 8
        color: Theme.cardBackground

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.right: chevron.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: root.currentLabel
            color: root.rows.length > 0 ? Theme.cardForeground : Theme.cardDim
            font.family: Theme.barFontFamily
            font.pixelSize: 12
            elide: Text.ElideRight
        }

        Text {
            id: chevron
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: "\uF078" // chevron-down
            color: Theme.cardDim
            font.family: Theme.iconFont
            font.pixelSize: 11
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: root.rows.length > 0
                ? Qt.PointingHandCursor : Qt.ArrowCursor
            enabled: root.rows.length > 0
            onClicked: root.toggleRequested()
        }
    }

    // ---- the list --------------------------------------------------------
    Rectangle {
        id: popup
        anchors.top: field.bottom
        anchors.topMargin: 4
        anchors.left: parent.left
        width: root.width
        height: Math.min(root.rows.length, root.maxRows) * root.rowHeight + 8
        radius: 10
        color: Theme.cardPill
        visible: root.open

        ListView {
            id: list
            anchors.fill: parent
            anchors.topMargin: 4
            anchors.bottomMargin: 4
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.rows

            delegate: Rectangle {
                required property var modelData

                // list.width, never ListView.width: with no id on the
                // view, ListView resolves to the TYPE object and the
                // delegate silently collapses to 0 wide
                width: list.width
                height: root.rowHeight
                color: "transparent"

                readonly property bool active: modelData.value === root.current

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.right: check.left
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.label
                    // the two-state ink the pinned clipboard rows wear:
                    // full cardForeground for the live option, the dim
                    // the rest of the list is drawn in for the others.
                    // Not the accent — #e6e600 all but disappears on
                    // the light plate.
                    color: parent.active ? Theme.cardForeground : Theme.cardDim
                    font.family: Theme.barFontFamily
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                Text {
                    id: check
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uF00C" // check
                    visible: parent.active
                    color: Theme.cardForeground
                    font.family: Theme.iconFont
                    font.pixelSize: 11
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    // picked() closes the list through the page; asking
                    // to toggle as well would reopen it on the spot
                    onClicked: root.picked(modelData.value)
                }
            }
        }
    }

    // ---- opening ---------------------------------------------------------
    // Bring the live option into view, so a monitor whose mode sits
    // twentieth in its list does not open onto the top of the list and
    // read as "nothing selected". callLater because the ListView's
    // delegates are created when the popup becomes visible, which is
    // after this handler runs.
    onOpenChanged: {
        if (!root.open)
            return
        for (var i = 0; i < root.rows.length; i++) {
            if (root.rows[i].value === root.current) {
                var at = i
                Qt.callLater(function () {
                    list.positionViewAtIndex(at, ListView.Beginning)
                })
                return
            }
        }
    }
}
