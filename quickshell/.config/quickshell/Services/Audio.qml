// Audio.qml — system volume and mute.
//
// Polls wpctl instead of using Quickshell's Pipewire service: on this machine
// the Pipewire service leaves the default sink node unbound (node.ready stays
// false), so sink.audio.volume reads 0 while wpctl reports the real value.
// One short-lived wpctl every 2s is cheaper than debugging that.
import QtQml
import QtQuick
import Quickshell
import Quickshell.Io

pragma Singleton

Singleton {
    id: root

    // 0..1
    property real volume: 0
    property bool muted: false
    property bool available: false

    signal updated()

    function refresh() {
        if (!volProc.running)
            volProc.running = true
    }

    function setVolume(v) {
        // 1.5 headroom so the master row in the volume card matches the
        // app rows' boost range (pavucontrol's over-unity default)
        var clamped = Math.max(0, Math.min(1.5, v))
        ctlProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", clamped.toFixed(3)]
        ctlProc.running = true
    }

    // delta is in 0..1 units; its sign picks the direction
    function nudge(delta) {
        var pct = Math.round(Math.abs(delta) * 100)
        if (pct < 1)
            pct = 1
        ctlProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", pct + "%" + (delta < 0 ? "-" : "+")]
        ctlProc.running = true
    }

    function toggleMute() {
        ctlProc.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
        ctlProc.running = true
    }

    Process {
        id: volProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                // "Volume: 0.75" or "Volume: 0.75 [MUTED]"
                var m = /Volume:\s*([0-9.]+)/.exec(this.text)
                if (m) {
                    root.volume = parseFloat(m[1])
                    root.available = true
                }
                root.muted = this.text.indexOf("[MUTED]") !== -1
                root.updated()
            }
        }
    }

    // read back only after the write lands, so the UI never shows a stale value
    Process {
        id: ctlProc
        onExited: root.refresh()
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()
}
