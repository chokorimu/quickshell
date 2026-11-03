// Network.qml — connectivity via nmcli.
//
// Quickshell's Networking service reports zero devices on this machine even
// though NetworkManager is active and connected (wifiEnabled comes back false
// too), so this polls nmcli instead. Two passes: device status decides whether
// we are online and over what, then the wifi list adds signal strength.
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

    // ---- wifi radio -----------------------------------------------------
    // The notifications page's wifi tile toggles the radio. nmcli lets
    // an unprivileged user flip radios (verified both directions), so
    // there is no privilege path to arrange. The flag is read only by
    // that tile, so it polls only while the page is open — radioActive,
    // flipped by the page — rather than riding the always-on 5s timer
    // the bar's own readouts use. refresh() re-reads it on the way in,
    // so the tile is live the moment the card opens.
    property bool radioEnabled: false
    property bool radioActive: false

    signal updated()

    function setRadio(on) {
        radioSetProc.command = ["nmcli", "radio", "wifi", on ? "on" : "off"]
        if (!radioSetProc.running)
            radioSetProc.running = true
    }

    function refresh() {
        if (!statusProc.running)
            statusProc.running = true
        if (root.radioActive && !radioStateProc.running)
            radioStateProc.running = true
    }

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
                    var type = f[1]
                    var state = f[2]
                    var con = f[3]
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
                root.radioEnabled = this.text.trim() === "enabled"
                root.updated()
            }
        }
    }

    Process {
        id: radioSetProc
        onExited: root.refresh()
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()
}
