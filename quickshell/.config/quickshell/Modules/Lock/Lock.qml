// Lock.qml — the lockscreen.
//
// hyprlock did the job, but it is a closed box: its config is its own
// dialect, its colors are static, and it sits entirely outside this
// shell's theming. This module replaces it with a surface that shares
// the Theme singleton — so it follows matugen and the light/dark
// switch like every other surface — and the session page's avatar.
//
// Auth is real PAM through Quickshell's PamContext, pointed at our
// own stack — pam.d/lock beside this config, stow-deployed, no root
// anywhere. It is pam_unix alone: the same module that checks the
// password everywhere else, minus the pam_faillock attempt cap that
// hyprlock's chain carried (deny=3, 900s unlock — three typos and
// the session is locked out for a quarter hour). FAIL_DELAY 3 still
// applies, so guessing stays slow; there is just no cap. The file
// itself carries the full reasoning.
//
// Structure: the root is a non-visual state holder — one instance in
// shell.qml — and one WlSessionLock beneath it binding to `locked`.
// The lock instantiates its surface component once per output, so
// every monitor locks and unlocks together with no bookkeeping
// here; a lockscreen that left one screen interactive would be no
// lockscreen at all.
//
// The surface is ext-session-lock-v1 rather than a layer surface,
// and that is load-bearing: while a client holds the session lock,
// hyprland blanks every other surface AND suppresses every keybind
// without `locked = true`. The layer-shell draft of this module
// looked the same but left the desktop live behind it — SUPER+W
// still closed windows while locked. The binds that should survive
// (volume, brightness, media transport) already carry that flag in
// keybinds.lua; everything else now dies with the lock.
import QtQml
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import "../../Theme"
import "../../Services"

Item {
    id: root

    // ---- shared state --------------------------------------------------

    property bool locked: false

    // the status line under the field. PAM's own message ("Password:
    // ") is not user-facing, so this carries our strings instead.
    property string status: ""
    property bool statusIsError: false

    // failed unlocks since this lock. Drives the shake; the count
    // itself is not shown — a lockscreen that reports how many tries
    // are left is telling an attacker how close they are.
    property int attempts: 0

    // a password typed during the gap between a failed attempt and
    // the next conversation's prompt. respond() before PAM asks is
    // a conversation error, so it waits here for the prompt.
    property string pendingPassword: ""

    readonly property string user: Quickshell.env("USER")
    readonly property string avatarPath: Quickshell.env("HOME")
        + "/.config/quickshell/avatar.png"

    property string hostname: ""
    property bool avatarExists: false

    // caps lock, polled from the compositor while locked. A wrong
    // password that was really a stuck shift is the classic
    // lockscreen confusion, and nothing in Quickshell 0.3.2 exposes
    // modifier state — but hyprland tracks it per keyboard in
    // `hyprctl devices`. One fork a second while locked, none the
    // rest of the time; an unparseable dump leaves the last known
    // state standing rather than flashing the indicator.
    property bool capsOn: false

    // how strongly the current artwork shows through the scrim
    // behind the card. The tune-here line: 0 is the plain scrim,
    // and the media card's own wash ships at 0.1 with its blur
    // switched off — but a lockscreen backdrop is the one surface
    // where the art is the point rather than a tint.
    readonly property real artBackdropAlpha: 0.35

    // PAM target. Our own stack (pam.d/lock in this config dir) —
    // see the header and that file for why it is not hyprlock's.
    // Both stay overridable so a probe can point the module at a
    // throwaway stack (pam_permit / a faillock-free pam_unix) and
    // exercise both outcomes without touching the real one.
    property string pamConfig: "lock"
    property string pamConfigDir: Quickshell.env("HOME")
        + "/.config/quickshell/pam.d"

    // one clock for every surface
    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    function lock() {
        if (root.locked)
            return
        root.locked = true
        root.status = ""
        root.statusIsError = false
        root.attempts = 0
        root.pendingPassword = ""
        // starts the conversation; the prompt arrives as a
        // pamMessage, which is what focuses the field
        pam.active = true
        // and the caps-lock read starts now rather than a second in
        capsProc.running = true
    }

    function unlock() {
        root.locked = false
        // drop any in-flight conversation so a stale prompt cannot
        // complete against an unmapped surface
        pam.active = false
        root.status = ""
        root.statusIsError = false
        root.attempts = 0
        root.pendingPassword = ""
    }

    // The field delegates here rather than calling respond() itself,
    // so the whole auth step is one function on the state holder —
    // which is also what lets a probe drive it without synthesizing
    // keystrokes.
    function submit(password) {
        if (pam.responseRequired) {
            pam.respond(password)
            root.status = "Verifying..."
            root.statusIsError = false
            return
        }
        // No prompt yet: either the first conversation is still
        // starting or a failed attempt is re-arming. Stash it — the
        // prompt's arrival responds with it (see the delegate's
        // Connections below). Dropping it instead would eat the
        // first keystroke of every retry.
        root.pendingPassword = password
        root.status = "Verifying..."
        root.statusIsError = false
    }

    PamContext {
        id: pam
        config: root.pamConfig
        configDirectory: root.pamConfigDir
        user: root.user

        onCompleted: (result) => {
            // PamResult: 0 Success, 1 Failed, 2 Error, 3 MaxTries
            if (result === 0) {
                root.unlock()
                return
            }
            root.attempts++
            root.statusIsError = true
            root.status = result === 3
                ? "Too many attempts"
                : result === 2
                    ? "Authentication error"
                    : "Wrong password"
            // The conversation is over — active and responseRequired
            // both drop on completion — so the next one starts right
            // here. There is no attempt cap: every try gets a fresh
            // conversation (which is also why MaxTries cannot
            // accumulate), and a lockscreen left with a dead
            // conversation would be one nobody could get out of. If
            // this restart itself fails to start, onError's
            // StartFailed path hands off to hyprlock.
            pam.active = false
            pam.active = true
        }

        onError: (error) => {
            // PamError: 0 StartFailed, 1 TryAuthFailed, 2 InternalError.
            // StartFailed means the PAM stack could not be opened at
            // all — the user would be locked out of their own session
            // with no way in, so hand off to hyprlock, the locker that
            // definitely works, rather than sitting there dead.
            if (error === 0) {
                fallbackProc.running = true
                root.locked = false
                return
            }
            root.statusIsError = true
            root.status = "Authentication error"
        }

        onPamMessage: {
            // The signal's parameters arrive undefined in 0.3.2 — the
            // shipped qmltypes declares pamMessage with no Parameter
            // lines (stale typeinfo; AGENTS.md's standing warning).
            // The readonly properties carry the same data and are
            // notified, so read those. Focusing happens per-window
            // through the Connections in the delegate below.
        }
    }

    // the safety net above: hyprlock, spawned as a plain process
    Process {
        id: fallbackProc
        command: ["hyprlock"]
    }

    IpcHandler {
        target: "lock"
        // parameterless only — an IpcHandler function taking an
        // argument reports "Function not found" in 0.3.2
        function lock(): void { root.lock() }
        // deliberately no unlock route: the only way out is a
        // successful PAM conversation
    }

    // hostname — read once; the lockscreen is short-lived enough that
    // a change mid-session is not worth a watcher (SessionCard's
    // pattern)
    Process {
        running: true
        command: ["cat", "/proc/sys/kernel/hostname"]
        stdout: StdioCollector {
            onStreamFinished: root.hostname = this.text.trim()
        }
    }

    // does an avatar exist yet? Checked with test -f rather than by
    // pointing the Image at a missing file, which would log a load
    // error on every shell reload (SessionCard's pattern)
    Process {
        running: true
        command: ["test", "-f", root.avatarPath]
        onExited: (code) => { root.avatarExists = code === 0 }
    }

    // caps lock poll — gated on locked, so nothing forks while the
    // desktop is in use. The first read also fires from lock() so
    // the indicator is right the moment the surface appears rather
    // than a second later.
    Timer {
        interval: 1000
        repeat: true
        running: root.locked
        onTriggered: capsProc.running = true
    }

    Process {
        id: capsProc
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var devs = JSON.parse(this.text)
                    var on = false
                    for (var i = 0; i < devs.keyboards.length; i++)
                        if (devs.keyboards[i].capsLock)
                            on = true
                    root.capsOn = on
                } catch (e) {
                    // leave the last known state standing
                }
            }
        }
    }

    // ---- the lock surface ------------------------------------------------
    //
    // One WlSessionLock, one surface per output: the lock
    // instantiates the component per screen itself, so there is no
    // Variants here and no screen bookkeeping to get wrong. The
    // compositor hands the lock surfaces the keyboard, which is what
    // the field below types into; the per-output instantiation, the
    // keyboard and the clean unlock were all probe-verified
    // (/tmp/opencode/slprobe, slprobe2) before this replaced the
    // layer surface.
    //
    // The component is declared beside the lock rather than inline
    // in its `surface` property purely so the content keeps its old
    // indentation — inline would push every child four spaces right
    // for no gain.
    Component {
        id: lockSurface

        WlSessionLockSurface {
            id: surf

            // black base behind the scrim — the compositor's own
            // blank color, so a slow first paint never flashes the
            // wallpaper through. The scrim Rectangle below is the
            // real background; this is only the floor under it.
            color: "black"

            // scrim — the card surface's own darker step, so the card
            // reads as a raised surface on it
            Rectangle {
                anchors.fill: parent
                color: Theme.cardBackground
            }

            // blurred current-artwork wash over the scrim — the media
            // card's artBuffer recipe, full-screen and with the blur
            // actually switched on (the card ships blurSize 0). Cover-
            // fit so a square keeps its ratio on any monitor; 13
            // additive taps ('lighter' at 1/n each) because source-
            // over cannot reach an exact average — the last copy
            // would survive at ~37% and 8-bit truncation costs
            // another ~20%; and an opaque black fill first because a
            // transparent destination leaves the accumulated alpha at
            // ~55% and the colour then reads back over-delivered. No
            // player = nothing painted and the scrim stands alone.
            // The item's opacity is the wash's strength; the paint
            // itself stays at full strength so the taps average
            // exactly.
            Canvas {
                id: artBackdrop
                anchors.fill: parent
                opacity: root.artBackdropAlpha

                // the blur's tune-here block, the media card's own:
                // blurSize is the disc's radius in logical px, 0 is
                // the off switch (a single tap at 0,0 — the raw art
                // at full strength); blurStep is the tap spacing
                // (13 taps at 10/5, 29 at 12/4); blurPasses applies
                // the disc that many times, effective radius
                // size*sqrt(passes). More taps also dims the wash
                // slightly — 'lighter' loses energy as N grows — so
                // raise artBackdropAlpha to compensate.
                readonly property real blurSize: 10
                readonly property real blurStep: 5
                readonly property int blurPasses: 1

                // the tap set: a disc of offsets at blurStep spacing
                // inside blurSize*sqrt(blurPasses). Computed once;
                // the paint reads it per artwork.
                property var artTaps: []
                Component.onCompleted: {
                    var r = blurSize * Math.sqrt(blurPasses), s = blurStep, t = []
                    for (var dy = -r; dy <= r; dy += s)
                        for (var dx = -r; dx <= r; dx += s)
                            if (dx * dx + dy * dy <= r * r + 0.001)
                                t.push([dx, dy])
                    artTaps = t
                }

                // pixmap source only — children of a Canvas render
                // above its paint, so this stays invisible. An Image
                // rather than the canvas's own loadImage because it
                // loads asynchronously and repaints on arrival.
                // sourceSize is deliberately not set: canvas
                // drawImage ignores it (a 1px line survived an 8x
                // downscale), so covers decode at full size.
                Image {
                    id: mediaArt
                    visible: false
                    asynchronous: true
                    source: Media.artUrl
                    onStatusChanged: artBackdrop.requestPaint()
                }

                onPaint: {
                    var ctx = getContext("2d")
                    var w = width, h = height
                    ctx.clearRect(0, 0, w, h)
                    // no art (or not loaded yet): transparent, so the
                    // scrim shows through untouched
                    if (mediaArt.status !== Image.Ready)
                        return

                    ctx.fillStyle = "#000000"
                    ctx.fillRect(0, 0, w, h)

                    // cover-fit, not stretch — and the crop is
                    // centred, which keeps every blur tap inside the
                    // drawn copy (the copy is at least as large as
                    // the screen on both axes, so a tap shifted off
                    // an edge still has the copy's margin behind it)
                    var iw = mediaArt.implicitWidth
                    var ih = mediaArt.implicitHeight
                    var scale = (iw > 0 && ih > 0) ? Math.max(w / iw, h / ih) : 1
                    var dw = iw * scale
                    var dh = ih * scale
                    var dx = (w - dw) / 2
                    var dy = (h - dh) / 2

                    var n = artTaps.length
                    ctx.globalCompositeOperation = "lighter"
                    ctx.globalAlpha = 1 / n
                    for (var i = 0; i < n; i++)
                        ctx.drawImage(mediaArt, dx + artTaps[i][0], dy + artTaps[i][1], dw, dh)
                    ctx.globalCompositeOperation = "source-over"
                    ctx.globalAlpha = 1
                }
            }

            Rectangle {
                id: card
                anchors.centerIn: parent
                width: 420
                height: col.height + 96
                radius: 24
                color: Theme.cardPill

                // shake on a failed unlock. A Translate rather than
                // fighting the centerIn anchor, and retriggered by
                // restart() so back-to-back failures each shake.
                property real shakeOffset: 0
                transform: Translate { x: card.shakeOffset }

                SequentialAnimation {
                    id: shakeAnim
                    NumberAnimation { target: card; property: "shakeOffset"; to: -10; duration: 60 }
                    NumberAnimation { target: card; property: "shakeOffset"; to: 10; duration: 60 }
                    NumberAnimation { target: card; property: "shakeOffset"; to: -6; duration: 60 }
                    NumberAnimation { target: card; property: "shakeOffset"; to: 0; duration: 60 }
                }

                Connections {
                    target: root
                    function onAttemptsChanged() {
                        if (root.attempts > 0)
                            shakeAnim.restart()
                    }
                }

                // A Column gives its children height, never width —
                // and anchors (or x/y) on a direct Column child are
                // ignored. So every child takes width: parent.width
                // and centers itself with horizontalAlignment, and the
                // avatar sits in a full-width wrapper Item where
                // anchors are legal.
                Column {
                    id: col
                    anchors.centerIn: parent
                    width: 340
                    spacing: 18

                    Item {
                        width: parent.width
                        height: 96

                        // placeholder disc — cardHighlight reads as
                        // "no avatar yet" against the card surface
                        Rectangle {
                            width: 96
                            height: 96
                            anchors.centerIn: parent
                            radius: 48
                            color: Theme.cardHighlight
                            visible: !root.avatarExists
                        }

                        // circular art is a Canvas arc clip — clip:true
                        // on a Rectangle only clips to the rectangular
                        // bounds, so an Image child renders square
                        Canvas {
                            width: 96
                            height: 96
                            anchors.centerIn: parent
                            visible: root.avatarExists
                            property url artSource: root.avatarExists
                                ? "file://" + root.avatarPath : ""

                            onArtSourceChanged: {
                                if (artSource != "")
                                    loadImage(artSource)
                                requestPaint()
                            }
                            onImageLoaded: requestPaint()

                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                if (!root.avatarExists)
                                    return
                                ctx.beginPath()
                                ctx.arc(width / 2, height / 2, width / 2,
                                    0, 2 * Math.PI)
                                ctx.clip()
                                ctx.drawImage(artSource, 0, 0, width, height)
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: root.user + (root.hostname.length > 0
                            ? "@" + root.hostname : "")
                        color: Theme.cardForeground
                        font.family: Theme.barFontFamily
                        font.pixelSize: 14
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: Qt.formatDateTime(clock.date, "hh:mm")
                        color: Theme.cardForeground
                        font.family: Theme.barFontFamily
                        font.pixelSize: 52
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: Qt.formatDateTime(clock.date, "ddd, MMM d")
                        color: Theme.cardDim
                        font.family: Theme.barFontFamily
                        font.pixelSize: 13
                    }

                    // password field — the pill idiom: a cardHighlight
                    // track at full radius, glyph left, input on the
                    // card surface with no background of its own
                    Rectangle {
                        width: parent.width
                        height: 44
                        radius: 22
                        color: Theme.cardHighlight

                        Text {
                            id: lockGlyph
                            x: 16
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\uF023"
                            font.family: Theme.iconFont
                            font.pixelSize: 16
                            color: Theme.cardDim
                        }

                        TextInput {
                            id: field
                            x: 44
                            width: parent.width - 60
                            anchors.verticalCenter: parent.verticalCenter
                            echoMode: TextInput.Password
                            color: Theme.cardForeground
                            font.family: Theme.barFontFamily
                            font.pixelSize: 15
                            cursorVisible: true
                            selectByMouse: false
                            // right-click paste is a lockscreen's
                            // friend; middle-click paste is not
                            mouseSelectionMode: TextInput.SelectWords

                            Text {
                                visible: !field.text && !field.activeFocus
                                text: "Password"
                                color: Theme.cardDim
                                font: field.font
                            }

                            onAccepted: {
                                root.submit(field.text)
                                field.text = ""
                            }
                        }
                    }

                    // caps lock warning, between the field and the
                    // status line. A Row rather than one Text because
                    // the glyph needs the icon font and the words the
                    // UI font; the shared line box (height on the
                    // label, AlignVCenter) keeps their ink on one
                    // line — the icon font's line box runs ~19 against
                    // the UI font's ~16 at these sizes. The Row sits
                    // in a full-width wrapper Item because anchors on
                    // a direct Column child are ignored, and a Row
                    // has no horizontalAlignment of its own (that is
                    // RowLayout) — the avatar above uses the same
                    // wrapper for the same reason.
                    Item {
                        width: parent.width
                        height: capsRow.implicitHeight
                        visible: root.capsOn

                        Row {
                            id: capsRow
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 6

                            Text {
                                id: capsGlyph
                                text: "\uF071"
                                font.family: Theme.iconFont
                                font.pixelSize: 12
                                color: Theme.cardForeground
                            }

                            Text {
                                height: capsGlyph.height
                                verticalAlignment: Text.AlignVCenter
                                text: "Caps Lock is on"
                                color: Theme.cardForeground
                                font.family: Theme.barFontFamily
                                font.pixelSize: 12
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: root.status
                        // the error state rides full ink against the
                        // dim normal state — the card palette carries
                        // no urgent color, and the shake is the loud
                        // signal anyway
                        color: root.statusIsError
                            ? Theme.cardForeground : Theme.cardDim
                        font.family: Theme.barFontFamily
                        font.pixelSize: 13
                        visible: root.status.length > 0
                    }
                }
            }

            // Focus. The surface maps with exclusive keyboard focus,
            // but the caret still has to be placed, and the compositor
            // needs a beat to commit the interactivity change before
            // the activation request — the ESC lesson. Both paths (the
            // window appearing, the prompt arriving) funnel through
            // this one timer; only the focused window's call moves
            // anything.
            Timer {
                id: focusTimer
                interval: 50
                onTriggered: field.forceActiveFocus()
            }

            onVisibleChanged: if (visible) focusTimer.restart()

            Connections {
                target: pam
                function onResponseRequiredChanged() {
                    if (!pam.responseRequired)
                        return
                    focusTimer.restart()
                    // a password typed during the re-arm gap answers
                    // itself the moment the new prompt lands
                    if (root.pendingPassword.length > 0) {
                        var pw = root.pendingPassword
                        root.pendingPassword = ""
                        pam.respond(pw)
                    }
                }
            }
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: root.locked
        surface: lockSurface
    }
}
