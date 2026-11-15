// Monitors.qml — the display manager's data.
//
// Reads `hyprctl monitors all -j` rather than Hyprland's QML service:
// `Hyprland.monitors` reports only ACTIVE outputs, and this page's
// whole job is the ones that are not — a projector that is plugged in
// and switched off is a row it has to show. `all` lists every
// connected output either way, and a disabled one keeps its last mode
// and scale in the JSON, so the page can still edit them.
//
// Writes go through `hyprctl eval 'hl.monitor({...})'`. `hyprctl
// keyword` is dead on this Lua-config Hyprland ("keyword can't work
// with non-legacy parsers"), and eval's Lua call is the config's own.
// Verified against a headless output (`hyprctl output create
// headless`), which is how the multi-monitor paths were probed on a
// machine with one physical panel:
//
//   - `hl.monitor` MERGES into the stored rule. A spec that omits
//     `mode` leaves the previous mode standing (probed: pinned eDP-1
//     to 60Hz, applied a spec without `mode`, still 60Hz), so each
//     control sends only the field it changes.
//   - `mirror = ""` unmirrors — `mirrorOf` goes back to "none" and
//     the output returns to its own position.
//   - `disabled = true` keeps the output in `monitors all`.
//   - `position = "auto-left"` (and -right/-up/-down) arranges the
//     output against the existing ones; the resolved x/y comes back
//     in the read.
//   - An UNSUPPORTED mode does not error. Hyprland silently falls
//     back to the preferred mode and still exits 0 (probed with
//     "999x999@60", which dropped eDP-1 to 60Hz), which is why the
//     page only ever offers modes out of `availableModes` and never
//     a free-form string.
//   - `mirrorOf` in the JSON is the source monitor's ID as a string
//     ("0"), not its name — `parse` resolves it in a second pass.
//   - A bad field or a Lua syntax error prints `error: ...` and exits
//     7. That is the only failure signal, and it is why the queue
//     keeps stderr.
//
// Polling is gated on `active` (the page's visibility), so nothing
// forks while the card is closed. The page is a persistent instance
// behind a visible flag — ThemeCard's mould — so the read runs on the
// way in rather than at shell load.
import QtQml
import QtQuick
import Quickshell
import Quickshell.Io

pragma Singleton

Singleton {
    id: root

    // driven by the page's visibility; see the header comment
    property bool active: false
    property bool available: false
    // one entry per connected output, active and disabled alike.
    // Normalized: `mirrorOf` is a NAME ("" when not mirroring),
    // `modes` is `availableModes` with the "Hz" suffix stripped
    // because that is what `hl.monitor` takes back.
    property var monitors: []
    // one readable line after a failed apply
    property string lastError: ""

    signal updated()

    readonly property var activeMonitors: monitors.filter(function (m) {
        return !m.disabled
    })
    readonly property int activeCount: activeMonitors.length
    readonly property int mirroredCount: activeMonitors.filter(function (m) {
        return m.mirrorOf.length > 0
    }).length

    // ---- lookups --------------------------------------------------------
    function byName(name) {
        for (var i = 0; i < root.monitors.length; i++) {
            if (root.monitors[i].name === name)
                return root.monitors[i]
        }
        return null
    }

    // mirrorOf arrives as the source's id, not its name, so `parse`
    // resolves it in a second pass over the list it just built

    // the displays a given output may mirror, which is every other
    // active one — you cannot mirror onto something that is off
    function mirrorTargets(name) {
        return root.activeMonitors.filter(function (m) {
            return m.name !== name
        })
    }

    // ---- reading --------------------------------------------------------
    function refresh() {
        if (!readProc.running)
            readProc.running = true
    }

    function parse(text) {
        var raw = null
        try {
            raw = JSON.parse(text)
        } catch (e) {
            raw = null
        }
        if (!raw || !raw.length) {
            // an empty array is a real answer (every output off) and
            // reads as available; a parse failure does not
            root.available = raw !== null
            root.monitors = []
            root.updated()
            return
        }
        var out = []
        for (var i = 0; i < raw.length; i++) {
            var m = raw[i]
            var modes = []
            var am = m.availableModes || []
            for (var j = 0; j < am.length; j++)
                modes.push(String(am[j]).replace(/Hz$/, ""))
            var mirror = m.mirrorOf
            out.push({
                name: m.name,
                description: m.description || "",
                make: m.make || "",
                model: m.model || "",
                id: m.id,
                width: m.width,
                height: m.height,
                refreshRate: m.refreshRate,
                scale: m.scale,
                x: m.x,
                y: m.y,
                disabled: m.disabled === true,
                // the source's id for now — resolved to a name in the
                // second pass, since the map only exists once every
                // output is in `out`
                mirrorOf: (mirror === undefined || mirror === null
                           || mirror === "none" || mirror === "")
                    ? "" : String(mirror),
                focused: m.focused === true,
                transform: m.transform,
                modes: modes
            })
        }
        // second pass: id -> name. `nameOfId` reads `root.monitors`,
        // which is still the PREVIOUS list while this loop runs, so
        // the map has to come off `out` itself.
        for (var k = 0; k < out.length; k++) {
            if (out[k].mirrorOf.length === 0)
                continue
            var source = ""
            for (var n = 0; n < out.length; n++) {
                if (String(out[n].id) === out[k].mirrorOf) {
                    source = out[n].name
                    break
                }
            }
            out[k].mirrorOf = source
        }
        root.available = true
        root.monitors = out
        root.updated()
    }

    // ---- writing --------------------------------------------------------
    // One process, drained from a queue: `running = true` on an
    // already-running Process is a silent no-op (the trap AppAudio's
    // slider writes and Wallpapers' picks queue around), and two
    // control clicks in one gesture would otherwise drop the first.
    property var pending: []

    function enqueue(snippet) {
        root.lastError = ""
        root.pending = root.pending.concat([snippet])
        root.drain()
    }

    function drain() {
        if (applyProc.running || root.pending.length === 0)
            return
        var next = root.pending[0]
        root.pending = root.pending.slice(1)
        applyProc.command = ["hyprctl", "eval", next]
        applyProc.running = true
    }

    // Output names are `eDP-1` / `HDMI-A-1` / `DP-3` — alphanumerics,
    // dashes, dots. The check keeps anything else out of the Lua
    // string, and the quote/backslash escape keeps a stray character
    // from ending it early.
    function luaStr(s) {
        return "\"" + String(s).replace(/\\/g, "\\\\").replace(/"/g, "\\\"") + "\""
    }

    function applySpec(name, fields) {
        if (!/^[A-Za-z0-9._-]+$/.test(name)) {
            root.lastError = "Unrecognised output name"
            return
        }
        var parts = ["output=" + root.luaStr(name)]
        for (var i = 0; i < fields.length; i++)
            parts.push(fields[i])
        root.enqueue("hl.monitor({" + parts.join(",") + "})")
    }

    function setDisabled(name, off) {
        root.applySpec(name, ["disabled=" + (off ? "true" : "false")])
    }

    // `mode` is a `availableModes` entry with "Hz" stripped, e.g.
    // "2560x1600@165.02"
    function setMode(name, mode) {
        if (String(mode).length === 0)
            return
        root.applySpec(name, ["mode=" + root.luaStr(mode)])
    }

    function setScale(name, s) {
        root.applySpec(name, ["scale=" + Number(s)])
    }

    // "" extends again — verified to clear `mirrorOf` rather than
    // storing an empty target
    function setMirror(name, source) {
        root.applySpec(name, ["mirror=" + root.luaStr(source)])
    }

    // "auto-left" / "auto-right" / "auto-up" / "auto-down"
    function setPosition(name, preset) {
        root.applySpec(name, ["position=" + root.luaStr(preset)])
    }

    // 0..3 = 0/90/180/270 degrees. Hyprland also takes 4..7 for the
    // flipped variants (probed: 9 is rejected with "more than the
    // maximum of 7"), which the page does not offer — the four
    // unflipped ones cover a portrait monitor and an inverted
    // projector, and a flip is not something a card should guess at.
    function setTransform(name, t) {
        var n = Math.round(Number(t))
        if (!(n >= 0 && n <= 3))
            return
        root.applySpec(name, ["transform=" + n])
    }

    // Focus is a dispatch, not a monitor rule — it is what decides
    // where a new window opens, which is the "primary display" idea
    // Hyprland actually has.
    function focusMonitor(name) {
        if (!/^[A-Za-z0-9._-]+$/.test(name))
            return
        Hyprland.dispatch("hl.dsp.focus({monitor=" + root.luaStr(name) + "})")
    }

    // ---- the processes --------------------------------------------------
    Process {
        id: readProc
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(this.text)
        }
    }

    Process {
        id: applyProc
        command: ["hyprctl", "eval", ""]
        stdout: StdioCollector { id: applyOut }
        stderr: StdioCollector { id: applyErr }
        onExited: (code) => {
            // hyprctl exits 0 on a monitor rule it merely could not
            // satisfy (an unsupported mode falls back silently), so
            // the code alone is not the signal — but a rejected field
            // or a Lua error does print `error: ...` and exit 7
            var text = (applyOut.text || "") + "\n" + (applyErr.text || "")
            if (code !== 0 || text.indexOf("error:") >= 0) {
                var line = text.split("\n")[0]
                    .replace(/^error:\s*/, "").replace(/^\s+|\s+$/g, "")
                root.lastError = line.length > 0
                    ? line : "Could not apply the change"
            }
            // whatever just happened changed the world: re-read so
            // the rows and the panel show the result
            root.refresh()
            root.drain()
        }
    }

    Timer {
        interval: 2000
        running: root.active
        repeat: true
        onTriggered: root.refresh()
    }
}
