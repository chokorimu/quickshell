// NetworkCard.qml — the island's seventh menu: the wifi picker.
//
// Same card and pop as the other pages; reached by hovering the wifi
// tab in the column. Top to bottom it reads title + radio pill, a
// status line, a "Networks" label row with the Rescan pill in Clear's
// slot, and the scan as a scrollable list on a cardHighlight plate —
// the notifications page's list idiom, one row per SSID.
//
// A row is strength bars, the name, a lock when the network is
// secured, and the state at the right: Connected / Connecting… /
// Saved / the security type (Open for an open network). Clicking a
// row connects, disconnects, brings a saved profile back up, or — for
// an unsaved secured network — swaps the list for the password panel
// over the same box. Saved rows carry a trash glyph after a hairline
// separator: the notification row's own trailing action.
//
// The password panel is the one place in the shell that asks for the
// keyboard. A layer surface cannot receive keys at keyboardFocus
// None, so Bar.qml raises `keyboardActive` and shell.qml flips the
// bar window to WlrKeyboardFocus.Exclusive — the mechanism the
// launcher already proved on an already-mapped surface (see its
// keyboardFocus comment). The flip is tied to the panel, not to the
// page: a hover-opened island must not take the keyboard away from
// the desktop, but a field the user just clicked into must.
//
// No MouseArea in here takes hover: a hover-enabled area would steal
// cardZone's hover in Bar.qml and collapse the island under a resting
// cursor. The rows, the pills and the eye are click-only, like the
// list pages around them.
import QtQml
import QtQuick
import Quickshell
import "../../Theme"
import "../../Services"

Item {
    id: wifiPage

    // ---- the password panel's state -------------------------------------
    // pendingSsid is what makes the panel exist at all. It is also the
    // keyboard request: `keyboardActive` is what Bar.qml reads to raise
    // the bar window's keyboard interactivity, so an empty SSID means
    // the shell never holds the keyboard.
    property string pendingSsid: ""
    property bool revealPassword: false
    readonly property bool keyboardActive: pendingSsid.length > 0
    readonly property bool busy: Network.connecting.length > 0

    function openPanel(ssid) {
        wifiPage.pendingSsid = ssid
        wifiPage.revealPassword = false
        passwordInput.text = ""
        Network.lastError = ""
        // The window is flipping to Exclusive in the same turn, and
        // the launcher's own open path asks for focus in the same
        // breath, so this is the proven shape. The retry below covers
        // the case where the compositor commits the interactivity a
        // frame late and the request lands first.
        passwordInput.forceActiveFocus()
        focusRetry.restart()
    }

    function closePanel() {
        wifiPage.pendingSsid = ""
        wifiPage.revealPassword = false
        passwordInput.text = ""
    }

    function submitPassword() {
        if (wifiPage.pendingSsid.length === 0 || wifiPage.busy)
            return
        Network.connectTo(wifiPage.pendingSsid, passwordInput.text)
    }

    // one retry, only if the field did not take: a second
    // forceActiveFocus while it is already active would be harmless,
    // but the guard keeps it from fighting a user who tabbed away
    Timer {
        id: focusRetry
        interval: 80
        onTriggered: {
            if (wifiPage.visible && wifiPage.keyboardActive
                    && !passwordInput.activeFocus)
                passwordInput.forceActiveFocus()
        }
    }

    // the panel closes itself the moment its network is actually up —
    // the row behind it is the confirmation, so the form should not
    // linger over it
    Connections {
        target: Network
        function onUpdated() {
            if (wifiPage.pendingSsid.length > 0
                    && Network.connected
                    && Network.ssid === wifiPage.pendingSsid)
                wifiPage.closePanel()
        }
    }

    // ---- row actions -----------------------------------------------------
    function rowClicked(n) {
        // an enterprise network needs an identity and usually a CA,
        // which this page does not collect — the row says Enterprise
        // instead of opening a prompt that could not succeed
        if (n.enterprise)
            return
        // one action at a time: a second connect queued behind a 30s
        // one would fire minutes later out of nowhere
        if (wifiPage.busy)
            return
        if (n.active) {
            Network.disconnectWifi()
        } else if (n.saved) {
            Network.connectSaved(n.ssid)
        } else if (n.secured) {
            wifiPage.openPanel(n.ssid)
        } else {
            Network.connectTo(n.ssid, "")
        }
    }

    // ---- the page's lifecycle -------------------------------------------
    // A persistent instance behind a visible flag, so the services are
    // flipped active on the way in and left alone the rest of the
    // time: nothing forks, and nothing scans, while the card is closed.
    onVisibleChanged: {
        if (visible) {
            Network.pageActive = true
            Network.lastError = ""
            Network.refresh()
            Network.readSaved()
            Network.scan(true)
        } else {
            Network.pageActive = false
            Network.lastError = ""
            wifiPage.closePanel()
        }
    }

    // ---- title row ------------------------------------------------------
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
            text: "// WI-FI"
            color: Theme.cardForeground
            font.family: Theme.barFontFamily
            font.pixelSize: 20
            font.weight: Font.DemiBold
        }
    }

    // ---- the radio pill -------------------------------------------------
    // One click away in the title row's corner, the media page's size
    // switch placement. It wears the accent while the radio is on and
    // the quiet surface while it is off, so the state reads at a
    // glance without a second label saying so.
    Rectangle {
        id: radioPill
        anchors.right: parent.right
        anchors.rightMargin: 28
        anchors.verticalCenter: titleRow.verticalCenter
        height: 20
        width: radioLabel.implicitWidth + 24
        radius: 10
        color: Network.radioEnabled ? Theme.cardAccent : Theme.cardHighlight

        Text {
            id: radioLabel
            anchors.centerIn: parent
            text: Network.radioEnabled ? "On" : "Off"
            color: Network.radioEnabled ? Theme.cardAccentOn : Theme.cardForeground
            font.family: Theme.barFontFamily
            font.pixelSize: 12
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Network.setRadio(!Network.radioEnabled)
        }
    }

    // ---- status line ----------------------------------------------------
    // What the machine is on, or why there is nothing to connect to.
    // The right half carries the last failure — a connect that timed
    // out, a wrong password — in the urgent red, so the reason lands
    // beside the list rather than as a popup that covers it.
    Text {
        id: statusText
        anchors.top: titleRow.bottom
        anchors.topMargin: 16
        anchors.left: parent.left
        anchors.leftMargin: 80
        anchors.right: statusError.left
        anchors.rightMargin: 12
        text: {
            if (!Network.available)
                return "No Wi-Fi device"
            if (!Network.radioEnabled)
                return "Wi-Fi is off — turn it on to see networks"
            if (Network.connected && Network.kind === "wifi")
                return "Connected to " + Network.ssid
            if (Network.connected)
                return "Online over " + Network.kind
            return "Not connected"
        }
        color: Network.connected ? Theme.cardForeground : Theme.cardDim
        font.family: Theme.barFontFamily
        font.pixelSize: 13
        elide: Text.ElideRight
    }

    Text {
        id: statusError
        anchors.right: parent.right
        anchors.rightMargin: 28
        anchors.verticalCenter: statusText.verticalCenter
        width: Math.min(implicitWidth, 200)
        text: Network.lastError
        // the panel carries the same line in its own hint, so the
        // top-right copy stands down while the panel is up
        visible: text.length > 0 && !wifiPage.keyboardActive
        color: Theme.barUrgent
        font.family: Theme.barFontFamily
        font.pixelSize: 12
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
    }

    // ---- the networks section -------------------------------------------
    // Label + Rescan pill, the label row every other list page wears.
    // The pill's own label goes "Scanning…" while the sweep runs, so
    // the wait is explained on the control that caused it.
    Item {
        id: sectionLabel
        anchors.top: statusText.bottom
        anchors.topMargin: 16
        anchors.left: parent.left
        anchors.leftMargin: 80
        anchors.right: parent.right
        anchors.rightMargin: 28
        height: 20

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Networks"
            color: Theme.cardForeground
            font.family: Theme.barFontFamily
            font.pixelSize: 14
        }

        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 20
            width: rescanLabel.implicitWidth + 24
            radius: 10
            color: Theme.cardHighlight

            // a dead control reads as dead: with the radio off, or a
            // sweep already running, the pill dims the way the bar's
            // unavailable readouts do
            readonly property bool live: !Network.scanning && Network.radioEnabled

            Text {
                id: rescanLabel
                anchors.centerIn: parent
                text: Network.scanning ? "Scanning…" : "Rescan"
                color: parent.live ? Theme.cardForeground : Theme.cardDim
                font.family: Theme.barFontFamily
                font.pixelSize: 12
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: parent.live ? Qt.PointingHandCursor : Qt.ArrowCursor
                enabled: parent.live
                onClicked: Network.scan(true)
            }
        }
    }

    // ---- the list -------------------------------------------------------
    // Anchored to the label row above and the card's bottom margin
    // below, so it takes every pixel the header leaves — the card
    // never resizes, and rows scroll past a partial one, which is the
    // scroll affordance (there is no scrollbar anywhere on this card).
    Item {
        id: listSlot
        anchors.top: sectionLabel.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.leftMargin: 80
        anchors.right: parent.right
        anchors.rightMargin: 28
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16

        Rectangle {
            id: listPlate
            anchors.fill: parent
            radius: 10
            color: Theme.cardHighlight
            visible: !wifiPage.keyboardActive
        }

        ListView {
            id: networkList
            anchors.fill: parent
            // a fixed height off the card, never contentHeight: a view
            // whose height binds to its own content starts at zero,
            // instantiates no delegates, and can never grow
            clip: true
            cacheBuffer: 200
            boundsBehavior: Flickable.StopAtBounds
            visible: !wifiPage.keyboardActive
            model: Network.networks

            delegate: Rectangle {
                required property var modelData
                required property int index

                // networkList.width, never ListView.width: with no id
                // on the view, ListView resolves to the TYPE object,
                // whose .width is undefined — the delegate silently
                // collapses to 0 wide
                width: networkList.width
                height: 44
                color: "transparent"

                // the connected row's mark: a thin accent bar down the
                // plate's left edge, inside the straight run so it
                // never reaches the rounded corner. The selected tab's
                // black edge block, at row scale — the accent fill a
                // full-width row would wear reads far too loud here
                // (the launcher's selection row learned that).
                Rectangle {
                    x: 0
                    width: 3
                    height: 20
                    radius: 1.5
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.cardAccent
                    visible: modelData.active
                }

                // ---- signal strength ---------------------------------
                // Four bars, ascending, lit from the left. The
                // thresholds are deliberately generous — a 65% link
                // lights three of four, which is what every other wifi
                // client shows for a perfectly usable signal.
                Item {
                    id: bars
                    property int level: modelData.signal
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    height: 14

                    Rectangle {
                        x: 0
                        width: 3
                        height: 4
                        radius: 1
                        anchors.bottom: parent.bottom
                        color: bars.level >= 15 ? Theme.cardForeground : Theme.cardDim
                        opacity: bars.level >= 15 ? 1 : 0.35
                    }
                    Rectangle {
                        x: 4
                        width: 3
                        height: 7
                        radius: 1
                        anchors.bottom: parent.bottom
                        color: bars.level >= 35 ? Theme.cardForeground : Theme.cardDim
                        opacity: bars.level >= 35 ? 1 : 0.35
                    }
                    Rectangle {
                        x: 8
                        width: 3
                        height: 10
                        radius: 1
                        anchors.bottom: parent.bottom
                        color: bars.level >= 55 ? Theme.cardForeground : Theme.cardDim
                        opacity: bars.level >= 55 ? 1 : 0.35
                    }
                    Rectangle {
                        x: 12
                        width: 3
                        height: 13
                        radius: 1
                        anchors.bottom: parent.bottom
                        color: bars.level >= 75 ? Theme.cardForeground : Theme.cardDim
                        opacity: bars.level >= 75 ? 1 : 0.35
                    }
                }

                // ---- the SSID ----------------------------------------
                Text {
                    id: rowName
                    anchors.left: bars.right
                    anchors.leftMargin: 12
                    anchors.right: lockGlyph.visible ? lockGlyph.left : stateText.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.ssid
                    color: Theme.cardForeground
                    font.family: Theme.barFontFamily
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }

                // lock glyph — a fixed 18px box with the glyph centred
                // in it, the control-centre tiles' ink-width fix: a
                // Nerd Font glyph's Text width follows its ink, not its
                // advance, so an unpinned one would drag the name's
                // right anchor around from row to row
                Item {
                    id: lockGlyph
                    anchors.right: stateText.left
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14
                    height: 18
                    visible: modelData.secured

                    Text {
                        anchors.centerIn: parent
                        text: "\uF023" // lock
                        color: Theme.cardDim
                        font.family: Theme.iconFont
                        font.pixelSize: 12
                    }
                }

                // ---- the state ---------------------------------------
                // Connected / Connecting… / Saved / the security type,
                // which for an open network reads "Open" — the one
                // word that matters most on a public network.
                Text {
                    id: stateText
                    anchors.right: forgetSep.visible ? forgetSep.left : parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, 96)
                    text: {
                        if (modelData.active && Network.connected)
                            return "Connected"
                        if (wifiPage.busy && Network.connecting === modelData.ssid)
                            return "Connecting…"
                        if (modelData.enterprise)
                            return "Enterprise"
                        if (modelData.saved)
                            return "Saved"
                        return modelData.secured ? modelData.security : "Open"
                    }
                    color: modelData.active && Network.connected
                        ? Theme.cardForeground : Theme.cardDim
                    font.family: Theme.barFontFamily
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                }

                // ---- forget -------------------------------------------
                // Saved profiles only, and never the one in use: the
                // separator and the 18px box are the notification row's
                // trailing-action language, so a trash glyph here reads
                // as the row's own control rather than as more text.
                Rectangle {
                    id: forgetSep
                    anchors.right: forgetGlyph.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 2
                    height: 24
                    color: Theme.cardDim
                    opacity: 0.1
                    visible: modelData.saved && !modelData.active
                }

                Item {
                    id: forgetGlyph
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18
                    height: 18
                    visible: modelData.saved && !modelData.active

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
                        onClicked: Network.forget(modelData.ssid)
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    // the trailing action has its own area and must win:
                    // declared before this one, so this one sits on top —
                    // inset it past the trash box instead
                    anchors.rightMargin: forgetGlyph.visible ? 34 : 0
                    cursorShape: modelData.enterprise ? Qt.ArrowCursor : Qt.PointingHandCursor
                    enabled: !modelData.enterprise
                    onClicked: wifiPage.rowClicked(modelData)
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 2
                    color: Theme.cardDim
                    opacity: 0.1
                    visible: index < networkList.count - 1
                }
            }
        }

        // the empty states share the slot with the list, so they sit on
        // the plate rather than replacing it — top-aligned where the
        // first row would land, the clipboard's own treatment
        Text {
            anchors.top: parent.top
            anchors.topMargin: 10
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 20
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: networkList.count === 0 && !wifiPage.keyboardActive
            text: {
                if (!Network.available)
                    return "This machine has no wifi adapter."
                if (!Network.radioEnabled)
                    return "Wi-Fi is off."
                if (Network.scanning)
                    return "Scanning for networks…"
                return "No networks in range."
            }
            color: Theme.cardDim
            font.family: Theme.barFontFamily
            font.pixelSize: 13
        }

        // ---- the password panel --------------------------------------
        // Covers the label row and the list rather than floating over
        // half of them: while a password is being typed, the thing the
        // card is doing is this one field. Cancel and Connect sit on
        // the panel's floor, the primary action in the accent and the
        // way out on the card's own surface (a cardHighlight pill on a
        // cardHighlight plate would be invisible).
        Rectangle {
            id: passwordPanel
            anchors.fill: parent
            visible: wifiPage.keyboardActive
            radius: 10
            color: Theme.cardHighlight

            Text {
                id: panelCaption
                anchors.top: parent.top
                anchors.topMargin: 16
                anchors.left: parent.left
                anchors.leftMargin: 16
                text: "Connect to"
                color: Theme.cardDim
                font.family: Theme.barFontFamily
                font.pixelSize: 12
            }

            Text {
                id: panelSsid
                anchors.top: panelCaption.bottom
                anchors.topMargin: 2
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.right: parent.right
                anchors.rightMargin: 16
                text: wifiPage.pendingSsid
                color: Theme.cardForeground
                font.family: Theme.barFontFamily
                font.pixelSize: 17
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Rectangle {
                id: field
                anchors.top: panelSsid.bottom
                anchors.topMargin: 14
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.right: parent.right
                anchors.rightMargin: 16
                height: 44
                radius: 8
                color: Theme.cardBackground

                TextInput {
                    id: passwordInput
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.right: eyeBox.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.cardForeground
                    selectionColor: Theme.cardAccent
                    selectedTextColor: Theme.cardAccentOn
                    font.family: Theme.barFontFamily
                    font.pixelSize: 14
                    clip: true
                    echoMode: wifiPage.revealPassword
                        ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "•"
                    // Enter submits, Escape backs out. Both are only
                    // reachable while the bar window holds the
                    // keyboard (see keyboardActive above).
                    onAccepted: wifiPage.submitPassword()
                    Keys.onEscapePressed: function (event) {
                        event.accepted = true
                        wifiPage.closePanel()
                    }
                }

                // TextInput has no placeholderText — that is TextField
                // — so the hint is a Text behind it, hidden as soon as
                // there is something to see
                Text {
                    anchors.left: passwordInput.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Password"
                    visible: passwordInput.text.length === 0
                    color: Theme.cardDim
                    font.family: Theme.barFontFamily
                    font.pixelSize: 14
                }

                // reveal toggle — typing a long wifi password blind is
                // a false economy on a keyboard you are sharing with
                // the desktop for eight seconds
                Item {
                    id: eyeBox
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18
                    height: 18

                    Text {
                        anchors.centerIn: parent
                        text: wifiPage.revealPassword ? "\uF070" : "\uF06E" // eye-slash / eye
                        color: Theme.cardDim
                        font.family: Theme.iconFont
                        font.pixelSize: 14
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            wifiPage.revealPassword = !wifiPage.revealPassword
                            passwordInput.forceActiveFocus()
                        }
                    }
                }
            }

            Text {
                id: panelHint
                anchors.top: field.bottom
                anchors.topMargin: 10
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.right: parent.right
                anchors.rightMargin: 16
                text: Network.lastError.length > 0
                    ? Network.lastError
                    : "Enter to connect · Esc to cancel"
                color: Network.lastError.length > 0 ? Theme.barUrgent : Theme.cardDim
                font.family: Theme.barFontFamily
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            // Cancel and Connect on the panel's floor, right-aligned
            // with the field's edges so the block reads as one column.
            Rectangle {
                id: cancelPill
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 16
                anchors.right: connectPill.left
                anchors.rightMargin: 8
                height: 28
                width: cancelLabel.implicitWidth + 28
                radius: 8
                color: Theme.cardBackground

                Text {
                    id: cancelLabel
                    anchors.centerIn: parent
                    text: "Cancel"
                    color: Theme.cardForeground
                    font.family: Theme.barFontFamily
                    font.pixelSize: 12
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: wifiPage.closePanel()
                }
            }

            Rectangle {
                id: connectPill
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 16
                anchors.right: parent.right
                anchors.rightMargin: 16
                height: 28
                width: connectLabel.implicitWidth + 28
                radius: 8
                color: Theme.cardAccent

                Text {
                    id: connectLabel
                    anchors.centerIn: parent
                    text: wifiPage.busy ? "Connecting…" : "Connect"
                    color: Theme.cardAccentOn
                    font.family: Theme.barFontFamily
                    font.pixelSize: 12
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    enabled: !wifiPage.busy
                    onClicked: wifiPage.submitPassword()
                }
            }
        }
    }
}
