// Memory.qml — RAM usage from /proc/meminfo.
//
// No Quickshell service covers this. MemAvailable rather than MemFree is the
// right basis for "used" on a modern kernel, since it accounts for reclaimable
// page cache.
import QtQml
import QtQuick
import Quickshell
import Quickshell.Io

pragma Singleton

Singleton {
    id: root

    property real totalGb: 0
    property real usedGb: 0
    property real fraction: 0 // 0..1
    property bool available: false

    signal updated()

    function refresh() {
        if (!memProc.running)
            memProc.running = true
    }

    Process {
        id: memProc
        command: ["cat", "/proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: {
                var total = 0
                var avail = 0
                var lines = this.text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var m = /^(\w+):\s+(\d+)\s*kB/.exec(lines[i])
                    if (!m)
                        continue
                    if (m[1] === "MemTotal")
                        total = parseInt(m[2])
                    else if (m[1] === "MemAvailable")
                        avail = parseInt(m[2])
                }
                if (total > 0) {
                    root.available = true
                    root.totalGb = total / 1048576
                    root.usedGb = (total - avail) / 1048576
                    root.fraction = (total - avail) / total
                }
                root.updated()
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()
}
