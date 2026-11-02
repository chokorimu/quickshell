// Cava.qml — bar heights for the media card's background visualizer.
//
// Runs a second, headless cava instance in raw mode and parses its
// stdout into 32 levels. The terminal cava (cava/.config/cava/config)
// draws in a terminal; this one only streams numbers, and the shell
// paints them. cava takes only `-p <config>` on the command line —
// there is no flag for any of this — so the raw config is a separate
// file, cava-raw.conf, deployed next to the shell by stow.
//
// Reading a continuous stream without leaking was the hard part.
// StdioCollector accumulates every byte it has ever seen — measured
// 792 -> 7022 bytes over 8s at 100 lines/s, which at cava's 60fps
// would be ~830MB/day — and its `text` does not even update until the
// stream ends. SplitParser is the answer: it inherits DataStreamParser's
// read(QString) signal, fires it once per splitMarker-delimited chunk
// with the marker stripped, and consumes the buffer. Its `text` stays
// pinned at one frame's worth no matter how long it runs (verified:
// 711 chunks over 8s, text length 9 throughout).
//
// Gated on `active` the same way Brightness is: the process only runs
// while the media card is actually on screen, so a collapsed island
// forks nothing.
import QtQml
import QtQuick
import Quickshell
import Quickshell.Io

pragma Singleton

Singleton {
    id: root

    readonly property int barCount: 32

    // 32 values, 0..1 — one height per bar. Reassigned (never mutated
    // in place) so the change notifies; a JS array is a reference type.
    property var levels: zeroLevels()

    // driven by the consumer's visibility; see the header comment
    property bool active: false

    // Fires once per parsed frame. The consumer's Canvas repaints on
    // this rather than binding to `levels`: reassigning the array
    // notifies, but a Canvas still needs an explicit requestPaint().
    signal frame()

    function zeroLevels() {
        var out = []
        for (var i = 0; i < root.barCount; i++)
            out.push(0)
        return out
    }

    onActiveChanged: {
        if (active) {
            if (!cavaProc.running)
                cavaProc.running = true
        } else {
            // running = false terminates the child (verified: the
            // stream stops dead, no orphan). Drop the last frame's
            // bars too, so the card goes quiet rather than freezing
            // on whatever was playing when it closed.
            if (cavaProc.running)
                cavaProc.running = false
            root.levels = root.zeroLevels()
            root.frame()
        }
    }

    Process {
        id: cavaProc
        command: ["cava", "-p",
            Quickshell.env("HOME") + "/.config/quickshell/cava-raw.conf"]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                // "v0;v1;...;vN" — one frame, marker already stripped.
                // Values are 0..1000 on a fixed scale (bit_format is
                // ignored in ascii mode), so they normalise cleanly.
                var parts = data.split(";")
                if (parts.length < 2)
                    return
                var out = root.zeroLevels()
                var n = Math.min(parts.length, root.barCount)
                for (var i = 0; i < n; i++) {
                    var v = parseInt(parts[i])
                    out[i] = isNaN(v) ? 0 : Math.max(0, Math.min(1000, v)) / 1000
                }
                root.levels = out
                root.frame()
            }
        }
    }
}
