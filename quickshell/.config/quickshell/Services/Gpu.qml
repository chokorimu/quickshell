// Gpu.qml — NVIDIA dGPU via nvidia-smi.
//
// nvidia-smi prints "util, used, total" as CSV with no header and no
// units; VRAM comes back in MiB and is converted to GiB here.
//
// available starts false and is reset to false on ANY failure — a
// non-zero exit (nvidia-smi missing, no NVIDIA driver) or output that
// does not parse — because this box has a dGPU but the shell has to
// survive on machines that do not, and the consuming page needs a
// reliable n/a signal. Same active-gated polling as Cpu/Brightness:
// no forking at boot, the timer runs only while the page is on screen.
import QtQml
import QtQuick
import Quickshell
import Quickshell.Io

pragma Singleton

Singleton {
    id: root

    // 0..1
    property real fraction: 0
    property real usedVramGb: 0
    property real totalVramGb: 0
    property bool available: false
    // driven by the consumer's visibility; see the header comment
    property bool active: false

    signal updated()

    function refresh() {
        if (!gpuProc.running)
            gpuProc.running = true
    }

    Process {
        id: gpuProc
        command: ["nvidia-smi", "--query-gpu=utilization.gpu,memory.used,memory.total", "--format=csv,noheader,nounits"]
        stdout: StdioCollector {
            onStreamFinished: {
                // "40, 2077, 6144" — one line, three comma-separated ints
                var f = this.text.trim().split("\n")[0].split(",")
                var util = parseInt(f[0])
                var used = parseInt(f[1])
                var total = parseInt(f[2])
                if (f.length >= 3 && !isNaN(util) && !isNaN(used) && !isNaN(total)) {
                    root.fraction = Math.max(0, Math.min(1, util / 100))
                    root.usedVramGb = used / 1024
                    root.totalVramGb = total / 1024
                    root.available = true
                } else {
                    root.available = false
                }
                root.updated()
            }
        }
        // a failed exec (no nvidia-smi on PATH) exits non-zero with
        // empty stdout; either way available must end up false
        onExited: (exitCode) => {
            if (exitCode !== 0)
                root.available = false
        }
    }

    Timer {
        interval: 2000
        running: root.active
        repeat: true
        onTriggered: root.refresh()
    }
}
