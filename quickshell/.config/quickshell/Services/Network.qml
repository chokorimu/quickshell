// Network.qml — connectivity via nmcli.
//
// Quickshell's Networking service reports zero devices on this machine even
// though NetworkManager is active and connected (wifiEnabled comes back false
// too), so this polls nmcli instead. Two passes: device status decides whether
// we are online and over what, then the wifi list adds signal strength.
//
// The wifi page (Modules/Bar/NetworkCard.qml) also lives here rather than in a
// service of its own: it is the same subject — connectivity — and splitting it
// would leave two readers of the same radio flag disagreeing about who owns
// it. Everything the page needs that the bar does not (the scan, the saved
// profiles, the connect/disconnect actions, their failures) is gated on
// `pageActive`, so the shell forks nothing for a card nobody has open.
import QtQml
import QtQuick
import Quickshell
import Quickshell.Io

pragma Singleton

Singleton {
    id: root

    property bool connected: false
    property string kind: "" // "wifi" | "ethernet" | ""
    property string ssid: ""
    property int signal: 0 // 0..100
    property bool available: false
    // the wifi interface's own name, read off the status pass — the
    // device is what `device disconnect` needs, and it is not always
    // "wlan0"
    property string device: ""

    // ---- wifi radio -----------------------------------------------------
    // The notifications page's wifi tile toggles the radio, and so does
    // this page's own pill. nmcli lets an unprivileged user flip radios
    // (verified both directions), so there is no privilege path to
    // arrange. Both flags gate polling: `radioActive` belongs to the
    // tile, `pageActive` to the wifi page, and either one keeps the
    // radio read alive — a page closing must not blind the tile that is
    // still on screen.
    property bool radioEnabled: false
    property bool radioActive: false

    // ---- the wifi page's own state --------------------------------------
    // active: the page is open, so scanning and the saved-profile read
    // are allowed. networks: the scan, deduped by SSID and sorted
    // (connected first, then strongest). saved: the NAMES of the saved
    // wifi profiles, which is what `connection up id` and
    // `connection delete id` take. connecting: the SSID of the action in
    // flight, empty when nothing is running. lastError: one readable
    // line for the page to show after a failure.
    property bool pageActive: false
    property var networks: []
    property var saved: []
    property bool scanning: false
    property string connecting: ""
    property string lastError: ""
    // the raw scan text, kept so the saved-profile read can re-derive
    // the rows without asking the radio for another sweep
    property string scanText: ""

    signal updated()

    function setRadio(on) {
        radioSetProc.command = ["nmcli", "radio", "wifi", on ? "on" : "off"]
        if (!radioSetProc.running)
            radioSetProc.running = true
    }

    function refresh() {
        if (!statusProc.running)
            statusProc.running = true
        if ((root.radioActive || root.pageActive) && !radioStateProc.running)
            radioStateProc.running = true
    }

    // ---- the scan ---------------------------------------------------------
    // `force` is the Rescan pill and the page's own opening: a real
    // `--rescan yes` costs several seconds because it waits for the
    // radio to sweep. The periodic refresh passes force = false, which
    // leaves nmcli's default `--rescan auto` in place — it reuses
    // NetworkManager's cache and only sweeps when that is stale, so a
    // card left open does not hammer the radio.
    //
    // A force scan that arrives while one is already running is
    // dropped rather than queued: the running scan is about to deliver
    // the same list.
    function scan(force) {
        if (!root.pageActive || scanProc.running)
            return
        scanning = true
        scanProc.command = force
            ? ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY",
               "device", "wifi", "list", "--rescan", "yes"]
            : ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY",
               "device", "wifi", "list"]
        scanProc.running = true
    }

    // The saved wifi profiles. Read fresh on every page open and after
    // every action, because a connect creates one and a forget removes
    // one — the list is small and the command is instant, so caching it
    // would only be a way to go stale.
    function readSaved() {
        if (!root.pageActive || savedProc.running)
            return
        savedProc.running = true
    }

    // ---- terse-mode parsing ----------------------------------------------
    // nmcli's `-t` mode escapes `:` and `\` inside a value, so a plain
    // split(":") mangles any SSID containing either ("Cafe: Corner"
    // arrives as "Cafe\: Corner"). Walk the line and unescape as we go.
    function terseSplit(line) {
        var out = []
        var cur = ""
        for (var i = 0; i < line.length; i++) {
            var c = line.charAt(i)
            if (c === "\\" && i + 1 < line.length) {
                cur += line.charAt(++i)
            } else if (c === ":") {
                out.push(cur)
                cur = ""
            } else {
                cur += c
            }
        }
        out.push(cur)
        return out
    }

    // Turn the raw scan text into the page's model. The same SSID
    // normally arrives once per BSSID — a mesh or a 2.4/5GHz pair
    // shares one name — so entries are folded by SSID and keep the
    // strongest RSSI. `active` is OR'd across them: the AP you are
    // associated with is not always the loudest one.
    function rebuild() {
        var seen = {}
        var list = []
        var lines = root.scanText.split("\n")
        for (var i = 0; i < lines.length; i++) {
            if (lines[i].length === 0)
                continue
            var f = terseSplit(lines[i])
            if (f.length < 4)
                continue
            var inUse = f[0].indexOf("*") >= 0
            var name = f[1]
            // an empty SSID is a hidden network; the list has nothing
            // to show for it and no way to pick it by name
            if (name.length === 0 || name === "--")
                continue
            var sig = parseInt(f[2], 10)
            if (isNaN(sig))
                sig = 0
            var sec = f[3]
            var e = seen[name]
            if (e === undefined) {
                e = { ssid: name, signal: sig, security: sec, active: false }
                seen[name] = e
                list.push(e)
            }
            if (inUse)
                e.active = true
            if (sig > e.signal)
                e.signal = sig
            // the longest security string is the informative one when
            // BSSIDs disagree ("WPA2" against "WPA2 WPA3")
            if (sec.length > e.security.length)
                e.security = sec
        }
        for (var j = 0; j < list.length; j++) {
            var n = list[j]
            n.secured = n.security.length > 0
            // 802.1X is WPA-Enterprise: it needs an identity, a
            // password and usually a CA, which this page does not
            // collect. The row says so instead of opening a password
            // prompt that could not possibly succeed.
            n.enterprise = n.security.indexOf("802.1X") >= 0
            n.saved = root.saved.indexOf(n.ssid) >= 0
        }
        // connected first, then by signal — what every wifi client
        // does, and it keeps the row you just connected to at the top
        // where you can see it took
        list.sort(function (a, b) {
            if (a.active !== b.active)
                return a.active ? -1 : 1
            return b.signal - a.signal
        })
        root.networks = list
    }

    // ---- actions ----------------------------------------------------------
    // One process, drained from a queue, because `running = true` on an
    // already-running Process is a silent no-op (the trap AppAudio's
    // slider writes and Wallpapers' picks queue around) and a second
    // click during a 30s connect would otherwise be dropped without a
    // trace.
    property var actionQueue: []
    property string actionKind: ""

    function runAction(cmd, kind, label) {
        actionQueue = actionQueue.concat([{ command: cmd, kind: kind, label: label }])
        drainActions()
    }

    function drainActions() {
        if (actionProc.running || actionQueue.length === 0)
            return
        var a = actionQueue[0]
        actionQueue = actionQueue.slice(1)
        actionKind = a.kind
        // the page shows "Connecting…" on the row, so the label is the
        // SSID for a connect and the profile name for everything else
        connecting = a.label
        actionProc.command = a.command
        actionProc.running = true
    }

    // `--wait 30` bounds a dead network: nmcli's default is 90s, which
    // is longer than anyone waits before deciding it did not work.
    function connectTo(ssid, password) {
        var cmd = ["nmcli", "--wait", "30", "device", "wifi", "connect", ssid]
        if (password.length > 0)
            cmd.push("password", password)
        lastError = ""
        runAction(cmd, "connect", ssid)
    }

    // A saved profile is brought up rather than re-created: nmcli would
    // find the matching connection anyway, but `connection up` is the
    // exact operation and it leaves the stored profile alone.
    function connectSaved(name) {
        lastError = ""
        runAction(["nmcli", "--wait", "30", "connection", "up", "id", name],
                  "connect", name)
    }

    function disconnectWifi() {
        if (root.device.length === 0)
            return
        lastError = ""
        runAction(["nmcli", "device", "disconnect", root.device], "disconnect", "")
    }

    function forget(name) {
        lastError = ""
        runAction(["nmcli", "connection", "delete", "id", name], "forget", name)
    }

    // nmcli's failures are written for a terminal. The common ones get
    // a sentence a person can act on; anything else falls through to
    // its own first line, which is still better than silence.
    function explain(text) {
        var t = (text === undefined || text === null ? "" : String(text))
            .replace(/^\s+|\s+$/g, "")
        // nmcli prefixes the whole message; strip every leading Error:
        while (t.indexOf("Error:") === 0)
            t = t.substring(6).replace(/^\s+/, "")
        if (t.length === 0)
            return "Connection failed"
        if (t.indexOf("Secrets were required") >= 0
                || t.indexOf("802-11-wireless-security") >= 0)
            return "Wrong password"
        var lower = t.toLowerCase()
        if (lower.indexOf("timeout") >= 0 || lower.indexOf("timed out") >= 0)
            return "Timed out"
        if (t.indexOf("No network with SSID") >= 0)
            return "Network not found"
        if (t.indexOf("not available") >= 0)
            return "Network not available"
        return t.split("\n")[0]
    }

    // ---- bar readouts -----------------------------------------------------
    // DEVICE:TYPE:STATE:CONNECTION
    Process {
        id: statusProc
        command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.available = true
                root.connected = false
                root.kind = ""
                root.ssid = ""
                root.signal = 0

                var lines = this.text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var f = lines[i].split(":")
                    if (f.length < 4)
                        continue
                    var dev = f[0]
                    var type = f[1]
                    var state = f[2]
                    var con = f[3]
                    // the interface name, whether or not it is up
                    if (type === "wifi" && root.device.length === 0)
                        root.device = dev
                    // skip tun/loopback/bridge and anything not actually up
                    if (type !== "wifi" && type !== "ethernet")
                        continue
                    if (state.indexOf("connected") !== 0)
                        continue
                    if (!con)
                        continue
                    root.connected = true
                    root.kind = type
                    root.ssid = con
                    break
                }

                if (root.kind === "wifi" && !wifiProc.running)
                    wifiProc.running = true
                else
                    root.updated()
            }
        }
    }

    // ACTIVE:SSID:SIGNAL
    Process {
        id: wifiProc
        command: ["nmcli", "-t", "-f", "ACTIVE,SSID,SIGNAL", "device", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    if (lines[i].indexOf("yes:") !== 0)
                        continue
                    var f = lines[i].split(":")
                    if (f.length >= 3) {
                        root.ssid = f[1]
                        root.signal = parseInt(f[2]) || 0
                    }
                    break
                }
                root.updated()
            }
        }
    }

    // "enabled" | "disabled" — one line, wifi only
    Process {
        id: radioStateProc
        command: ["nmcli", "radio", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: {
                var was = root.radioEnabled
                root.radioEnabled = this.text.trim() === "enabled"
                root.updated()
                // the radio just came up under an open page: the list
                // the page is showing was gathered while it was down,
                // so sweep now rather than leaving an empty card for
                // the periodic refresh to fill in
                if (root.pageActive && root.radioEnabled && !was)
                    root.scan(true)
            }
        }
    }

    Process {
        id: radioSetProc
        onExited: {
            root.refresh()
            if (root.pageActive)
                root.scan(true)
        }
    }

    // ---- the page's readers ------------------------------------------------
    // IN-USE:SSID:SIGNAL:SECURITY
    Process {
        id: scanProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.scanText = this.text
                root.rebuild()
            }
        }
        onExited: (code) => {
            root.scanning = false
            // a failed scan means no device, or the radio off — the
            // page's own state line already explains both, so the only
            // thing to do here is not leave "Scanning…" on screen
            if (code !== 0) {
                root.scanText = ""
                root.rebuild()
            }
        }
    }

    // NAME:TYPE — wifi profiles only
    Process {
        id: savedProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                var lines = this.text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    if (lines[i].length === 0)
                        continue
                    var f = root.terseSplit(lines[i])
                    if (f.length < 2)
                        continue
                    if (f[1] !== "802-11-wireless")
                        continue
                    out.push(f[0])
                }
                root.saved = out
                // the scan's `saved` flags come off this list, so the
                // page's rows are only right once both have landed
                if (root.scanText.length > 0)
                    root.rebuild()
            }
        }
    }

    Process {
        id: actionProc
        stderr: StdioCollector { id: actionErr }
        onExited: (code) => {
            if (code !== 0)
                root.lastError = root.explain(actionErr.text)
            else
                root.lastError = ""
            root.connecting = ""
            root.actionKind = ""
            // whatever just happened changed the world: the readouts,
            // the saved-profile list and the rows all want re-reading
            root.refresh()
            root.readSaved()
            if (root.pageActive)
                root.scan(false)
            root.drainActions()
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    // the page's own refresh cadence while it is open — auto-rescan,
    // so it costs a cached read most of the time
    Timer {
        interval: 10000
        running: root.pageActive && root.radioEnabled
        repeat: true
        onTriggered: root.scan(false)
    }

    Component.onCompleted: root.refresh()
}
