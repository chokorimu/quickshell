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
// ALWAYS ON — cava starts with the shell and never stops. That is a
// deliberate trade, not an oversight, and here is the measurement
// behind it. cava's cold start is ~375ms: 16ms of exec and config
// parse, then ~360ms from opening the audio input to its first frame
// on stdout. It is not a buffer fill (dumping 2s of audio into the
// fifo ahead of time does not shorten it) and not framerate-dependent
// (30, 60 and 240fps all land at ~400ms) — it is a fixed warm-up
// inside cava. Confirmed on the real pipewire path too, not just a
// fifo. Its steady-state latency is only 21ms, so the bars track the
// music tightly; the delay was never the audio pipeline, only the
// start. Gating the process on the media page therefore paid 375ms on
// every open — invisible on a hover-open, where the 300ms pop hides
// ~300ms of it, and fully exposed on a tab switch, which has no
// animation to hide behind.
//
// The warm cost, measured: 1.3% of one core and ~88MB RSS. That is
// less than the pollers this shell already runs forever — AppAudio
// forks pactl every 2s for the life of the session — so it buys a
// media tab that is live the instant it appears for a price the shell
// was already paying elsewhere.
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

    Process {
        id: cavaProc
        // running from the start, not from a consumer's visibility —
        // see the header comment for the cold-start measurement.
        running: true
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
