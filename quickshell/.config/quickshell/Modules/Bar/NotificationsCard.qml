// NotificationsCard.qml — the island's seventh menu: the control
// centre. Quick toggles up top, notification history below.
//
// Same card and pop as the media, usage, theme, volume, capture and
// session pages; reached by hovering the seventh tab button in the
// column. The toggles are four ToggleTiles in a 2x2 grid — wifi,
// bluetooth, do-not-disturb, battery saver — and the history is the
// clipboard list's idiom under a label row: a rounded cardHighlight
// plate, soft dividers, the partial row as the scroll affordance,
// anchored to the card's bottom edge so it takes every pixel the
// toggles leave it. Each row carries a trash glyph after its time —
// the per-row delete, quiet in cardDim against the label row's Clear
// pill, which stays the loud one — with a vertical hairline standing
// between the time and the glyph so the delete reads as the row's own
// action zone rather than as more row text.
//
// The page is a persistent instance behind a visible flag, so the
// three page-only services — Bluetooth, PowerProfiles and Network's
// radio flag — are flipped active and refreshed on the way in, in
// Brightness's mould: nothing forks while the card is closed.
import QtQml
import QtQuick
import Quickshell
import "../../Theme"
import "../../Services"

Item {
    id: notificationsPage

    // Plumbing for Bar.qml's hover OR-in. Nothing on the page takes
    // hover of its own — the tiles are click-only and the list
    // scrolls on the wheel — so this stays false, the same shape
    // Capture.qml carries before a section grows a hover control.
    property bool hovered: false

    // ---- the page-only services ----------------------------------------
    // active + refresh on the way in, inactive on the way out. The
    // tile bindings below are what construct these singletons at
    // shell load (a service referenced only from a callback would
    // not exist until the first callback ran), so the bindings have
    // to stay on the page rather than move into a function.
    onVisibleChanged: {
        if (visible) {
            Bluetooth.active = true
            Bluetooth.refresh()
            PowerProfiles.active = true
            PowerProfiles.refresh()
            Network.radioActive = true
            Network.refresh()
        } else {
            Bluetooth.active = false
            PowerProfiles.active = false
            Network.radioActive = false
        }
    }

    // ---- title row ------------------------------------------------------
    // The header mark + "Notifications", left-aligned, the 80px
    // margin clearing the menu column strip — every other page's
    // title row.
    Row {
        id: titleRow
        anchors.top: parent.top
        anchors.topMargin: 28
        anchors.left: parent.left
        anchors.leftMargin: 80
        spacing: 12

        HeaderIcon {
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "// NOTIFICATIONS"
            color: Theme.cardForeground
            font.family: Theme.barFontFamily
            font.pixelSize: 20
            font.weight: Font.DemiBold
        }
    }

    // ---- the toggles ----------------------------------------------------
    // 2x2 grid of 240px tiles across the 492px content width with a
    // 12px gap — the usage page's row-1 geometry, two rows of it.
    // Two anchored Rows rather than a Column of Rows: a Column gives
    // its children height but never width, so a Row inside one with
    // no width of its own is 0 wide and every tile vanishes.
    //
    // The labels run to a ~7-letter budget, and the long names are
    // abbreviated at the source rather than left to truncate. The
    // tile is 240 wide: the glyph takes 44 (14 margin + 18 + 12),
    // the state band takes 120 off the right edge, which leaves the
    // label 44..98 — 54px, about seven letters at 13px before
    // ElideRight starts eating them. So Bluetooth is BT, Do Not
    // Disturb is DND, and Battery Saver is Battery (the state line
    // already says which mode is live). Wi-Fi fits as it is.
    Row {
        id: toggleRow1
        anchors.top: titleRow.bottom
        anchors.topMargin: 24
        anchors.left: parent.left
        anchors.leftMargin: 80
        anchors.right: parent.right
        anchors.rightMargin: 28
        spacing: 12

        ToggleTile {
            width: 240
            glyph: "\uF1EB" // wifi
            label: "Wi-Fi"
            // the SSID while the radio is on — the one piece of state
            // that makes the tile worth reading rather than glancing
            stateText: Network.radioEnabled
                ? (Network.ssid.length > 0 ? Network.ssid : "On")
                : "Off"
            on: Network.radioEnabled
            onClicked: Network.setRadio(!Network.radioEnabled)
        }

        ToggleTile {
            width: 240
            glyph: "\uF293" // bluetooth-b
            label: "BT"
            stateText: Bluetooth.powered
                ? (Bluetooth.connectedDevice.length > 0
                    ? Bluetooth.connectedDevice : "Not connected")
                : "Off"
            available: Bluetooth.available
            on: Bluetooth.powered
            onClicked: Bluetooth.setPowered(!Bluetooth.powered)
        }
    }

    Row {
        id: toggleRow2
        anchors.top: toggleRow1.bottom
        anchors.topMargin: 12
        anchors.left: toggleRow1.left
        anchors.right: toggleRow1.right
        spacing: 12

        // the tile's own glyph follows the flag, and so does the
        // tab's out on the bar — bell while popups are allowed,
        // bell-slash while DND holds
        ToggleTile {
            width: 240
            glyph: NotificationHistory.dnd ? "\uF1F6" : "\uF0F3"
            label: "DND"
            stateText: NotificationHistory.dnd ? "On" : "Off"
            on: NotificationHistory.dnd
            onClicked: NotificationHistory.dnd = !NotificationHistory.dnd
        }

        ToggleTile {
            width: 240
            glyph: "\uF243" // battery-quarter
            label: "Battery"
            stateText: PowerProfiles.saverOn ? "Power saver" : "Balanced"
            available: PowerProfiles.available
            on: PowerProfiles.saverOn
            onClicked: PowerProfiles.setSaver(!PowerProfiles.saverOn)
        }
    }

    // ---- notification history -------------------------------------------
    // Below the toggles and anchored to the card's bottom edge rather
    // than flowed in a column above — the clipboard list's own
    // placement, and it buys the list every pixel the toggles leave.
    //
    // Top to bottom it reads label, list. The label takes the other
    // sections' styling and carries a Clear pill on its right that
    // empties the log; Clear is destructive, so it is the small pill
    // out of the way on the label's right, Reset's own placement.
    Column {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        anchors.left: parent.left
        anchors.leftMargin: 80
        anchors.right: parent.right
        anchors.rightMargin: 28
        spacing: 8

        Item {
            width: parent.width
            height: 20

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Notifications"
                color: Theme.cardForeground
                font.family: Theme.barFontFamily
                font.pixelSize: 14
            }

            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 20
                width: historyClearLabel.implicitWidth + 24
                radius: 10
                color: Theme.cardHighlight

                Text {
                    id: historyClearLabel
                    anchors.centerIn: parent
                    text: "Clear"
                    color: Theme.cardForeground
                    font.family: Theme.barFontFamily
                    font.pixelSize: 12
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NotificationHistory.clear()
                }
            }
        }

        // the list's slot: a plain Item rather than the Column's own
        // child, because the empty message shares the box and
        // anchors are not allowed directly inside a Column. The
        // width is a binding, not an anchor, for the same reason: a
        // Column positions its children vertically and leaves the
        // width alone, so an unset width is 0 — and a 0-wide slot
        // renders neither the list nor the empty message.
        //
        // 155, not more. The column is bottom-anchored and exactly
        // children-driven (20 label row + 8 + slot), so its top edge
        // sits at 384 - (28 + slot) = 356 - slot. Measured baseline:
        // the title row is 25 tall, which puts the first toggle row
        // at y77 and the second's bottom at y185 — 356 - 155 = 201
        // lands the label at y201, a 16px gap under the toggles. The
        // 40px rows then show three and a 35px peek of the fourth,
        // the peek being the scroll affordance.
        Item {
            width: parent.width
            height: 155

            // The list's plate: the section's own surface, rounded
            // at the card's own 10 — the tile and pill radius — at
            // LO's call. It shipped square, the clipboard list's
            // rationale: the dividers run edge to edge, and a rounded
            // plate was read as putting their ends on the curve. No
            // divider ever reaches a corner, though — rows are 40px,
            // so the feet land at y40/80/120 against corner zones of
            // only the top and bottom 10px, and StopAtBounds leaves
            // no overscroll to push one down into the bottom arc.
            // The ListView's own clip stays rectangular, so the
            // rounding is safe only because no row content reaches
            // the corners either: the icon starts 10px in, and the
            // partial fourth row's ink stops well inside the arcs.
            Rectangle {
                anchors.fill: parent
                radius: 10
                color: Theme.cardHighlight
            }

            ListView {
                id: historyList
                anchors.fill: parent
                // a fixed height off the card, never contentHeight:
                // a view whose height binds to its own content starts
                // at zero, instantiates no delegates, and can never
                // grow
                clip: true
                cacheBuffer: 200
                boundsBehavior: Flickable.StopAtBounds
                // no scrollbar — the partial fourth row is the
                // affordance, same as the clipboard list
                model: NotificationHistory.entries

                delegate: Rectangle {
                    // captured once per row: modelData is the entry
                    // object out of the history's JS array
                    required property var modelData
                    // the row's own index, so the divider knows which
                    // row is the last — a trailing hairline under the
                    // final entry would read as a border the list
                    // does not have
                    required property int index

                    // historyList.width, never ListView.width: with
                    // no id on the view, ListView resolves to the
                    // TYPE object, whose .width is undefined — the
                    // delegate silently collapses to 0 wide, with no
                    // error logged
                    width: historyList.width
                    height: 40
                    color: "transparent"

                    // the sender's avatar when the entry has one: a
                    // copy of the notification's own image, saved to
                    // disk at receipt (see the capture in
                    // Notifications.qml) because the image:// URL it
                    // arrived through dies with the Notification
                    // object. Falls back to the app icon — the popup
                    // card's own fallback — and then to nothing:
                    // iconPath("") mangles into a broken request, so
                    // only ask when the app named an icon.
                    Image {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22
                        height: 22
                        sourceSize: Qt.size(22, 22)
                        fillMode: Image.PreserveAspectFit
                        source: modelData.imagePath.length > 0
                            ? "file://" + modelData.imagePath
                            : modelData.icon.length > 0
                                ? Quickshell.iconPath(modelData.icon, "application-x-executable")
                                : ""
                    }

                    // summary over body — the popup card's own
                    // hierarchy at row size, with the app name
                    // standing in when an app sent no summary. A
                    // critical notification's summary takes the
                    // urgent red, the one color in the palette that
                    // means "look at this" without a legend.
                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 42
                        anchors.right: historyTime.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            width: parent.width
                            text: modelData.summary.length > 0
                                ? modelData.summary : modelData.app
                            color: modelData.urgency >= 2
                                ? Theme.barUrgent : Theme.cardForeground
                            font.family: Theme.barFontFamily
                            font.pixelSize: 13
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        Text {
                            width: parent.width
                            text: modelData.body
                            color: Theme.cardDim
                            font.family: Theme.barFontFamily
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            visible: modelData.body.length > 0
                        }
                    }

                    // receipt time — HH:MM today, MM/DD before that.
                    // Freedesktop notifications carry no timestamp of
                    // their own, so this is when the shell saw it.
                    //
                    // It moved in from the row's right edge to make
                    // room for the delete action: the time now anchors
                    // to the separator's left rather than to the row's,
                    // and the text column's right anchor follows it
                    // automatically.
                    Text {
                        id: historyTime
                        anchors.right: historyTrashSep.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            var d = new Date(modelData.time)
                            var pad = function (n) { return (n < 10 ? "0" : "") + n }
                            var now = new Date()
                            if (d.getFullYear() === now.getFullYear()
                                    && d.getMonth() === now.getMonth()
                                    && d.getDate() === now.getDate())
                                return pad(d.getHours()) + ":" + pad(d.getMinutes())
                            return pad(d.getMonth() + 1) + "/" + pad(d.getDate())
                        }
                        color: Theme.cardDim
                        font.family: Theme.barFontFamily
                        font.pixelSize: 12
                    }

                    // the separator between the row's content and its
                    // delete action — a vertical hairline standing in
                    // the gap the time moved out of. Without it the
                    // trash glyph reads as one more piece of row text
                    // that happens to sit at the end; with it the row
                    // splits into "what happened" and "what you can do
                    // about it", the settings-list trailing-action
                    // idiom.
                    //
                    // The row divider's own language, turned on its
                    // side: 2px of cardDim at 0.1, the same weight and
                    // the same softness as the hairline at the row's
                    // foot, so the two read as one system rather than
                    // as a border drawn around the row. cardDim rather
                    // than cardHighlight, which would be invisible on
                    // a cardHighlight plate.
                    //
                    // 24px in a 40px row — 60%, so the line sits
                    // slightly proud of the 18px trash box it divides
                    // from the time instead of tracing the glyph's own
                    // edges, and leaves 8px clear top and bottom. Full
                    // row height was the other candidate and reads as a
                    // table column rule, which would grid the list
                    // against its own foot dividers.
                    //
                    // Symmetric 8px gaps either side: the time anchors
                    // to this line's left, the line to the trash box's,
                    // so the three sit on an even rhythm.
                    //
                    // A plain Rectangle, so it carries no MouseArea and
                    // cannot steal cardZone's hover the way a
                    // hover-enabled control on this page would.
                    Rectangle {
                        id: historyTrashSep
                        anchors.right: historyTrash.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 2
                        height: 24
                        color: Theme.cardDim
                        opacity: 0.1
                    }

                    // per-row delete — the trash glyph after the time,
                    // at the row's right edge. cardDim like the time,
                    // so it reads as a quiet per-row action rather
                    // than a second Clear pill: the label row's Clear
                    // is the loud one, and this is the one you reach
                    // for on a single entry.
                    //
                    // A fixed 18px box rather than the glyph's own
                    // Text, the control-centre tiles' fix: a Nerd
                    // Font glyph's Text width follows its ink, not its
                    // advance, so an unpinned glyph would drag the
                    // time's right anchor along with it. The glyph is
                    // centered in the box with no width of its own,
                    // which centres the ink instead. Measured off the
                    // font files, the trash's ink centre is 0.360em
                    // against the time's digits' 0.350em — 0.10px at
                    // 12px, so both land on the row's centre line
                    // with plain vertical centring and no shared line
                    // box needed.
                    //
                    // Click-only like every MouseArea on the page: a
                    // hover-enabled one would steal cardZone's hover
                    // and collapse the island under a resting cursor.
                    Item {
                        id: historyTrash
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18
                        height: 18

                        Text {
                            anchors.centerIn: parent
                            text: "\uF1F8" // trash
                            color: Theme.cardDim
                            font.family: Theme.iconFont
                            font.pixelSize: 14
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NotificationHistory.remove(index)
                        }
                    }

                    // the divider, edge to edge at the row's foot —
                    // the settings-list idiom. 2px of cardDim at 0.1
                    // at LO's call, up from a 1px cardBackground
                    // groove: the card's own surface cutting through
                    // read as a deep channel, and the softer line
                    // separates the rows without drawing them apart.
                    // 0.35 was still too present and 0.2 after it, so
                    // it came down again. cardDim rather than
                    // cardHighlight, which would be invisible on a
                    // cardHighlight plate.
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 2
                        color: Theme.cardDim
                        opacity: 0.1
                        visible: index < historyList.count - 1
                    }
                }
            }

            // an empty log reads the same way the clipboard's does:
            // one dim line at the top of the slot, where the first
            // entry would land
            Text {
                anchors.top: parent.top
                anchors.topMargin: 10
                anchors.horizontalCenter: parent.horizontalCenter
                visible: NotificationHistory.entries.length === 0
                text: "No notifications yet"
                color: Theme.cardDim
                font.family: Theme.barFontFamily
                font.pixelSize: 13
            }
        }
    }
}
