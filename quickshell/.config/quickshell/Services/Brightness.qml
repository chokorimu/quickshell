// Brightness.qml — system backlight.
//
// Polls brightnessctl rather than reading /sys/class/backlight
// directly: the sysfs nodes are root-owned, and brightnessctl already
// knows how to find the right device and how to write it back. The
// device name comes off the read and is passed back on every write,
// so a machine with several backlights always reads and writes the
// same one.
//
// Unlike Audio this does NOT poll at boot: the theme page is its only
// consumer and it is usually closed, so the timer only runs while the
// card is on screen (`active`). ThemeCard flips it with its own
// visibility and calls refresh() on the way in, so the slider is live
// the moment the page opens and forks nothing the rest of the time.
import QtQml
import QtQuick
import Quickshell
import Quickshell.Io

pragma Singleton

Singleton {
    id: root

    // 0..1
    property real brightness: 0
    property bool available: false
    // the backlight device the reads came from — "" until the first
    // successful read, and then pinned so writes target the same one
    property string device: ""
    // driven by the consumer's visibility; see the header comment
    property bool active: false

    signal updated()

    function refresh() {
        if (!getProc.running)
            getProc.running = true
    }

    function setBrightness(v) {
        var clamped = Math.max(0, Math.min(1, v))
        var cmd = ["brightnessctl"]
        if (root.device.length > 0)
            cmd.push("-d", root.device)
        cmd.push("set", Math.round(clamped * 100) + "%")
        setProc.command = cmd
        setProc.running = true
    }

    // delta is in 0..1 units; its sign picks the direction
    function nudge(delta) {
        var pct = Math.max(1, Math.round(Math.abs(delta) * 100))
        var cmd = ["brightnessctl"]
        if (root.device.length > 0)
            cmd.push("-d", root.device)
        cmd.push("set", pct + "%" + (delta < 0 ? "-" : "+"))
        setProc.command = cmd
        setProc.running = true
    }

    // "nvidia_0,backlight,81,81%,100" — device, class, current,
    // percent, max. One line per device; the first is the one
    // brightnessctl itself treats as the default.
    Process {
        id: getProc
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.trim().split("\n")[0].split(",")
                if (parts.length >= 4) {
                    root.device = parts[0]
                    root.brightness = parseInt(parts[3]) / 100
                    root.available = true
                }
                root.updated()
            }
        }
    }

    // read back only after the write lands, so the UI never shows a
    // stale value
    Process {
        id: setProc
        onExited: if (root.active) root.refresh()
    }

    Timer {
        interval: 2000
        running: root.active
        repeat: true
        onTriggered: root.refresh()
    }
}
