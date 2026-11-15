// MonitorCard.qml — the island's display manager.
//
// The eighth tab. Top to bottom it reads title, a status line (with
// the last failure on its right, NetworkCard's idiom), a "Displays"
// label row with the Refresh pill in Clear's slot, and the outputs as
// a scrollable list on a cardHighlight plate — one row per connected
// output, ACTIVE OR NOT, because the page's whole job is the one that
// is switched off.
//
// A row is the output's name over its mode, with an On/Off pill at the
// right. Clicking the pill enables or disables; clicking the row body
// swaps the list for that output's detail panel, over the same box
// (the wifi page's password panel). The panel is where everything
// else lives: resolution, refresh rate and scale as three CardDropdown
// selects, then rotation, mirror target and arrangement, plus Focus
// and Disable on its floor.
//
// The one thing the page refuses to do is disable the last active
// display — the pill dims instead of taking the only screen away.
// Hyprland has no "primary display", so Focus is a dispatch rather
// than a rule: it is what decides where a new window opens.
//
// No MouseArea in here takes hover: a hover-enabled area would steal
// cardZone's hover in Bar.qml and collapse the island under a resting
// cursor. The rows, the pills and the dropdowns are click-only, like
// the list pages around them.
import QtQml
import QtQuick
import Quickshell
import "../../Theme"
import "../../Services"

Item {
    id: monitorPage

    // the output whose detail panel is open; "" shows the list
    property string selectedName: ""
    readonly property var selected: monitorPage.selectedName.length > 0
        ? Monitors.byName(monitorPage.selectedName) : null

    // the id of the open dropdown ("" = none). One at a time, and the
    // page owns it rather than each control, because the click-away
    // catcher that closes it lives here and because two open lists
    // would paint over each other's rows.
    property string openSelect: ""

    // the scales the Scale dropdown offers. 1.6 is this machine's
    // panel, and it is on the ladder so a user can always get back to
    // it. A scale outside this list is still shown when it is the live
    // one (see scaleOptions), so the ladder can stay short.
    readonly property var scaleLadder: [0.8, 1, 1.25, 1.6, 1.67, 2]

    // ---- the layout's numbers -------------------------------------------
    readonly property int labelColumn: 120
    readonly property int controlWidth: 220
    readonly property int rowHeight: 52

    // ---- the page's lifecycle -------------------------------------------
    // A persistent instance behind a visible flag, so the poll is
    // flipped active on the way in and left alone the rest of the
    // time: nothing forks while the card is closed.
    onVisibleChanged: {
        Monitors.active = visible
        if (visible) {
            Monitors.lastError = ""
            Monitors.refresh()
        } else {
            monitorPage.selectedName = ""
            monitorPage.openSelect = ""
            Monitors.lastError = ""
        }
    }

    function openPanel(name) {
        monitorPage.selectedName = name
        monitorPage.openSelect = ""
        Monitors.lastError = ""
    }

    function closePanel() {
        monitorPage.selectedName = ""
        monitorPage.openSelect = ""
        Monitors.lastError = ""
    }

    // ---- formatting ------------------------------------------------------
    // "2560x1600@165.02" -> { w, h, r }. The mode strings carry no
    // "Hz" by the time they reach here (Monitors strips it, because
    // that is the form `hl.monitor` takes back).
    function parseMode(s) {
        var m = /^(\d+)x(\d+)@([\d.]+)$/.exec(String(s))
        if (!m)
            return null
        return { w: parseInt(m[1]), h: parseInt(m[2]), r: parseFloat(m[3]) }
    }

    function scaleText(s) {
        var n = Math.round(Number(s) * 100) / 100
        return String(n) + "\u00D7"
    }

    // ---- resolution, refresh and scale, as three option sets ------------
    // Hyprland reports a mode as "2560x1600@165.02" and takes it back in
    // that one string, but a display panel talks about the two halves
    // separately — a resolution and a refresh rate, the second's
    // contents depending on the first. These three functions are that
    // split, plus the join back into the string `hl.monitor` wants.

    // unique WxH, in the order availableModes lists them (the panel's
    // own preference order, which is usually biggest-first)
    function resolutions(m) {
        var out = []
        if (!m)
            return out
        var seen = {}
        for (var i = 0; i < m.modes.length; i++) {
            var p = monitorPage.parseMode(m.modes[i])
            if (!p)
                continue
            var key = p.w + "x" + p.h
            if (seen[key])
                continue
            seen[key] = true
            out.push(key)
        }
        return out
    }

    // the whole-Hz rates offered at a resolution, highest first. Grouped
    // by whole Hz because the list says 165.02 while the read reports
    // 165.019 — two decimals apart, the same refresh rate to anyone
    // reading this page, and one entry per rung keeps the list short.
    function rates(m, res) {
        var out = []
        if (!m || res.length === 0)
            return out
        var seen = {}
        for (var i = 0; i < m.modes.length; i++) {
            var p = monitorPage.parseMode(m.modes[i])
            if (!p || (p.w + "x" + p.h) !== res)
                continue
            var hz = Math.round(p.r)
            if (seen[hz])
                continue
            seen[hz] = true
            out.push(hz)
        }
        out.sort(function (a, b) { return b - a })
        return out
    }

    // the exact string for a (resolution, whole Hz) pair, or "" when
    // the pair is not offered — which is why nothing here guesses
    function modeString(m, res, hz) {
        if (!m || res.length === 0)
            return ""
        for (var i = 0; i < m.modes.length; i++) {
            var p = monitorPage.parseMode(m.modes[i])
            if (!p)
                continue
            if ((p.w + "x" + p.h) === res && Math.round(p.r) === hz)
                return m.modes[i]
        }
        return ""
    }

    function currentResolution(m) {
        return m ? m.width + "x" + m.height : ""
    }

    function currentHz(m) {
        return m ? Math.round(m.refreshRate) : 0
    }

    // The mode string picking a resolution would apply: the current
    // refresh rate when the new resolution offers it, otherwise the
    // highest it does — the alternative is a dropdown that silently
    // drops to 60Hz. "" when there is nothing to apply. Split out of
    // pickResolution so the decision can be probed without touching a
    // real output.
    function modeForResolution(m, res) {
        if (!m || res.length === 0)
            return ""
        var list = monitorPage.rates(m, res)
        if (list.length === 0)
            return ""
        var hz = monitorPage.currentHz(m)
        if (list.indexOf(hz) < 0)
            hz = list[0]
        return monitorPage.modeString(m, res, hz)
    }

    function pickResolution(m, res) {
        var mode = monitorPage.modeForResolution(m, res)
        if (mode.length > 0)
            Monitors.setMode(m.name, mode)
    }

    function pickHz(m, hz) {
        if (!m)
            return
        var mode = monitorPage.modeString(m, monitorPage.currentResolution(m), hz)
        if (mode.length > 0)
            Monitors.setMode(m.name, mode)
    }

    // ---- the option sets the dropdowns read ----------------------------
    // Each is `{ value, label }`, value being what `picked` hands back.
    // A live value that is not in its list is appended rather than
    // dropped, so a mode set outside this page still shows up as the
    // field's text instead of the field reading as blank.
    readonly property string selectedRes: monitorPage.selected
        ? monitorPage.currentResolution(monitorPage.selected) : ""

    // the live refresh rate and scale as the dropdowns' `current`
    // strings. Both go through the same rounding the options do, or a
    // 1.6000001 or a 165.019 would miss its own entry and the field
    // would fall back to the placeholder.
    readonly property string selectedHz: monitorPage.selected
        ? String(monitorPage.currentHz(monitorPage.selected)) : ""
    readonly property string selectedScale: monitorPage.selected
        ? String(Math.round(Number(monitorPage.selected.scale) * 100) / 100) : ""

    readonly property var resolutionOptions: {
        var m = monitorPage.selected
        if (!m)
            return []
        var list = monitorPage.resolutions(m)
        var out = []
        for (var i = 0; i < list.length; i++) {
            var p = list[i].split("x")
            out.push({ value: list[i], label: p[0] + "\u00D7" + p[1] })
        }
        if (monitorPage.selectedRes.length > 0
                && list.indexOf(monitorPage.selectedRes) < 0) {
            var q = monitorPage.selectedRes.split("x")
            out.unshift({ value: monitorPage.selectedRes,
                          label: q[0] + "\u00D7" + q[1] })
        }
        return out
    }

    readonly property var refreshOptions: {
        var m = monitorPage.selected
        if (!m)
            return []
        var list = monitorPage.rates(m, monitorPage.selectedRes)
        var out = []
        for (var i = 0; i < list.length; i++)
            out.push({ value: String(list[i]), label: list[i] + "Hz" })
        var live = String(monitorPage.currentHz(m))
        if (list.indexOf(monitorPage.currentHz(m)) < 0)
            out.unshift({ value: live, label: live + "Hz" })
        return out
    }

    readonly property var scaleOptions: {
        var m = monitorPage.selected
        var out = []
        var onLadder = false
        for (var i = 0; i < monitorPage.scaleLadder.length; i++) {
            var v = monitorPage.scaleLadder[i]
            if (m && Math.abs(v - m.scale) < 0.001)
                onLadder = true
            out.push({ value: String(v), label: monitorPage.scaleText(v) })
        }
        // a hand-set scale (1.7, say) is not a rung; show it as its own
        // entry rather than pretending it is the nearest one
        if (m && !onLadder) {
            var own = Math.round(Number(m.scale) * 100) / 100
            out.push({ value: String(own), label: monitorPage.scaleText(own) })
            out.sort(function (a, b) { return Number(a.value) - Number(b.value) })
        }
        return out
    }

    // where an output sits relative to a reference one, in LOGICAL
    // coordinates (the x/y in the read are already scaled). A rotated
    // output reports its physical mode size, so an odd transform
    // swaps the axes. "" means overlapping — which is what mirroring
    // looks like.
    function arrangement(m, ref) {
        if (!m || !ref || m.name === ref.name)
            return ""
        var mRot = (m.transform % 2) === 1
        var rRot = (ref.transform % 2) === 1
        var w = (mRot ? m.height : m.width) / m.scale
        var h = (mRot ? m.width : m.height) / m.scale
        var refW = (rRot ? ref.height : ref.width) / ref.scale
        var refH = (rRot ? ref.width : ref.height) / ref.scale
        if (m.x >= ref.x + refW)
            return "auto-right"
        if (m.x + w <= ref.x)
            return "auto-left"
        if (m.y >= ref.y + refH)
            return "auto-down"
        if (m.y + h <= ref.y)
            return "auto-up"
        return ""
    }

    // the output a monitor's arrangement is measured against: the
    // first other active one, so the panel does not depend on order
    function referenceFor(m) {
        if (!m)
            return null
        var list = Monitors.activeMonitors
        for (var i = 0; i < list.length; i++) {
            if (list[i].name !== m.name)
                return list[i]
        }
        return null
    }

    function detailLine(m) {
        if (!m)
            return ""
        if (m.disabled)
            return m.width + "\u00D7" + m.height + " \u00B7 disabled"
        var s = m.width + "\u00D7" + m.height + " @ "
            + Math.round(m.refreshRate) + "Hz \u00B7 " + monitorPage.scaleText(m.scale)
        if (m.mirrorOf.length > 0)
            s += " \u00B7 mirroring " + m.mirrorOf
        return s
    }

    function statusLine() {
        if (!Monitors.available)
            return "Reading displays\u2026"
        var n = Monitors.monitors.length
        if (n === 0)
            return "No displays connected"
        var s = (n === 1 ? "1 display" : n + " displays") + " connected"
        if (Monitors.mirroredCount > 0)
            s += " \u00B7 " + Monitors.mirroredCount + " mirrored"
        return s
    }

    // ---- the click-away catcher ------------------------------------------
    // A dropdown's list closes on a click anywhere else on the page. The
    // area is declared FIRST, so every control sits above it and takes
    // its own clicks — this only ever sees the empty card. It takes no
    // hover (a hover-enabled area here would steal cardZone's and
    // collapse the island), so it is invisible to the pointer until a
    // press lands on it.
    MouseArea {
        anchors.fill: parent
        onClicked: monitorPage.openSelect = ""
    }

    // ---- title row -------------------------------------------------------
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
            text: "// DISPLAYS"
            color: Theme.cardForeground
            font.family: Theme.barFontFamily
            font.pixelSize: 20
            font.weight: Font.DemiBold
        }
    }

    // ---- status line -----------------------------------------------------
    Text {
        id: statusText
        anchors.top: titleRow.bottom
        anchors.topMargin: 16
        anchors.left: parent.left
        anchors.leftMargin: 80
        anchors.right: statusError.left
        anchors.rightMargin: 12
        text: monitorPage.statusLine()
        color: Monitors.activeCount > 0 ? Theme.cardForeground : Theme.cardDim
        font.family: Theme.barFontFamily
        font.pixelSize: 13
        elide: Text.ElideRight
    }

    Text {
        id: statusError
        anchors.right: parent.right
        anchors.rightMargin: 28
        anchors.verticalCenter: statusText.verticalCenter
        width: Math.min(implicitWidth, 220)
        text: Monitors.lastError
        visible: text.length > 0
        color: Theme.barUrgent
        font.family: Theme.barFontFamily
        font.pixelSize: 12
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
    }

    // ---- the displays section --------------------------------------------
    Item {
        id: sectionLabel
        anchors.top: statusText.bottom
        anchors.topMargin: 16
        anchors.left: parent.left
        anchors.leftMargin: 80
        anchors.right: parent.right
        anchors.rightMargin: 28
        height: 20
        visible: monitorPage.selected === null

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Displays"
            color: Theme.cardForeground
            font.family: Theme.barFontFamily
            font.pixelSize: 14
        }

        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 20
            width: refreshLabel.implicitWidth + 24
            radius: 10
            color: Theme.cardHighlight

            Text {
                id: refreshLabel
                anchors.centerIn: parent
                text: "Refresh"
                color: Theme.cardForeground
                font.family: Theme.barFontFamily
                font.pixelSize: 12
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Monitors.refresh()
            }
        }
    }

    // ---- the list --------------------------------------------------------
    // Anchored to the label row above and the card's bottom margin
    // below, so it takes every pixel the header leaves. Rows scroll
    // past a partial one, which is the scroll affordance — there is no
    // scrollbar anywhere on this card.
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
        visible: monitorPage.selected === null

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: Theme.cardHighlight
        }

        ListView {
            id: displayList
            anchors.fill: parent
            // a fixed height off the card, never contentHeight: a view
            // whose height binds to its own content starts at zero,
            // instantiates no delegates, and can never grow
            clip: true
            cacheBuffer: 200
            boundsBehavior: Flickable.StopAtBounds
            model: Monitors.monitors

            delegate: Rectangle {
                required property var modelData
                required property int index

                // displayList.width, never ListView.width: with no id
                // on the view, ListView resolves to the TYPE object,
                // whose .width is undefined — the delegate silently
                // collapses to 0 wide
                width: displayList.width
                height: monitorPage.rowHeight
                color: "transparent"

                // the focused output's mark: a thin accent bar down
                // the plate's left edge, inside the straight run so it
                // never reaches the rounded corner. The wifi row's
                // connected marker.
                Rectangle {
                    x: 0
                    width: 3
                    height: 20
                    radius: 1.5
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.cardAccent
                    visible: modelData.focused
                }

                Text {
                    id: rowName
                    x: 14
                    y: 8
                    text: modelData.name
                    color: modelData.disabled ? Theme.cardDim : Theme.cardForeground
                    font.family: Theme.barFontFamily
                    font.pixelSize: 13
                    elide: Text.ElideRight
                    width: togglePill.x - x - 12
                }

                Text {
                    id: rowDetail
                    x: 14
                    y: rowName.y + rowName.height + 1
                    text: monitorPage.detailLine(modelData)
                    color: Theme.cardDim
                    opacity: modelData.disabled ? 0.7 : 1
                    font.family: Theme.barFontFamily
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    width: togglePill.x - x - 12
                }

                // ---- enable / disable --------------------------------
                // The radio pill's language at row scale. It dims —
                // rather than disappearing — on the last active
                // display, because taking the only screen away is the
                // one thing this page must not do.
                Rectangle {
                    id: togglePill

                    readonly property bool canToggle: modelData.disabled
                        || Monitors.activeCount > 1
                    readonly property bool lit: !modelData.disabled && canToggle

                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    height: 20
                    width: toggleLabel.implicitWidth + 24
                    radius: 10
                    color: lit ? Theme.cardAccent : Theme.cardHighlight

                    Text {
                        id: toggleLabel
                        anchors.centerIn: parent
                        text: modelData.disabled ? "Off" : "On"
                        color: togglePill.lit ? Theme.cardAccentOn
                            : (togglePill.canToggle ? Theme.cardForeground : Theme.cardDim)
                        font.family: Theme.barFontFamily
                        font.pixelSize: 12
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: togglePill.canToggle
                            ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: togglePill.canToggle
                        onClicked: Monitors.setDisabled(modelData.name,
                                                        !modelData.disabled)
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    // the pill has its own area and must win: declared
                    // before this one, so this one sits on top — inset
                    // it past the pill instead
                    anchors.rightMargin: 12 + togglePill.width
                    cursorShape: Qt.PointingHandCursor
                    onClicked: monitorPage.openPanel(modelData.name)
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 2
                    color: Theme.cardDim
                    opacity: 0.1
                    visible: index < displayList.count - 1
                }
            }
        }

        // the empty state shares the slot with the list, so it sits on
        // the plate rather than replacing it — the clipboard's own
        // treatment
        Text {
            anchors.top: parent.top
            anchors.topMargin: 10
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 20
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: displayList.count === 0
            text: Monitors.available
                ? "No displays connected." : "Reading displays\u2026"
            color: Theme.cardDim
            font.family: Theme.barFontFamily
            font.pixelSize: 13
        }
    }

    // ---- the detail panel ------------------------------------------------
    // Covers the label row and the list, the wifi page's password
    // panel: while an output is being configured, that output is what
    // the card is doing. Every control applies the moment it is
    // clicked — there is nothing to commit — so the floor carries the
    // two actions that are not a setting, and the way out is the back
    // chevron in the header.
    Rectangle {
        id: detailPanel
        anchors.top: statusText.bottom
        anchors.topMargin: 16
        anchors.left: parent.left
        anchors.leftMargin: 80
        anchors.right: parent.right
        anchors.rightMargin: 28
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        radius: 10
        color: Theme.cardHighlight
        visible: monitorPage.selected !== null

        // ---- header: back, name, state ------------------------------
        Item {
            id: panelHeader
            anchors.top: parent.top
            anchors.topMargin: 16
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.right: parent.right
            anchors.rightMargin: 16
            height: 20

            Item {
                id: panelBack
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 20

                Text {
                    anchors.centerIn: parent
                    text: "\uF053" // chevron-left
                    color: Theme.cardForeground
                    font.family: Theme.iconFont
                    font.pixelSize: 14
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: monitorPage.closePanel()
                }
            }

            Text {
                id: panelName
                anchors.left: panelBack.right
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: monitorPage.selected ? monitorPage.selected.name : ""
                color: Theme.cardForeground
                font.family: Theme.barFontFamily
                font.pixelSize: 17
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                width: panelState.left - x - 12
            }

            Text {
                id: panelState
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 140)
                text: {
                    if (!monitorPage.selected)
                        return ""
                    if (monitorPage.selected.disabled)
                        return "Disabled"
                    if (monitorPage.selected.mirrorOf.length > 0)
                        return "Mirrors " + monitorPage.selected.mirrorOf
                    return monitorPage.selected.focused ? "Primary" : ""
                }
                color: Theme.cardDim
                font.family: Theme.barFontFamily
                font.pixelSize: 12
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
            }
        }

        // ---- the controls -------------------------------------------
        // The theme page's control-row language: a 120px label column
        // and the control beside it, so every row starts on one line.
        Column {
            id: panelControls
            anchors.top: panelHeader.bottom
            // 8, not the 16 the header gap started at: this panel
            // carries SIX option rows (resolution, refresh, scale,
            // rotation, mirror, position) against the theme page's
            // three, in the same 400-tall card. Probed: six 26px rows
            // at 6 land 145..331 under a 20px header, with the floor at
            // 342 and 11px between them.
            anchors.topMargin: 8
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.right: parent.right
            anchors.rightMargin: 16
            // 6, not the control pages' 16: six rows of 26 plus five
            // gaps is 186, and the panel has 205 to give once the
            // header, the floor and the two 16px paddings are paid for.
            spacing: 6

            // ---- resolution ------------------------------------------
            // Three dropdowns where a stepper used to be. A display
            // panel talks about a mode's two halves separately, and a
            // real HDMI monitor reports twenty of them — no pill row
            // fits that, and a stepper hides every option but the two
            // beside the current one. Only the modes Hyprland listed
            // are offered: an unsupported one does not error, it
            // silently falls back (see Monitors.qml), so nothing here
            // guesses at a mode.
            Item {
                width: parent.width
                height: 26
                // the open list paints over the rows below it, and a
                // child's z reorders it among its own siblings, never
                // among its parent's — so the ROW is what lifts.
                z: monitorPage.openSelect === "resolution" ? 1 : 0

                Text {
                    id: resolutionLabel
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: monitorPage.labelColumn
                    text: "Resolution"
                    color: Theme.cardForeground
                    font.family: Theme.barFontFamily
                    font.pixelSize: 14
                }

                CardDropdown {
                    anchors.left: resolutionLabel.right
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: monitorPage.controlWidth
                    height: 26
                    options: monitorPage.resolutionOptions
                    current: monitorPage.selectedRes
                    open: monitorPage.openSelect === "resolution"
                    onToggleRequested: monitorPage.openSelect =
                        monitorPage.openSelect === "resolution" ? "" : "resolution"
                    onPicked: function (value) {
                        monitorPage.openSelect = ""
                        monitorPage.pickResolution(monitorPage.selected, value)
                    }
                }
            }

            // ---- refresh rate ----------------------------------------
            // The rates offered at the chosen resolution, highest first
            // and grouped by whole Hz: the mode string says 165.02 while
            // the read reports 165.019 — the same rate to anyone reading
            // this page, and one entry per rung keeps the list short.
            Item {
                width: parent.width
                height: 26
                z: monitorPage.openSelect === "refresh" ? 1 : 0

                Text {
                    id: refreshRateLabel
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: monitorPage.labelColumn
                    text: "Refresh"
                    color: Theme.cardForeground
                    font.family: Theme.barFontFamily
                    font.pixelSize: 14
                }

                CardDropdown {
                    anchors.left: refreshRateLabel.right
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: monitorPage.controlWidth
                    height: 26
                    options: monitorPage.refreshOptions
                    current: monitorPage.selectedHz
                    open: monitorPage.openSelect === "refresh"
                    onToggleRequested: monitorPage.openSelect =
                        monitorPage.openSelect === "refresh" ? "" : "refresh"
                    onPicked: function (value) {
                        monitorPage.openSelect = ""
                        monitorPage.pickHz(monitorPage.selected, Number(value))
                    }
                }
            }

            // ---- scale -----------------------------------------------
            // A ladder of the steps people actually pick, 1.6 included
            // because it is this machine's panel and a user has to be
            // able to get back to it. A scale set outside this page
            // (1.7, say) is appended as its own entry rather than shown
            // as the nearest rung it is not.
            Item {
                width: parent.width
                height: 26
                z: monitorPage.openSelect === "scale" ? 1 : 0

                Text {
                    id: scaleLabel
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: monitorPage.labelColumn
                    text: "Scale"
                    color: Theme.cardForeground
                    font.family: Theme.barFontFamily
                    font.pixelSize: 14
                }

                CardDropdown {
                    anchors.left: scaleLabel.right
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: monitorPage.controlWidth
                    height: 26
                    options: monitorPage.scaleOptions
                    current: monitorPage.selectedScale
                    open: monitorPage.openSelect === "scale"
                    onToggleRequested: monitorPage.openSelect =
                        monitorPage.openSelect === "scale" ? "" : "scale"
                    onPicked: function (value) {
                        monitorPage.openSelect = ""
                        Monitors.setScale(monitorPage.selectedName, Number(value))
                    }
                }
            }

            // ---- rotation -------------------------------------------            // 0 / 90 / 180 / 270. Hyprland also takes 4..7 for the
            // flipped variants, which this page does not offer — a flip
            // is not something a card should guess at. A flipped output
            // (transform 4..7) lights its base rotation, because the
            // rotation is the part these pills describe; clicking one
            // applies the unflipped form.
            Item {
                width: parent.width
                height: 26
                visible: monitorPage.selected !== null

                Text {
                    id: rotationLabel
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: monitorPage.labelColumn
                    text: "Rotation"
                    color: Theme.cardForeground
                    font.family: Theme.barFontFamily
                    font.pixelSize: 14
                }

                Row {
                    anchors.left: rotationLabel.right
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Repeater {
                        model: [0, 90, 180, 270]

                        Rectangle {
                            required property int modelData

                            readonly property bool active: monitorPage.selected
                                && (monitorPage.selected.transform % 4)
                                    === modelData / 90
                            height: 26
                            width: rotationPillLabel.implicitWidth + 24
                            radius: 8
                            color: active ? Theme.cardAccent : Theme.cardBackground

                            Text {
                                id: rotationPillLabel
                                anchors.centerIn: parent
                                text: modelData + "\u00B0"
                                color: parent.active
                                    ? Theme.cardAccentOn : Theme.cardForeground
                                font.family: Theme.barFontFamily
                                font.pixelSize: 12
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Monitors.setTransform(monitorPage.selectedName,
                                                                 modelData / 90)
                            }
                        }
                    }
                }
            }

            // ---- mirror ---------------------------------------------
            // Extend, or mirror onto one of the other ACTIVE outputs —
            // you cannot mirror onto something that is switched off,
            // so the row only exists once there is a target.
            Item {
                width: parent.width
                height: 26
                visible: monitorPage.selected !== null
                    && Monitors.mirrorTargets(monitorPage.selectedName).length > 0

                Text {
                    id: mirrorLabel
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: monitorPage.labelColumn
                    text: "Mirror"
                    color: Theme.cardForeground
                    font.family: Theme.barFontFamily
                    font.pixelSize: 14
                }

                Row {
                    anchors.left: mirrorLabel.right
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    // Extend: the off state of the mirror switch
                    Rectangle {
                        readonly property bool active: monitorPage.selected
                            && monitorPage.selected.mirrorOf.length === 0
                        height: 26
                        width: extendLabel.implicitWidth + 24
                        radius: 8
                        color: active ? Theme.cardAccent : Theme.cardBackground

                        Text {
                            id: extendLabel
                            anchors.centerIn: parent
                            text: "Extend"
                            color: parent.active ? Theme.cardAccentOn : Theme.cardForeground
                            font.family: Theme.barFontFamily
                            font.pixelSize: 12
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Monitors.setMirror(monitorPage.selectedName, "")
                        }
                    }

                    Repeater {
                        model: Monitors.mirrorTargets(monitorPage.selectedName)

                        Rectangle {
                            required property var modelData

                            readonly property bool active: monitorPage.selected
                                && monitorPage.selected.mirrorOf === modelData.name
                            height: 26
                            width: mirrorTargetLabel.implicitWidth + 24
                            radius: 8
                            color: active ? Theme.cardAccent : Theme.cardBackground

                            Text {
                                id: mirrorTargetLabel
                                anchors.centerIn: parent
                                text: modelData.name
                                color: parent.active
                                    ? Theme.cardAccentOn : Theme.cardForeground
                                font.family: Theme.barFontFamily
                                font.pixelSize: 12
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Monitors.setMirror(monitorPage.selectedName,
                                                              modelData.name)
                            }
                        }
                    }
                }
            }

            // ---- arrangement ----------------------------------------
            // Which side of the other display this one sits on. The
            // current side is read back off the two positions, so a
            // pill lights only when it describes where the output
            // actually is. Hidden while mirroring, where position is
            // meaningless.
            Item {
                width: parent.width
                height: 26
                visible: monitorPage.selected !== null
                    && monitorPage.selected.mirrorOf.length === 0
                    && monitorPage.referenceFor(monitorPage.selected) !== null

                readonly property var reference:
                    monitorPage.referenceFor(monitorPage.selected)
                readonly property string current: monitorPage.arrangement(
                    monitorPage.selected, reference)

                Text {
                    id: positionLabel
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: monitorPage.labelColumn
                    text: "Position"
                    color: Theme.cardForeground
                    font.family: Theme.barFontFamily
                    font.pixelSize: 14
                }

                Row {
                    anchors.left: positionLabel.right
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Repeater {
                        model: [
                            { label: "Left", preset: "auto-left" },
                            { label: "Right", preset: "auto-right" },
                            { label: "Above", preset: "auto-up" },
                            { label: "Below", preset: "auto-down" }
                        ]

                        Rectangle {
                            required property var modelData

                            readonly property bool active:
                                parent.parent.current === modelData.preset
                            height: 26
                            width: positionPillLabel.implicitWidth + 24
                            radius: 8
                            color: active ? Theme.cardAccent : Theme.cardBackground

                            Text {
                                id: positionPillLabel
                                anchors.centerIn: parent
                                text: modelData.label
                                color: parent.active
                                    ? Theme.cardAccentOn : Theme.cardForeground
                                font.family: Theme.barFontFamily
                                font.pixelSize: 12
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Monitors.setPosition(monitorPage.selectedName,
                                                                modelData.preset)
                            }
                        }
                    }
                }
            }
        }

        // ---- the floor: the two actions that are not a setting -------
        Row {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            anchors.right: parent.right
            anchors.rightMargin: 16
            spacing: 8

            Rectangle {
                readonly property bool canDisable: monitorPage.selected
                    && (monitorPage.selected.disabled || Monitors.activeCount > 1)
                height: 26
                width: disableLabel.implicitWidth + 28
                radius: 8
                color: Theme.cardBackground

                Text {
                    id: disableLabel
                    anchors.centerIn: parent
                    text: monitorPage.selected && monitorPage.selected.disabled
                        ? "Enable" : "Disable"
                    color: parent.canDisable ? Theme.cardForeground : Theme.cardDim
                    font.family: Theme.barFontFamily
                    font.pixelSize: 12
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: parent.canDisable
                        ? Qt.PointingHandCursor : Qt.ArrowCursor
                    enabled: parent.canDisable
                    onClicked: Monitors.setDisabled(monitorPage.selectedName,
                        !(monitorPage.selected && monitorPage.selected.disabled))
                }
            }

            Rectangle {
                readonly property bool canFocus: monitorPage.selected
                    && !monitorPage.selected.disabled
                    && !monitorPage.selected.focused
                height: 26
                width: focusLabel.implicitWidth + 28
                radius: 8
                color: canFocus ? Theme.cardAccent : Theme.cardBackground

                Text {
                    id: focusLabel
                    anchors.centerIn: parent
                    text: "Focus"
                    color: parent.canFocus ? Theme.cardAccentOn
                        : (monitorPage.selected && monitorPage.selected.focused
                           ? Theme.cardDim : Theme.cardForeground)
                    font.family: Theme.barFontFamily
                    font.pixelSize: 12
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: parent.canFocus
                        ? Qt.PointingHandCursor : Qt.ArrowCursor
                    enabled: parent.canFocus
                    onClicked: Monitors.focusMonitor(monitorPage.selectedName)
                }
            }
        }
    }
}
