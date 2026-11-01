// AppAudio.qml — per-application volume, pavucontrol style.
//
// Quickshell's Pipewire service can't see nodes on this machine (the
// default sink stays ready:false), so this polls pactl instead — the
// same trade Audio.qml already makes with wpctl. pactl speaks the
// pipewire-pulse protocol and lists every playback stream ("sink
// input") with its app name, volume and mute state, and writes go
// back through set-sink-input-volume / set-sink-input-mute.
//
// Streams come and go as apps start and stop audio, so the list is
// polled rather than event-driven; two seconds matches Audio.qml's
// cadence. Volumes above 100% are legal in pipewire (boost up to
// 150%), so the model carries whatever pactl reports and setVolume
// clamps to that range.
//
// Writes go through a one-deep queue drained by the process's own
// exit: a slider drag fires many writes in quick succession, and a
// bare `running = true` on an already-running Process is a no-op, so
// without the queue every write but the first would be silently
// dropped. A refresh follows only once the queue empties, so a burst
// of drags costs one read-back instead of one per write.
import QtQml
import QtQuick
import Quickshell
import Quickshell.Io

pragma Singleton

Singleton {
    id: root

    // each entry: { id, app, volume (0..1.5), muted }
    property var streams: []

    // pending write commands, drained one at a time
    property var queue: []

    signal updated()

    // boost headroom, matching pavucontrol's over-unity range
    readonly property real maxVolume: 1.5

    function refresh() {
        if (!listProc.running)
            listProc.running = true
    }

    function setVolume(id, v) {
        var clamped = Math.max(0, Math.min(root.maxVolume, v))
        queue.push(["pactl", "set-sink-input-volume", String(id), Math.round(clamped * 100) + "%"])
        pump()
    }

    function toggleMute(id) {
        queue.push(["pactl", "set-sink-input-mute", String(id), "toggle"])
        pump()
    }

    function pump() {
        if (ctlProc.running || queue.length === 0)
            return
        ctlProc.command = queue.shift()
        ctlProc.running = true
    }

    Process {
        id: listProc
        command: ["pactl", "list", "sink-inputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.streams = parseStreams(this.text)
                root.updated()
            }
        }
    }

    // drain the queue, then read back so the UI never shows a stale value
    Process {
        id: ctlProc
        onExited: {
            if (queue.length > 0)
                pump()
            else
                root.refresh()
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()

    // pactl prints one "Sink Input #N" block per stream; the fields we
    // want are Mute, the first channel's percentage, and the app name
    // (application.name, falling back to node.name, then the raw id)
    function parseStreams(text) {
        var out = []
        var blocks = text.split(/Sink Input #/)
        for (var i = 1; i < blocks.length; i++) {
            var b = blocks[i]
            var id = parseInt(b, 10)
            if (isNaN(id))
                continue

            var mute = /\bMute:\s*yes/i.test(b)

            // "Volume: front-left: 65533 /  75% / -7.50 dB, ..." — first
            // channel's percentage is the stream level
            var vol = /Volume:[^\n]*?\/\s*([0-9]+)%/.exec(b)
            var volume = vol ? parseInt(vol[1], 10) / 100 : 1

            var name = /application\.name\s*=\s*"([^"]*)"/.exec(b)
            if (!name)
                name = /node\.name\s*=\s*"([^"]*)"/.exec(b)
            var app = name ? name[1] : "#" + id

            out.push({ id: id, app: app, volume: volume, muted: mute })
        }
        return out
    }
}
