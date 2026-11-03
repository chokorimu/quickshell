// PowerProfiles.qml — the power-profiles-daemon profile, via
// powerprofilesctl.
//
// UPower does not expose a PowerProfiles interface on this machine
// (verified: the introspection call fails with "No interface
// org.freedesktop.UPower.PowerProfiles"), and Quickshell 0.3.2 has
// no service for PPD either, so this shells out. power-profiles-
// daemon is active with performance / balanced / power-saver
// available.
//
// The island's battery-saver tile is the only consumer, so this
// polls in Brightness's active-gated mould: nothing forks while the
// card is closed.
import QtQml
import QtQuick
import Quickshell
import Quickshell.Io

pragma Singleton

Singleton {
    id: root

    // "performance" | "balanced" | "power-saver" | ""
    property string profile: ""
    property bool available: false

    readonly property bool saverOn: profile === "power-saver"

    // flipped by the page: the tile is the only reader
    property bool active: false

    function refresh() {
        if (!getProc.running)
            getProc.running = true
    }

    // the tile is a two-state switch over a three-profile daemon:
    // saver on pins power-saver, saver off goes back to balanced
    // rather than performance — the profile the machine idles in
    function setSaver(on) {
        setProc.command = ["powerprofilesctl", "set", on ? "power-saver" : "balanced"]
        if (!setProc.running)
            setProc.running = true
    }

    // prints the active profile's name and nothing else
    Process {
        id: getProc
        command: ["powerprofilesctl", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = this.text.trim()
                if (p.length > 0) {
                    root.available = true
                    root.profile = p
                }
            }
        }
        onExited: (code) => {
            if (code !== 0) {
                root.available = false
                root.profile = ""
            }
        }
    }

    Process {
        id: setProc
        onExited: root.refresh()
    }

    Timer {
        interval: 5000
        running: root.active
        repeat: true
        onTriggered: root.refresh()
    }
}
