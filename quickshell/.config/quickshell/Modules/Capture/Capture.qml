// Capture.qml — the island's fifth menu: capture.
//
// Same card and pop as the media, usage, volume, theme and session
// pages; reached by hovering the fifth tab button in the column. Three
// sections: screenshot (output / window / region), clipboard viewing,
// and screen recording.
//
// Step 2 wired the screenshot row: three pills, one hyprshot each,
// saving to ~/Pictures/Screenshots and copying to the clipboard on
// the way out. Step 4 wired the record row to OBS over obs-websocket:
// one pill toggles StartRecord/StopRecord with the elapsed time
// beside it — and while OBS is down the pill steps aside for a dim
// "OBS offline" line with the bar's ban glyph beside it, since a
// dead backend has nothing to toggle.
// Step 3 wired the clipboard row last and below the
// record button, at LO's request: a scrollable history read out of
// cliphist's db, one click copying an entry back, one Reset pill
// wiping it.
//
// A later pass moved the layout onto the theme page's idiom without
// touching any behaviour: the screenshot and record sections became
// control rows — label in a fixed 120px column, the pills beside it —
// riding the content margins at 16 spacing, and the clipboard section
// reads label, list top to bottom — the label in the other sections'
// style with a Reset pill on its right, and the 1px hairline that
// used to sit under the label removed. The theme page's own
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
            text: "// CAPTURE"
            color: Theme.cardForeground
            font.family: Theme.barFontFamily
            font.pixelSize: 20
            font.weight: Font.DemiBold
        }
    }

    // the sections, stacked under the header. Rides the content
    // area's margins both ways (80 left, 28 right) and spaces at 16 —
    // the theme page's controlColumn value, so the two pages read as
    // one system instead of two.
    Column {
        anchors.top: titleRow.bottom
        anchors.topMargin: 24
        anchors.left: parent.left
        anchors.leftMargin: 80
        anchors.right: parent.right
        anchors.rightMargin: 28
        spacing: 16

        // ---- screenshot: label + output / window / region -------------
        // Wired in step 2 to hyprshot, which takes all three geometries
        // itself: the active output, the active window, or a slurp
        // selection. The island dismisses itself first — slurp takes
        // the input grab, and a card caught mid-pop would be in the
        // frame.
        //
        // The row is the theme page's control-row idiom: a 40px Item
        // carrying the label in a fixed 120px column with the pills
        // beside it, so the label reads as a row header instead of a
        // caption floating over the controls. The pills themselves are
        // untouched — same surfaces, radii, glyphs and hyprshot modes.
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
        // Wired in step 4 to OBS over obs-websocket: the record pill
        // toggles StartRecord/StopRecord, the stream pill beside it
        // StartStream/StopStream, the elapsed time rides under them,
        // and the state arrives as events — so a recording or
        // stream started from OBS's own UI or a hotkey shows on the
        // pills too. wf-recorder is the alternative backend, not
        // installed yet.
        //
        // The screenshot section's control-row idiom, with the readout
        // demoted: label in the 120px column, the pills beside it, and
        // the elapsed/error Text anchored under the pills rather than
        // riding in the row at their right (LO's call — beside them it
        // read as a third control in the row, under them it reads as
        // the running state of whichever is live). The pills, the
        // red-while-recording and blue-while-streaming colours and the
        // Text's own binding are all unchanged from the single-pill
        // pass.
        //
        // OBS offline: both pills disappear entirely and a dim "OBS
        // offline" line takes their slot — LO's call. A dead backend
        // has nothing to toggle, and the 5s retry timer already
        // reconnects, so the pills' old click-to-retry job was
        // covered anyway; the slot reads as status instead of
        // wearing a dead button. The ban glyph beside the text is
        // the bar's own disconnected mark — the network readout
        // wears the same one — so the state reads identically in
        // both places.
        Item {
            width: parent.width
            // 56, not 40: the elapsed time moved below the pills at
            // LO's call, so the row carries the 36px pill stack, a 4px
            // gap and the ~16px readout under it. The clipboard slot
            // gives up the same 16 (167→151) to keep the gap under
            // this row at the uniform 16.
            height: 56

            Text {
                id: recLabel
                anchors.left: parent.left
                // centred on the pills, not the row: the readout hangs
                // below them, and centring against the whole 56px
                // stack would drop the label 10px under the pills' own
                // centre line
                anchors.verticalCenter: recPills.verticalCenter
                width: 120
                text: "Record"
                color: Theme.cardForeground
                font.family: Theme.barFontFamily
                font.pixelSize: 14
            }

            Row {
                id: recPills
                anchors.left: recLabel.right
                anchors.leftMargin: 12
                anchors.top: parent.top
                spacing: 8

                Rectangle {
                    id: recPill
                    // gone while OBS is down — the dim line below takes
                    // the slot. `|| recording` keeps it up if the socket
                    // drops mid-recording, so a stale live state can
                    // still be stopped
                    visible: capturePage.obsConnected || capturePage.recording
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
                        // no offline branch any more: the pill is only
                        // ever up when there is a backend to talk to
                        text: capturePage.recording ? "Stop recording" : "Start recording"
                        color: capturePage.recording ? Theme.cardOnInk : Theme.cardForeground
                        font.family: Theme.barFontFamily
                        font.pixelSize: 13
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: capturePage.toggleRecord()
                    }
                }

                // the stream pill — the record pill's twin, one state
                // over. Same shape, same visibility rule (`|| streaming`
                // so a socket drop mid-stream stays stoppable), and the
                // same content-driven width. Blue while live, the one
                // other color that reads as "live" without a legend;
                // recording took the palette's red, so streaming gets a
                // fixed blue that reads on both card surfaces.
                Rectangle {
                    id: streamPill
                    visible: capturePage.obsConnected || capturePage.streaming
                    height: 36
                    width: streamPillLabel.implicitWidth + 36
                    radius: 18
                    color: capturePage.streaming ? Theme.cardStream : Theme.cardHighlight

                    Text {
                        id: streamPillLabel
                        anchors.centerIn: parent
                        text: capturePage.streaming ? "Stop streaming" : "Start streaming"
                        color: capturePage.streaming ? Theme.cardStreamOn : Theme.cardForeground
                        font.family: Theme.barFontFamily
                        font.pixelSize: 13
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: capturePage.toggleStream()
                    }
                }

                // the offline stand-in, sitting exactly where the pills
                // were — the Row collapses the hidden pills, so this
                // lands on the left with nothing to do. The ban glyph
                // is the bar's own disconnected mark (the network
                // readout wears the same one), so the offline state
                // reads the same way here as it does out there.
                Row {
                    visible: !capturePage.obsConnected && !capturePage.recording && !capturePage.streaming
                    spacing: 6

                    Text {
                        id: offGlyph
                        text: "\uF05E" // ban
                        color: Theme.cardDim
                        font.family: Theme.iconFont
                        font.pixelSize: 14
                    }

                    Text {
                        id: offText
                        text: "OBS offline"
                        color: Theme.cardDim
                        font.family: Theme.barFontFamily
                        font.pixelSize: 13
                        // A Row top-aligns its children, and the two
                        // fonts' line boxes differ — the icon font's
                        // runs ~19 at 14px against the UI font's ~16
                        // at 13px — so both started at the row's top
                        // and the glyph's ink sat ~1.6px below the
                        // text's. Taking the glyph's line box as the
                        // shared height and centring the text's ink
                        // inside it puts both on one line: measured
                        // off the font files, the ban's ink centre is
                        // 0.360em over its baseline against the
                        // string's 0.381em, so once the boxes match
                        // the two centres land 0.3px apart —
                        // sub-pixel, and the eye reads one line.
                        height: offGlyph.height
                        verticalAlignment: Text.AlignVCenter
                    }
                }

            }

            // the elapsed time while recording, or the stream's while
            // streaming — one readout, and recording wins when both are
            // live. It moved below the pills at LO's call: beside them
            // it read as a third control in the row, under them it
            // reads as the running state of whichever is live. The
            // slot doubles as the error readout, so a rejected request
            // never fails silently — the pills just sit there.
            Text {
                id: recElapsed
                anchors.left: recPills.left
                anchors.top: recPills.bottom
                anchors.topMargin: 4
                text: capturePage.obsError.length > 0 ? capturePage.obsError
                    : (capturePage.recording ? capturePage.fmtDuration(capturePage.recSeconds)
                        : (capturePage.streaming ? capturePage.fmtDuration(capturePage.streamSeconds) : ""))
                color: capturePage.obsError.length > 0 ? Theme.barUrgent : Theme.cardDim
                font.family: Theme.barFontFamily
                font.pixelSize: 13
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
    // Top to bottom it reads label, list. The label takes the other
    // sections' styling — cardForeground at 14, not the dim 12 this
    // section started with — and carries a Reset pill on its right
    // that wipes the db through cliphist's own wipe and re-reads the
    // list. The 1px hairline that sat under the label is gone: once
    // the label matched the others, the ruler was the one thing left
    // styling this section differently.
    Column {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        anchors.left: parent.left
        anchors.leftMargin: 80
        anchors.right: parent.right
        anchors.rightMargin: 28
        spacing: 8

        // the label row: title on the left in the other sections'
        // style, Reset on the right. An Item with an explicit height
        // because a Column leaves its children's height alone, and
        // anchors are illegal directly inside one — the same reason
        // the list's slot below is an Item.
        Item {
            width: parent.width
            height: 20

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Clipboard"
                color: Theme.cardForeground
                font.family: Theme.barFontFamily
                font.pixelSize: 14
            }

            // Reset is destructive — it wipes every entry — so it is
            // deliberately the smallest pill on the page, sat out of
            // the way on the label's right rather than in the control
            // column where the other sections' pills live. Click-only
            // like every MouseArea in here.
            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 20
                width: clipResetLabel.implicitWidth + 24
                radius: 10
                color: Theme.cardHighlight

                Text {
                    id: clipResetLabel
                    anchors.centerIn: parent
                    text: "Reset"
                    color: Theme.cardForeground
                    font.family: Theme.barFontFamily
                    font.pixelSize: 12
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: capturePage.resetClipboard()
                }
            }
        }

        // the list's slot: a plain Item rather than the Column's own
        // child, because the empty message shares the box and
        // anchors are not allowed directly inside a Column.
        // The width is a binding, not an anchor, for the same reason:
        // a Column positions its children vertically and leaves the
        // width alone, so an unset width is 0 — and a 0-wide slot
        // renders neither the list nor the empty message.
        Item {
            width: parent.width
            // 151, not 108. The column is bottom-anchored, so every
            // pixel added here lifts its top edge by one and eats the
            // dead card between the record row and the clipboard
            // label. Measured baseline: the sections Column spaces at
            // 16, which puts the record row's bottom at y173, and the
            // column is exactly children-driven (20 label row + 8 +
            // slot — the hairline that used to add 1 + 8 is gone), so
            // its top edge sits at 384 - (28 + slot) = 356 - slot.
            // 356 - 151 = 205 lands the label at y205, a 16px gap
            // under the record row. The row grew 40→56 when the
            // elapsed moved below the pills (LO's call), so the slot
            // gave up the same 16 to hold the gap — the list shows
            // exactly five rows now instead of five plus a peek, and
            // still scrolls past that.
            height: 151

            // The list's plate: the section's own surface, square-
            // cornered at LO's call. Square rather than the shell's
            // usual pill for two reasons — the dividers run edge to
            // edge, and a rounded plate would put their ends on the
            // curve — and a list panel reads as a panel, not as one
            // more control. cardHighlight is the token every other
            // control on the card already wears, so the plate reads
            // as one more surface rather than a new idea; the
            // dividers cut back to cardBackground, which reads as a
            // groove (darker than the plate in the dark palette,
            // lighter in the light one) instead of a drawn line.
            Rectangle {
                anchors.fill: parent
                color: Theme.cardHighlight
            }

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
                    // the row's own index, so the divider knows which
                    // row is the last — a trailing hairline under the
                    // final entry would read as a border the list
                    // does not have
                    required property int index

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

                    // the divider, edge to edge at the row's foot —
                    // the settings-list idiom, and the reason the
                    // plate is square. cardBackground rather than
                    // cardHighlight: on a cardHighlight plate a
                    // cardHighlight line would be invisible, and the
                    // card's own surface cutting through reads as a
                    // groove in both palettes
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: Theme.cardBackground
                        visible: index < clipList.count - 1
                    }
                }
            }

            // an empty db and a dead watcher read the same way, so
            // one message covers both. Top centre, not filling the
            // slot: a line floating in the middle of a 167px empty
            // box reads as lost, while one at the top reads as
            // "nothing here yet" at the head of the list, where the
            // first entry would land.
            Text {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                visible: capturePage.clipEntries.length === 0
                text: "No history yet"
                color: Theme.cardDim
                font.family: Theme.barFontFamily
                font.pixelSize: 13
            }
        }
    }

    // ---- the screenshot machinery -------------------------------------
    // One hyprshot per shot. hyprshot does the geometry itself —
    // slurp for region, hyprctl's activewindow for window, its own
    // active-output lookup for output — then grim, then wl-copy, then
    // its own notification, so the three-process chain the grim
    // version ran by hand collapses into one argv with no shell and
    // no redirection anywhere.
    //
    // hyprshot was the first choice here and lost on evidence, all of
    // which has since been re-measured and overturned: it backgrounds
    // its grab (`begin_grab & checkRunning` on the last line), so the
    // main process exits about a second before the screenshot exists
    // — still true, and harmless, because nothing downstream needs
    // the file at exit (the notification is hyprshot's own, and the
    // only thing chained off the exit is the queue release, which
    // the 350ms dismiss timer pushes a further 350ms out anyway);
    // its active-output lookup (`hyprctl -j monitors` filtered by the
    // active workspace id) used to come up empty on this Lua-config
    // hyprland and silently degrade to `grim -g ""` — it now returns
    // 0,0 1600x1000, verified; and its freeze flag was a no-op
    // because hyprpicker was not installed — it is now, and the
    // freeze/unfreeze cycle probes clean in both the shot and the
    // cancel path.
    //
    // The exit code is ignored for the same family of reasons:
    // without -z, checkRunning's `pkill hyprpicker` matches nothing
    // and the script's `set -e` turns that into exit 1 on every
    // successful shot (with -z it exits 0). A cancelled region shot
    // exits 1 too, and both cases want the same thing — release the
    // chain, write nothing.
    readonly property string screenshotDir: Quickshell.env("HOME")
        + "/Pictures/Screenshots"

    // A shot is a chain: the dismissal wait, then one hyprshot, then
    // the release. chainBusy gates re-entry, and a click landing
    // mid-chain waits in `queued` — the same one-deep queue
    // Wallpapers uses, because `running = true` on a busy Process is
    // a silent no-op and the second click would vanish.
    property bool chainBusy: false
    property string queued: ""
    // the mode waiting on the dismissal timer, consumed when it fires
    property string pendingMode: ""

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

    // One hyprshot per mode. `-m active` is hyprshot's own active
    // window/output lookup (a second -m after the selection mode),
    // which replaces both hand-rolled geometry sources: hyprctl's
    // activewindow JSON parse for window, and nothing-at-all for
    // output. Region keeps hyprshot's internal slurp.
    //
    // -z (freeze) is region-only, and only now possible at all:
    // hyprpicker is installed, so hyprshot's `hyprpicker -r -z &`
    // actually freezes, and checkRunning pkills it the moment slurp
    // exits — verified in both the shot and the cancel path, no
    // strays either way. It is region-only because that is the one
    // mode where the screen moves under the cursor mid-selection;
    // output and window grab whatever is there the instant they run.
    //
    // -f carries this page's own timestamp rather than hyprshot's
    // default `%Y-%m-%d-%H%M%S_hyprshot.png`, so the island's shots
    // keep the bare shape hyprland's own screenshot keybinds use and
    // sort together with them in the directory — and keep the -2/-3
    // suffix when a second shot lands in the same second, which the
    // one-deep queue makes routine.
    function startSource(mode) {
        var args = ["hyprshot", "-m"]
        if (mode === "region")
            args.push("region", "-z")
        else if (mode === "window")
            args.push("window", "-m", "active")
        else
            args.push("output", "-m", "active")
        args.push("-o", screenshotDir, "-f", timestamp() + ".png")
        captureProcess.command = args
        captureProcess.running = true
    }

    // The only job left at the exit is releasing the chain: the file,
    // the clipboard and the notification are all hyprshot's own work
    // in its backgrounded grab, and none of them report back here.
    Process {
        id: captureProcess
        onExited: capturePage.chainDone()
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
    // the stream's mirror of the two above — same event/status shape,
    // different output
    property bool streaming: false
    property int streamSeconds: 0
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
                // recording or streaming since before the shell started
                capturePage.obsRequest("GetRecordStatus")
                capturePage.obsRequest("GetStreamStatus")
            } else if (msg.op === 7) {
                capturePage.onObsResponse(d)
            } else if (msg.op === 5) {
                if (d.eventType === "RecordStateChanged") {
                    var active = d.eventData && d.eventData.outputActive === true
                    // the stop event carries the saved file's path
                    if (!active && d.eventData && d.eventData.outputPath)
                        capturePage.notifySaved(d.eventData.outputPath)
                    capturePage.setRecording(active)
                } else if (d.eventType === "StreamStateChanged") {
                    // no outputPath here — a stream has no saved file,
                    // so the stop event carries nothing to notify with
                    capturePage.setStreaming(
                        d.eventData && d.eventData.outputActive === true)
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
        if (d.requestType === "GetStreamStatus" && d.responseData)
            capturePage.setStreaming(d.responseData.outputActive === true,
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

    // the stream's twin — same contract, its own counter. The two
    // outputs are independent in OBS (record and stream can run
    // alone, together, or neither), so the state is tracked
    // separately rather than folded into one "live" flag.
    function setStreaming(active, duration) {
        if (active === capturePage.streaming && duration === undefined)
            return
        capturePage.streaming = active
        capturePage.obsError = ""
        if (active)
            capturePage.streamSeconds = (duration !== undefined && duration > 0)
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

    function toggleStream() {
        if (!obsConnected) {
            capturePage.reconnectObs()
            return
        }
        capturePage.obsRequest(capturePage.streaming ? "StopStream" : "StartStream")
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

    // the stream's counter — independent, since the two outputs run
    // independently
    Timer {
        interval: 1000
        repeat: true
        running: capturePage.streaming
        onTriggered: capturePage.streamSeconds++
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

    // Reset wipes the whole db. cliphist owns it, so the wipe is
    // cliphist's own subcommand — no shell, no db-path guessing —
    // and the list re-reads off the process's exit, the same
    // StdioCollector path the open-refresh uses. A second click
    // mid-wipe is a silent no-op on an already-running Process,
    // which is the right behaviour here anyway.
    function resetClipboard() {
        clipWipeProcess.running = true
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

    Process {
        id: clipWipeProcess
        command: ["cliphist", "wipe"]
        onExited: clipListProcess.running = true
    }
}
