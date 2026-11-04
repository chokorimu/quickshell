// PowerProfiles.qml — the power-profiles-daemon profile, via
// powerprofilesctl.
//
// UPower does not expose a PowerProfiles interface on this machine
// (verified: the introspection call fails with "No interface
// org.freedesktop.UPower.PowerProfiles"), and Quickshell 0.3.2 has
// no service for PPD either, so this shells out. power-profiles-
// daemon is active with performance / balanced / power-saver
// available.
//
// The island's battery-saver tile is the only consumer, so this
// polls in Brightness's active-gated mould: nothing forks while the
// card is closed.
//
// The profile is not only a readout, though: power-saver also turns
// hyprland's blur off and pins both window opacities at 1, and
// leaving it puts them back. That lives here rather than in the
// tile's onClicked so it follows the profile wherever the change
// came from — the tile, a terminal, another tool — and so a boot
// that comes up already in power-saver gets the decorations right
// without anyone opening the card.
import QtQml
import QtQuick
import Quickshell
import Quickshell.Io

pragma Singleton

Singleton {
    id: root

    // "performance" | "balanced" | "power-saver" | ""
    property string profile: ""
    property bool available: false

    readonly property bool saverOn: profile === "power-saver"

    // flipped by the page: the tile is the only reader
    property bool active: false

    // The profile whose decoration state hyprland is currently
    // wearing. Every read is checked against it, so the 5s poll does
    // not re-fork hyprctl and a decoration changed by hand is not
    // fought every five seconds — only a real profile change (or a
    // forced re-sync) moves it.
    property string applied: ""

    // the profile the in-flight apply was issued for. `applied` only
    // moves to it once the process exits cleanly, so an apply that
    // never started — hyprctl missing, say — is retried on the next
    // read instead of being remembered as done.
    property string pending: ""

    // effects.lua's own values, mirrored here so leaving the saver
    // puts the desktop back exactly as the config left it. The blur
    // flag and the two opacities are the whole decoration contract
    // this touches; if the config changes, these change with it.
    readonly property string normalDecorations:
        "hl.config({decoration={blur={enabled=true},active_opacity=0.95,inactive_opacity=0.95}})"
    readonly property string saverDecorations:
        "hl.config({decoration={blur={enabled=false},active_opacity=1.0,inactive_opacity=1.0}})"

    function refresh() {
        if (!getProc.running)
            getProc.running = true
    }

    // the tile is a two-state switch over a three-profile daemon:
    // saver on pins power-saver, saver off goes back to balanced
    // rather than performance — the profile the machine idles in
    function setSaver(on) {
        setProc.command = ["powerprofilesctl", "set", on ? "power-saver" : "balanced"]
        if (!setProc.running)
            setProc.running = true
    }

    // Put hyprland's decorations in the state the current profile
    // asks for. Gated on available so a dead daemon leaves the last
    // applied state alone rather than restoring on a hiccup, and
    // deduped against `applied` so only a real change forks.
    function syncDecorations() {
        if (!root.available)
            return
        if (root.profile === root.applied)
            return
        // an apply already in flight settles itself on exit;
        // re-issuing now would only reassign a command the running
        // process ignores
        if (decorateProc.running)
            return
        root.pending = root.profile
        // Process.command is a QStringList — a bare string becomes
        // the program name and the process fails to start
        decorateProc.command = ["hyprctl", "eval",
            root.profile === "power-saver"
                ? root.saverDecorations : root.normalDecorations]
        decorateProc.running = true
    }

    // prints the active profile's name and nothing else
    Process {
        id: getProc
        command: ["powerprofilesctl", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = this.text.trim()
                if (p.length > 0) {
                    root.available = true
                    root.profile = p
                    root.syncDecorations()
                }
            }
        }
        onExited: (code) => {
            if (code !== 0) {
                root.available = false
                root.profile = ""
            }
        }
    }

    Process {
        id: setProc
        onExited: root.refresh()
    }

    // One read at construction, before anything opens the card:
    // hyprland re-reads its config on every compositor restart, so a
    // session that comes up already in power-saver would otherwise
    // sit with the blur on until the card is first opened. The
    // singleton is constructed at shell load — NotificationsCard
    // binds saverOn and available in its tile's property bindings —
    // so this runs once, at boot, and the active-gated polling below
    // carries the rest.
    Component.onCompleted: root.refresh()

    // Opening the card forces one re-sync for the same reason: the
    // compositor may have restarted since the last read. Clearing
    // the applied marker makes the refresh the page already does on
    // the way in carry the decorations with it.
    onActiveChanged: if (active) { root.applied = ""; root.refresh() }

    // hyprctl keyword is dead on this machine — "keyword can't work
    // with non-legacy parsers. Use eval." — because hyprland runs a
    // Lua config. The eval form is the config's own hl.config({...})
    // call, which merges rather than replaces, so one call carries
    // all three settings. Verified in both directions against the
    // running compositor.
    Process {
        id: decorateProc
        onExited: (code) => {
            // only a clean exit means hyprland is wearing `pending`'s
            // state. A process that failed to start fires no exit at
            // all, so `applied` stays put and the next read retries
            // rather than remembering the apply as done.
            if (code === 0)
                root.applied = root.pending
        }
    }

    Timer {
        interval: 5000
        running: root.active
        repeat: true
        onTriggered: root.refresh()
    }
}
