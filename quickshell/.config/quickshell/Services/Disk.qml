// Disk.qml — root filesystem usage via df.
//
// df -B1 / prints a header line plus one row; the header is skipped and
// the row's 1B-blocks and Used columns are converted to GiB
// (bytes / 1024^3 — the same convention as Memory.qml's kB / 1048576).
// 5s timer rather than 2s: disk usage changes on a human timescale and
// there is no point forking df more often. Same active-gated polling as
// Cpu/Gpu/Brightness — no forking at boot.
//
// One trap worth knowing: GNU df wraps an over-long device name onto its
// own line, which would leave the numbers row one field short. The
// length check below skips anything that is not a full row, so a wrapped
// name fails safe to available=false rather than parsing garbage.
// /dev/nvme0n1p6 is short enough that the row stays on one line here.
import QtQml
import QtQuick
import Quickshell
import Quickshell.Io

pragma Singleton

Singleton {
    id: root

    // 0..1
    property real fraction: 0
    property real usedGb: 0
    property real totalGb: 0
    property bool available: false
    // driven by the consumer's visibility; see the header comment
    property bool active: false

    signal updated()

    function refresh() {
        if (!dfProc.running)
            dfProc.running = true
    }

    Process {
        id: dfProc
        command: ["df", "-B1", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    // skip the header; the data row is the one that is
                    // not it
                    if (lines[i].indexOf("Filesystem") === 0)
                        continue
                    var f = lines[i].trim().split(/\s+/)
                    // filesystem, 1B-blocks, used, available, use%, mount
                    if (f.length < 6)
                        continue
                    var size = parseInt(f[1])
                    var used = parseInt(f[2])
                    if (isNaN(size) || isNaN(used) || size <= 0)
                        continue
                    root.totalGb = size / 1073741824
                    root.usedGb = used / 1073741824
                    root.fraction = used / size
                    root.available = true
                    break
                }
                root.updated()
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
