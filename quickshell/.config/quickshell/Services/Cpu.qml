// Cpu.qml — CPU utilisation from /proc/stat.
//
// The first "cpu " line aggregates every core in jiffies:
// user nice system idle iowait irq softirq steal guest guest_nice.
// Utilisation is a delta between two reads — (Δtotal − Δidle) / Δtotal —
// so the first read only establishes a baseline and fraction stays 0
// until the second one produces a real delta. Two deliberate choices in
// the arithmetic: iowait is NOT folded into idle (top/htop do; the raw
// idle column is the simpler contract), and guest/guest_nice are summed
// as-is even though the kernel already counts them inside user/nice —
// the double-count is negligible unless a VM is pinning cores.
//
// No polling at boot: like Brightness this is gated on `active`, driven
// by the consumer page's visibility, with refresh() called on the way in.
import QtQml
import QtQuick
import Quickshell
import Quickshell.Io

pragma Singleton

Singleton {
    id: root

    // 0..1
    property real fraction: 0
    property bool available: false
    // driven by the consumer's visibility; see the header comment
    property bool active: false

    // previous read's totals in jiffies; hasBaseline flips on the first
    // successful parse so the second read can produce a real delta
    property real prevTotal: 0
    property real prevIdle: 0
    property bool hasBaseline: false

    signal updated()

    function refresh() {
        if (!cpuProc.running)
            cpuProc.running = true
    }

    Process {
        id: cpuProc
        command: ["cat", "/proc/stat"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    // the aggregate line is "cpu " — per-core lines are
                    // "cpu0 ", "cpu1 " and must not match
                    if (!/^cpu\s/.test(lines[i]))
                        continue
                    var f = lines[i].trim().split(/\s+/)
                    var total = 0
                    var idle = 0
                    for (var j = 1; j < f.length; j++) {
                        var v = parseInt(f[j])
                        if (isNaN(v))
                            continue
                        total += v
                        if (j === 4)
                            idle = v
                    }
                    if (root.hasBaseline) {
                        var dTotal = total - root.prevTotal
                        var dIdle = idle - root.prevIdle
                        // two reads inside one jiffy produce no delta —
                        // keep the previous fraction rather than divide
                        // by zero
                        if (dTotal > 0)
                            root.fraction = Math.max(0, Math.min(1, (dTotal - dIdle) / dTotal))
                    }
                    root.prevTotal = total
                    root.prevIdle = idle
                    root.hasBaseline = true
                    root.available = true
                    break
                }
                root.updated()
            }
        }
    }

    Timer {
        interval: 2000
        running: root.active
        repeat: true
        onTriggered: root.refresh()
    }
}
