// Bluetooth.qml — adapter power via bluetoothctl, with the rfkill
// unblock that power-on needs.
//
// Quickshell 0.3.2 ships no Bluetooth service (the service list is
// Greetd/Mpris/Notifications/Pam/Pipewire/Polkit/SystemTray/UPower),
// so this polls bluetoothctl instead.
//
// The power path is the non-obvious part. A soft-blocked adapter
// reports PowerState: off-blocked and `bluetoothctl power on` fails
// with org.bluez.Error.Failed no matter what bluez itself allows —
// the block has to be cleared first with `rfkill unblock
// bluetooth`. That needs no privilege here: /dev/rfkill carries a
// POSIX ACL granting this user rw (verified with getfacl), so the
// unblock runs as the user. The block itself was a saved rfkill
// state restored at boot by systemd-rfkill; clearing it re-saves the
// unblocked state, so it does not come back after a reboot. Only the
// on direction touches rfkill — power off is a plain bluetoothctl
// call.
//
// Page-only consumer (the notifications tab's bluetooth tile), so
// this polls in Brightness's active-gated mould: nothing forks
// while the card is closed.
import QtQml
import QtQuick
import Quickshell
import Quickshell.Io

pragma Singleton

Singleton {
    id: root

    property bool powered: false
    // false when bluetoothctl cannot reach bluetoothd at all — the
    // tile then reads "Unavailable" and the click does nothing
    property bool available: false
    // name of the one connected device, "" when nothing is
    property string connectedDevice: ""

    // flipped by the page: the tile is the only reader
    property bool active: false

    function refresh() {
        if (!showProc.running)
            showProc.running = true
    }

    function setPowered(on) {
        if (on) {
            // unblock first, power on off its exit — two Processes
            // rather than a shell, so nothing needs quoting
            if (!unblockProc.running) {
                pendingPower = true
                unblockProc.running = true
            }
        } else {
            powerProc.command = ["bluetoothctl", "power", "off"]
            if (!powerProc.running)
                powerProc.running = true
        }
    }

    // set while the unblock -> power-on chain runs
    property bool pendingPower: false

    Process {
        id: unblockProc
        command: ["rfkill", "unblock", "bluetooth"]
        onExited: {
            if (root.pendingPower) {
                root.pendingPower = false
                powerProc.command = ["bluetoothctl", "power", "on"]
                powerProc.running = true
            }
        }
    }

    Process {
        id: powerProc
        onExited: root.refresh()
    }

    // Powered: yes|no — present even while the adapter is
    // soft-blocked (it then reads PowerState: off-blocked alongside
    // it), so a blocked adapter reads as simply off. A missing
    // Powered line or a non-zero exit means bluetoothd is not
    // reachable, which is the unavailable case.
    //
    // The line is TAB-INDENTED ("\tPowered: no") — bluetoothctl
    // indents every field under the Controller header — so the
    // match tolerates leading whitespace. Anchoring at ^Powered:
    // silently never matches and the tile reads Unavailable
    // forever, which is exactly what the first probe caught.
    Process {
        id: showProc
        command: ["bluetoothctl", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n")
                var sawPowered = false
                var powered = false
                for (var i = 0; i < lines.length; i++) {
                    var m = lines[i].match(/^\s*Powered:\s*(yes|no)/)
                    if (m) {
                        sawPowered = true
                        powered = m[1] === "yes"
                        break
                    }
                }
                if (sawPowered) {
                    root.available = true
                    root.powered = powered
                }
                if (!connProc.running)
                    connProc.running = true
            }
        }
        onExited: (code) => {
            if (code !== 0) {
                root.available = false
                root.powered = false
            }
        }
    }

    // one line per connected device: "Device F4:B6:2D:89:D8:6F
    // soundcore R50i" — the name is everything past the MAC, and may
    // itself contain spaces
    Process {
        id: connProc
        command: ["bluetoothctl", "devices", "Connected"]
        stdout: StdioCollector {
            onStreamFinished: {
                var name = ""
                var lines = this.text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var m = lines[i].match(/^Device\s+\S+\s+(.*)$/)
                    if (m) {
                        name = m[1]
                        break
                    }
                }
                root.connectedDevice = name
            }
        }
    }

    Timer {
        interval: 5000
        running: root.active
        repeat: true
        onTriggered: root.refresh()
    }
}
