// Capture.qml — the island's fourth menu: capture.
//
// Same card and pop as the media, volume, theme and session pages;
// reached by hovering the fourth tab button in the column. Three
// sections: screenshot (output / window / region), clipboard viewing,
// and screen recording.
//
// Step 2 wired the screenshot row: three pills, one grim chain each,
// saving to ~/Pictures/Screenshots and copying to the clipboard on
// the way out. The clipboard and record sections are still
// placeholders, each noting the step that wires it.
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

    // the sections, stacked under the header and left-aligned on the
    // content area's margin, the way the volume and theme pages flow
    Column {
        anchors.top: titleRow.bottom
        anchors.topMargin: 24
        anchors.left: parent.left
        anchors.leftMargin: 80
        spacing: 28

        // ---- screenshot: output / window / region ----------------------
        // Wired in step 2 to grim, which takes all three geometries:
        // the whole output, the active window's rectangle out of
        // hyprctl, or a slurp selection. The island dismisses itself
        // first — slurp takes the input grab, and a card caught
        // mid-pop would be in the frame.
        Column {
            anchors.left: parent.left
            spacing: 10

            Text {
                text: "Screenshot"
                color: Theme.cardDim
                font.family: Theme.barFontFamily
                font.pixelSize: 12
            }

            Row {
                anchors.left: parent.left
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

        // ---- clipboard --------------------------------------------------
        // Step 3 wires this. wl-paste reads the current selection only,
        // so real history needs cliphist installed and running
        // (wl-paste --watch cliphist store as a hypr exec-once).
        Column {
            anchors.left: parent.left
            spacing: 10

            Text {
                text: "Clipboard"
                color: Theme.cardDim
                font.family: Theme.barFontFamily
                font.pixelSize: 12
            }

            Row {
                anchors.left: parent.left
                spacing: 8

                Rectangle {
                    id: clipPill
                    height: 36
                    width: clipPillLabel.implicitWidth + 36
                    radius: 18
                    color: Theme.cardHighlight

                    Text {
                        id: clipPillLabel
                        anchors.centerIn: parent
                        text: "View history"
                        color: Theme.cardForeground
                        font.family: Theme.barFontFamily
                        font.pixelSize: 13
                    }

                    MouseArea {
                        anchors.fill: parent
                        // placeholder — step 3
                        onClicked: {}
                    }
                }
            }
        }

        // ---- record -----------------------------------------------------
        // Step 4 wires this to wf-recorder, started and stopped from
        // the same pill, with the elapsed time beside it. wf-recorder
        // is not installed yet. OBS is the alternative backend — see
        // the streaming note below.
        Column {
            anchors.left: parent.left
            spacing: 10

            Text {
                text: "Record"
                color: Theme.cardDim
                font.family: Theme.barFontFamily
                font.pixelSize: 12
            }

            Row {
                anchors.left: parent.left
                spacing: 8

                Rectangle {
                    id: recPill
                    height: 36
                    width: recPillLabel.implicitWidth + 36
                    radius: 18
                    color: Theme.cardHighlight

                    Text {
                        id: recPillLabel
                        anchors.centerIn: parent
                        text: "Start recording"
                        color: Theme.cardForeground
                        font.family: Theme.barFontFamily
                        font.pixelSize: 13
                    }

                    MouseArea {
                        anchors.fill: parent
                        // placeholder — step 4
                        onClicked: {}
                    }
                }
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
}
