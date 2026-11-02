// Wallpapers.qml — the wallpaper directory and the setter.
//
// Lists ~/.config/rofi/wallpapers, the directory the rofi wallpaper
// menu (SUPER+G) reads from, and applies a pick exactly the way that
// menu does: awww for the transition, then matugen to regenerate the
// palette from the new image. The directory is runtime data and is
// not part of this repo, so it is listed at runtime rather than
// referenced as a checked-in path.
//
// There is no polling here. Listing is a one-shot find and the
// current wallpaper is a one-shot awww query, both driven by the
// consumer opening the page — the theme page is the only consumer,
// and unlike the sliders nothing here needs to track live changes.
import QtQml
import QtQuick
import Quickshell
import Quickshell.Io

pragma Singleton

Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME")
        + "/.config/rofi/wallpapers"

    // full paths, sorted — the grid's model
    property var paths: []
    // the wallpaper awww reports as displayed, for the selected ring
    property string current: ""

    signal loaded()

    function refresh() {
        if (!listProc.running)
            listProc.running = true
        if (!queryProc.running)
            queryProc.running = true
    }

    // Apply a pick. The two steps are chained rather than run through
    // a shell so the path never needs quoting — these filenames carry
    // spaces and non-Latin characters. A click landing while a
    // previous pick is still transitioning would be dropped by a
    // bare `running = true` (a silent no-op on a running Process), so
    // the newest pick waits in a one-deep queue drained by matugen's
    // exit.
    function set(path) {
        if (awwwProc.running) {
            root.pending = path
            return
        }
        root.applying = path
        // the ring moves on the click, not when the transition ends:
        // awww takes 2.5s to grow the new wallpaper in, and a
        // selection that only highlights once the wallpaper is
        // already up reads as a dropped click
        root.current = path
        awwwProc.command = ["awww", "img", path,
            "--transition-type", "grow",
            "--transition-duration", "2.5",
            "--transition-fps", "60"]
        awwwProc.running = true
    }

    property string applying: ""
    property string pending: ""

    // the same extension set the rofi menu's find uses
    Process {
        id: listProc
        command: ["find", root.dir, "-maxdepth", "1", "-type", "f", "(",
            "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.png",
            "-o", "-iname", "*.webp", "-o", "-iname", "*.gif", ")"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                var lines = this.text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var l = lines[i].trim()
                    if (l.length > 0)
                        out.push(l)
                }
                out.sort()
                root.paths = out
                root.loaded()
            }
        }
    }

    // ": eDP-1: 1600x1000, scale: 1.6, currently displaying: image:
    //  /path/to/file.png" — one line per monitor, the path last, so
    //  it is taken to end-of-line and survives spaces in the name.
    //  The first monitor's wallpaper wins.
    Process {
        id: queryProc
        command: ["awww", "query"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n")
                var found = ""
                for (var i = 0; i < lines.length; i++) {
                    var m = /currently displaying: image: (.+)$/.exec(lines[i].trim())
                    if (m) {
                        found = m[1]
                        break
                    }
                }
                root.current = found
            }
        }
    }

    Process {
        id: awwwProc
        onExited: {
            matugenProc.command = ["matugen", "image", root.applying,
                "--prefer", "saturation"]
            matugenProc.running = true
        }
    }

    Process {
        id: matugenProc
        onExited: {
            // the palette is regenerated — drain the queue. `current`
            // was already moved in set(), so there is nothing to
            // update here beyond the next pick.
            if (root.pending.length > 0) {
                var next = root.pending
                root.pending = ""
                root.set(next)
            }
        }
    }
}
