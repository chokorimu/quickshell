// Capture.qml — the island's fourth menu: capture.
//
// Same card and pop as the media, volume, theme and session pages;
// reached by hovering the fourth tab button in the column. Three
// sections: screenshot (output / window / region), clipboard viewing,
// and screen recording.
//
// Step 2 wired the screenshot row: three pills, one grim chain each,
// saving to ~/Pictures/Screenshots and copying to the clipboard on
// the way out. Step 4 wired the record row to OBS over obs-websocket:
// one pill toggles StartRecord/StopRecord with the elapsed time
// beside it. Step 3 wired the clipboard row last and below the
// record button, at LO's request: a scrollable history read out of
// cliphist's db, one click copying an entry back.
//
// A later pass moved the layout onto the theme page's idiom without
// touching any behaviour: the screenshot and record sections became
// control rows — label in a fixed 120px column, the pills beside it —
// riding the content margins at 20 spacing, and the clipboard section
// reads label, hairline, list top to bottom. The theme page's own
// controls (the mode switch, the brightness slider) stayed there;
// only the layout language crossed over.
//
// The pills are click-only on purpose, the same rule the session and
// theme pages follow: a hover-enabled MouseArea in here steals
// cardZone's hover in Bar.qml and collapses the island under a
// resting cursor. Anything that needs hover later (a recording timer,
// say) has to report up through `hovered` the way SessionCard's power
// cells do.
import QtQml
import QtQuick
import Quickshell
import Quickshell.Io
import QtWebSockets
import "../../Theme"
// the header mark lives with the other cards; this is the first
// cross-module import in the tree, and it is circular with Bar.qml's
// own import of ../Capture — QML resolves both lazily, verified by
// load
import "../Bar"

Item {
    id: capturePage

    // Plumbing for Bar.qml's hover OR-in. Nothing on the page takes
    // hover of its own, so this stays false — but the pattern has to
    // exist before a section grows a hover-enabled control, or the
    // first one to ship collapses the island under the cursor.
    property bool hovered: false

    // title row — header mark + "Capture", left-aligned. The 80px
    // margin clears the menu column strip (56 wide), so nothing rides
    // it.
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
            text: "CAPTURE"
            color: Theme.cardForeground
            font.family: Theme.barFontFamily
            font.pixelSize: 20
            font.weight: Font.DemiBold
        }
    }

    // the sections, stacked under the header. Rides the content
    // area's margins both ways (80 left, 28 right) and spaces at 20 —
    // the theme page's controlColumn values, so the two pages read as
    // one system instead of two.
    Column {
        anchors.top: titleRow.bottom
        anchors.topMargin: 24
        anchors.left: parent.left
        anchors.leftMargin: 80
        anchors.right: parent.right
        anchors.rightMargin: 28
        spacing: 20

        // ---- screenshot: label + output / window / region -------------
        // Wired in step 2 to grim, which takes all three geometries:
        // the whole output, the active window's rectangle out of
        // hyprctl, or a slurp selection. The island dismisses itself
        // first — slurp takes the input grab, and a card caught
        // mid-pop would be in the frame.
        //
        // The row is the theme page's control-row idiom: a 40px Item
        // carrying the label in a fixed 120px column with the pills
        // beside it, so the label reads as a row header instead of a
        // caption floating over the controls. The pills themselves are
        // untouched — same surfaces, radii, glyphs and grim chains.
        Item {
            width: parent.width
            height: 40

            Text {
                id: shotLabel
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 120
                text: "Screenshot"
                color: Theme.cardForeground
                font.family: Theme.barFontFamily
                font.pixelSize: 14
            }

            Row {
                anchors.left: shotLabel.right
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Repeater {
                    model: ["Output", "Window", "Region"]

                    delegate: Rectangle {
                        id: shotPill
                        height: 36
                        // content-driven width — the label plus even
                        // side padding, so the three pills read as one
                        // family without hand-tuned numbers
                        width: shotPillLabel.implicitWidth + 36
                        radius: 18
                        color: Theme.cardHighlight

                        Text {
                            id: shotPillLabel
                            anchors.centerIn: parent
                            text: modelData
                            color: Theme.cardForeground
                            font.family: Theme.barFontFamily
                            font.pixelSize: 13
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: capturePage.shoot(modelData.toLowerCase())
                        }
                    }
                }
            }
        }

        // ---- record -----------------------------------------------------
        // Wired in step 4 to OBS over obs-websocket: one pill toggles
        // StartRecord/StopRecord, the elapsed time rides beside it,
        // and the state arrives as events — so a recording started
        // from OBS's own UI or a hotkey shows on the pill too.
        // wf-recorder is the alternative backend, not installed yet.
        //
        // Same control-row idiom as the screenshot section above:
        // label in the 120px column, the pill and its readout beside
        // it. The pill, the red-while-recording colour and the
        // elapsed/error Text are all unchanged.
        Item {
            width: parent.width
            height: 40

            Text {
                id: recLabel
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 120
                text: "Record"
                color: Theme.cardForeground
                font.family: Theme.barFontFamily
                font.pixelSize: 14
            }

            Row {
                anchors.left: recLabel.right
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Rectangle {
                    id: recPill
                    height: 36
                    // content-driven width like the screenshot pills —
                    // the label is the widest thing in the row, so the
                    // duration readout never moves the pill
                    width: recPillLabel.implicitWidth + 36
                    radius: 18
                    // recording reads as recording: the theme's red,
                    // the one color in the palette that means "live"
                    // without a legend
                    color: capturePage.recording ? Theme.barUrgent : Theme.cardHighlight

                    Text {
                        id: recPillLabel
                        anchors.centerIn: parent
                        text: capturePage.recording ? "Stop recording"
                            : (capturePage.obsConnected ? "Start recording" : "OBS offline")
                        color: capturePage.recording ? Theme.cardOnInk
                            : (capturePage.obsConnected ? Theme.cardForeground : Theme.cardDim)
                        font.family: Theme.barFontFamily
                        font.pixelSize: 13
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: capturePage.toggleRecord()
                    }
                }

                // the elapsed time while recording. The slot doubles
                // as the error readout, so a rejected request never
                // fails silently — the pill just sits there.
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: capturePage.obsError.length > 0 ? capturePage.obsError
                        : (capturePage.recording ? capturePage.fmtDuration(capturePage.recSeconds) : "")
                    color: capturePage.obsError.length > 0 ? Theme.barUrgent : Theme.cardDim
                    font.family: Theme.barFontFamily
                    font.pixelSize: 13
                }
            }
        }
    }

    // ---- clipboard: history -------------------------------------------
    // Below the record button, at LO's request, and anchored to the
    // card's bottom edge rather than flowed in the column above —
    // the theme page's wallpaper grid sits the same way, and it buys
    // the list every pixel the sections above leave it.
    //
    // wl-paste reads the current selection only, so the history
    // lives in cliphist's db, fed by `wl-paste --watch cliphist
    // store` from hyprland's autostart. This section lists it and
    // copies an entry back; cliphist owns the storing.
    //
    // Top to bottom it reads label, hairline, list — the hairline a
    // 1px Rectangle in cardHighlight across the content width, with
    // the Column's 8px spacing as the gap above and below it. A
    // Rectangle rather than a Canvas: a hairline is exactly what a
    // rect draws, and there is nothing here for a canvas to earn.
    Column {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        anchors.left: parent.left
        anchors.leftMargin: 80
        anchors.right: parent.right
        anchors.rightMargin: 28
        spacing: 8

        Text {
            text: "Clipboard"
            color: Theme.cardDim
            font.family: Theme.barFontFamily
            font.pixelSize: 12
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.cardHighlight
        }

        // the list's slot: a plain Item rather than the Column's own
        // child, because the empty message needs to fill the same
        // box and anchors are not allowed directly inside a Column.
        // The width is a binding, not an anchor, for the same reason:
        // a Column positions its children vertically and leaves the
        // width alone, so an unset width is 0 — and a 0-wide slot
        // renders neither the list nor the empty message.
        Item {
            width: parent.width
            height: 108

            ListView {
                id: clipList
                anchors.fill: parent
                // a fixed height off the card, never contentHeight: a
                // view whose height binds to its own content starts at
                // zero, instantiates no delegates, and can never grow
                clip: true
                cacheBuffer: 200
                boundsBehavior: Flickable.StopAtBounds
                // no scrollbar — the partial fourth row is the
                // affordance, same as the wallpaper grid
                model: capturePage.clipEntries

                delegate: Rectangle {
                    id: clipRow
                    required property var modelData

                    // clipList.width, never ListView.width: with no id
                    // on the view, ListView resolves to the TYPE
                    // object, whose .width is undefined — the delegate
                    // silently collapses to 0 wide, with no error
                    // logged
                    width: clipList.width
                    height: 30
                    color: "transparent"

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        text: clipRow.modelData.preview
                        elide: Text.ElideRight
                        // an image has no text to show, so cliphist's
                        // own marker stands in for the content and
                        // reads dim
                        color: clipRow.modelData.image ? Theme.cardDim : Theme.cardForeground
                        font.family: Theme.barFontFamily
                        font.pixelSize: 13
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: capturePage.pickClip(clipRow.modelData.id)
                    }
                }
            }

            // an empty db and a dead watcher read the same way, so
            // one message covers both
            Text {
                anchors.fill: parent
                anchors.leftMargin: 10
                visible: capturePage.clipEntries.length === 0
                text: "No history yet"
                verticalAlignment: Text.AlignVCenter
                color: Theme.cardDim
                font.family: Theme.barFontFamily
                font.pixelSize: 13
            }
        }
    }

    // ---- the screenshot machinery -------------------------------------
    // Three modes, three geometry sources, one capture: grim writes
    // the file, wl-copy takes it off disk straight after, and a
    // notification reports where it landed.
    //
    // hyprshot was the first choice and lost on evidence: it
    // backgrounds its grab (`begin_grab & checkRunning` on the last
    // line), so the main process exits about a second before the
    // screenshot exists and nothing downstream can chain off its
    // exit; its active-output lookup (`hyprctl -j monitors` filtered
    // by the active workspace id) comes up empty on this Lua-config
    // hyprland and silently degrades to `grim -g ""`, a full-screen
    // grab; and its freeze flag is a no-op here anyway because
    // hyprpicker is not installed. grim direct gives clean exits and
    // one code path for all three modes.
    //
    // The clipboard is wl-copy, which reads stdin — and QML's
    // Process has no file redirection — so that one step runs
    // through sh with the path single-quoted. The path is generated
    // here (a timestamp under ~/Pictures/Screenshots), so there is
    // nothing in it to escape.
    readonly property string screenshotDir: Quickshell.env("HOME")
        + "/Pictures/Screenshots"

    // A shot is a chain: a geometry source (slurp for region, hyprctl
    // for window, none for output), then grim to file + clipboard,
    // then the notification. chainBusy gates re-entry, and a click
    // landing mid-chain waits in `queued` — the same one-deep queue
    // Wallpapers uses, because `running = true` on a busy Process is
    // a silent no-op and the second click would vanish.
    property bool chainBusy: false
    property string queued: ""
    // the mode waiting on the dismissal timer, consumed when it fires
    property string pendingMode: ""
    // the file the running shot writes, for the notification
    property string lastPath: ""

    // Held from the pill click until the shot is actually on its
    // way. Bar.qml binds captureDismissing to this and holds the
    // island's collapse against the grace timer while it is set —
    // see the note there.
    property bool dismissing: false

    function shoot(mode) {
        if (chainBusy) {
            queued = mode
            return
        }
        pendingMode = mode
        chainBusy = true
        dismissing = true
        shotTimer.restart()
    }

    // The island has to be gone before the shot starts: the card
    // would be in the frame. The timer outlasts the 200ms pop-out
    // with margin, so the card — and the window's input mask with
    // it — is fully retracted before slurp takes the grab.
    Timer {
        id: shotTimer
        interval: 350
        onTriggered: {
            capturePage.startSource(capturePage.pendingMode)
            capturePage.dismissing = false
        }
    }

    function startSource(mode) {
        if (mode === "region")
            slurpProcess.running = true
        else if (mode === "window")
            windowProcess.running = true
        else
            capture("")
    }

    // region: slurp prints "x,y wxh" in logical pixels and exits 0,
    // or prints "selection cancelled" to stderr and exits 1
    Process {
        id: slurpProcess
        command: ["slurp"]
        stdout: StdioCollector { id: slurpOut }
        onExited: (exitCode) => {
            if (exitCode === 0 && slurpOut.text.trim().length > 0)
                capturePage.capture(slurpOut.text.trim())
            else
                capturePage.chainDone()
        }
    }

    // window: hyprctl's activewindow, {"at":[x,y],"size":[w,h]} in
    // the same logical convention slurp prints and grim -g eats
    Process {
        id: windowProcess
        command: ["hyprctl", "-j", "activewindow"]
        stdout: StdioCollector { id: windowOut }
        onExited: (exitCode) => {
            var geom = capturePage.windowGeometry(windowOut.text)
            if (exitCode === 0 && geom.length > 0)
                capturePage.capture(geom)
            else
                capturePage.chainDone()
        }
    }

    // An empty object (no focused window) has no at/size and yields
    // "", which drops the shot rather than grabbing the whole
    // screen — grim with no -g is the output mode's behaviour, not
    // something a missing window should fall back to.
    function windowGeometry(json) {
        try {
            var w = JSON.parse(json)
            if (!w.at || !w.size)
                return ""
            return w.at[0] + "," + w.at[1] + " " + w.size[0] + "x" + w.size[1]
        } catch (e) {
            return ""
        }
    }

    // grim writes the file, wl-copy takes it off disk straight
    // after — chained with && so a failed capture never reaches the
    // clipboard.
    function capture(geometry) {
        var path = screenshotDir + "/" + timestamp() + ".png"
        var cmd = "grim"
        if (geometry.length > 0)
            cmd += " -g '" + geometry + "'"
        cmd += " '" + path + "' && wl-copy --type image/png < '" + path + "'"
        captureProcess.command = ["/bin/sh", "-c", cmd]
        captureProcess.running = true
        lastPath = path
    }

    Process {
        id: captureProcess
        onExited: (exitCode) => {
            if (exitCode === 0 && capturePage.lastPath.length > 0) {
                notifyProcess.command = ["notify-send", "Screenshot saved",
                    capturePage.lastPath]
                notifyProcess.running = true
            }
            capturePage.chainDone()
        }
    }

    Process {
        id: notifyProcess
    }

    function chainDone() {
        chainBusy = false
        if (queued.length > 0) {
            var next = queued
            queued = ""
            // the queued shot goes back through shoot(), not
            // straight to startSource: the island may have
            // reopened under the cursor while the first chain ran,
            // and its card would be in this frame too — so the
            // queued mode gets the same dismissal wait a fresh
            // click gets
            shoot(next)
        }
    }

    // the same shape hyprland's own screenshot keybinds use
    // (date +%Y-%m-%d-%H%M%S), so the island's shots and the
    // keybind's shots sort together in the directory. A second shot
    // inside the same second — which the one-deep queue makes
    // routine — would otherwise reuse the name and the first file
    // would be overwritten, so a repeat inside one second takes a
    // -2, -3 ... suffix.
    property string lastStamp: ""
    property int lastStampCount: 0

    function timestamp() {
        var d = new Date()
        var pad = function (n) { return (n < 10 ? "0" : "") + n }
        var stamp = d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate())
            + "-" + pad(d.getHours()) + pad(d.getMinutes()) + pad(d.getSeconds())
        if (stamp === lastStamp) {
            lastStampCount++
            return stamp + "-" + lastStampCount
        }
        lastStamp = stamp
        lastStampCount = 1
        return stamp
    }

    // ---- the OBS client -----------------------------------------------
    // The record row's backend: obs-websocket 5.x over a plain
    // WebSocket. On connect the server sends Hello (op 0), the client
    // answers Identify (op 1) — with auth off there is no
    // challenge-response to compute, which is the whole reason the
    // localhost port runs unauthenticated, since 5.x auth is a SHA256
    // handshake QML's JS cannot do — and the server replies Identified
    // (op 2). From there it is requests (op 6) with responses (op 7),
    // plus events (op 5) the server pushes on its own.
    //
    // The CLI route (obs --startrecording) was the alternative and
    // lost on readback: it is a start button with no way to ask OBS
    // what it is doing, so the pill could never know when to say
    // "stop". The socket gives both directions.
    //
    // The socket lives for the shell's whole life — this page is a
    // persistent instance behind a visible flag, not a Loader — so
    // the connection is up before the capture page is ever opened,
    // and a recording started elsewhere still shows on the pill.
    readonly property string obsUrl: "ws://127.0.0.1:4455"

    // Identified received: the handshake is done and requests will be
    // answered
    property bool obsConnected: false
    property bool recording: false
    property int recSeconds: 0
    // a rejected request's comment, shown in the duration slot for a
    // few seconds
    property string obsError: ""
    property int obsReqId: 0

    WebSocket {
        id: obsSocket
        url: capturePage.obsUrl
        active: true

        onStatusChanged: (status) => {
            // 0 connecting, 1 open, 2 closing, 3 closed, 4 error —
            // the enum is not in the qmltypes, so the numbers are
            // spelled out here rather than referenced by name. Only
            // a dead socket arms the retry: a connecting one is
            // already on its way, and arming on the initial
            // Connecting would bounce a healthy connection at the
            // five-second mark.
            if (status === 3 || status === 4) {
                capturePage.obsConnected = false
                capturePage.scheduleObsRetry()
            }
        }

        onTextMessageReceived: (text) => {
            var msg
            try {
                msg = JSON.parse(text)
            } catch (e) {
                return
            }
            var d = msg.d || {}
            if (msg.op === 0) {
                // Hello: identify. No authentication field when the
                // server runs with auth off, and the default
                // subscription covers every non-high-volume category,
                // which includes the Outputs events the record state
                // rides on
                obsSocket.sendTextMessage(JSON.stringify({
                    op: 1,
                    d: { rpcVersion: 1 }
                }))
            } else if (msg.op === 2) {
                capturePage.obsConnected = true
                obsRetry.stop()
                capturePage.obsError = ""
                // sync the state OBS is already in — it may have been
                // recording since before the shell started
                capturePage.obsRequest("GetRecordStatus")
            } else if (msg.op === 7) {
                capturePage.onObsResponse(d)
            } else if (msg.op === 5) {
                if (d.eventType === "RecordStateChanged") {
                    var active = d.eventData && d.eventData.outputActive === true
                    // the stop event carries the saved file's path
                    if (!active && d.eventData && d.eventData.outputPath)
                        capturePage.notifySaved(d.eventData.outputPath)
                    capturePage.setRecording(active)
                }
            }
        }
    }

    function obsRequest(type) {
        if (!obsConnected)
            return
        obsReqId++
        obsSocket.sendTextMessage(JSON.stringify({
            op: 6,
            d: { requestType: type, requestId: "" + obsReqId }
        }))
    }

    function onObsResponse(d) {
        if (!d.requestStatus || d.requestStatus.result !== true) {
            capturePage.obsError = (d.requestStatus && d.requestStatus.comment)
                || "request failed"
            obsErrorTimer.restart()
            return
        }
        if (d.requestType === "GetRecordStatus" && d.responseData)
            capturePage.setRecording(d.responseData.outputActive === true,
                d.responseData.outputDuration)
    }

    // The event and the status response agree on the shape; the
    // duration only comes from the status response, so it seeds the
    // counter and the event leaves it alone. A state change is also
    // proof the last request landed, so it clears the error readout
    // rather than leaving a stale comment up for the timer.
    function setRecording(active, duration) {
        if (active === capturePage.recording && duration === undefined)
            return
        capturePage.recording = active
        capturePage.obsError = ""
        if (active)
            capturePage.recSeconds = (duration !== undefined && duration > 0)
                ? Math.floor(duration) : 0
    }

    function toggleRecord() {
        if (!obsConnected) {
            // OBS is down (or still starting): retry now rather than
            // making the click wait out the retry timer
            capturePage.reconnectObs()
            return
        }
        capturePage.obsRequest(capturePage.recording ? "StopRecord" : "StartRecord")
    }

    // The QML WebSocket has no open() — active is the only handle —
    // so a retry is a bounce: off aborts the dead socket, on opens a
    // fresh one. Five seconds matches the cadence the other pollers
    // run at, and a refused local connect costs nothing.
    Timer {
        id: obsRetry
        interval: 5000
        onTriggered: capturePage.reconnectObs()
    }

    function scheduleObsRetry() {
        obsRetry.restart()
    }

    function reconnectObs() {
        obsSocket.active = false
        obsSocket.active = true
    }

    Timer {
        id: obsErrorTimer
        interval: 4000
        onTriggered: capturePage.obsError = ""
    }

    // one tick a second while the recorder runs; the binding keeps it
    // stopped the rest of the time
    Timer {
        interval: 1000
        repeat: true
        running: capturePage.recording
        onTriggered: capturePage.recSeconds++
    }

    function fmtDuration(s) {
        var h = Math.floor(s / 3600)
        var m = Math.floor((s % 3600) / 60)
        var sec = s % 60
        var pad = function (n) { return (n < 10 ? "0" : "") + n }
        return (h > 0 ? h + ":" : "") + pad(m) + ":" + pad(sec)
    }

    Process {
        id: obsNotifyProcess
    }

    function notifySaved(path) {
        obsNotifyProcess.command = ["notify-send", "Recording saved", path]
        obsNotifyProcess.running = true
    }

    // ---- the clipboard history ----------------------------------------
    // cliphist owns the db; this reads it. `cliphist list` prints one
    // entry per line as `<id>\t<preview>`, newest first, with images
    // standing in as `[[ binary data 86 B png 23x23 ]]` and long
    // lines cut at cliphist's preview width. Decoding pipes the raw
    // entry back through wl-copy, which sniffs the type — a PNG
    // lands back on the clipboard as image/png, so the screenshot
    // row's copies round-trip too.
    property var clipEntries: []

    function onClipList(text) {
        var out = []
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
            // the id is everything before the first tab; a preview
            // may itself contain tabs, and a line without one is
            // cliphist's "please store something first" notice
            var tab = lines[i].indexOf("\t")
            if (tab < 0)
                continue
            var preview = lines[i].substring(tab + 1)
            out.push({
                id: lines[i].substring(0, tab),
                preview: preview,
                image: preview.indexOf("[[ binary data") === 0
            })
        }
        capturePage.clipEntries = out
    }

    // The page is a persistent instance behind a visible flag, so
    // the refresh rides the visibility Bar.qml toggles: the list is
    // read fresh every time the capture page opens.
    onVisibleChanged: if (visible) clipListProcess.running = true

    function pickClip(id) {
        // the id comes out of cliphist's own output, but it lands in
        // a shell command, so it is checked rather than trusted
        if (!/^\d+$/.test(id))
            return
        clipDecodeProcess.command = ["sh", "-c", "cliphist decode " + id + " | wl-copy"]
        clipDecodeProcess.running = true
    }

    Process {
        id: clipListProcess
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: capturePage.onClipList(this.text)
        }
    }

    Process {
        id: clipDecodeProcess
    }
}
