// ClipboardPins.qml — the capture page's pinned clipboard entries.
//
// cliphist owns the rolling history; this owns the entries the user
// pinned out of it. A pin is a record — the cliphist id, the preview
// line and the image flag — and the entry itself STAYS in cliphist's
// db, so a pinned row decodes exactly the way an unpinned one does.
// What pinning changes is only where the row renders: pinned records
// come first, and the cliphist list is filtered by id so a pinned
// entry never shows twice.
//
// That split is what makes the label row's Clear pill safe. It cannot
// be cliphist's own wipe any more — that would take the pinned
// entries with it — so it deletes the unpinned ids one at a time and
// never touches a pinned one. Pins survive a clear by construction
// rather than by being re-stored afterwards, and unpinning is just
// dropping the record: the entry is still in cliphist, so it falls
// back into the history list at its own position.
//
// Persistence is a JSON FileView at ~/.local/state/quickshell,
// NotificationHistory's pattern verbatim: PersistentProperties only
// spans hot reloads in 0.3.2, and state files belong in
// ~/.local/state rather than ~/.config/quickshell, which is this
// repo through stow.
import QtQml
import Quickshell
import Quickshell.Io

pragma Singleton

Singleton {
    id: root

    // Newest pin first — the same newest-first order the cliphist
    // list itself keeps, so pinning reads as the entry moving up
    // rather than as a second list with its own rules. Plain JS
    // objects: id (cliphist's own, a decimal string), preview (the
    // line cliphist printed, cut at its preview width) and image
    // (cliphist's binary marker, so an image row reads dim).
    property var entries: []

    readonly property string pinsPath: Quickshell.env("HOME")
        + "/.local/state/quickshell/clipboard-pins"

    // Pin an entry the capture page read out of cliphist. The record
    // is a copy, not the model object itself: the delegate's
    // modelData is destroyed with its row, and a reference to it
    // would go stale under the ListView.
    function pin(entry) {
        var next = root.entries.slice()
        next.unshift({
            id: entry.id,
            preview: entry.preview,
            image: entry.image === true
        })
        root.entries = next
    }

    // Drop a pin by its cliphist id — the unpin path. The per-row
    // delete calls this too and then deletes the entry from cliphist
    // as well; the record op is the same either way, so there is one
    // function rather than two. The copy-then-splice keeps the
    // reassignment a real change, so the ListView re-lays out and the
    // write-back fires.
    function drop(id) {
        var next = root.entries.slice()
        for (var i = 0; i < next.length; i++) {
            if (next[i].id === id) {
                next.splice(i, 1)
                break
            }
        }
        root.entries = next
    }

    FileView {
        id: pinsFile
        path: root.pinsPath
        // A small local file, and the singleton is constructed while
        // the shell loads, so the blocking read costs microseconds
        // and the first frame paints the persisted pins.
        blockLoading: true
        // A missing file is the normal first boot. Errors stay quiet
        // so the log is not carrying a load failure on every fresh
        // start, and the file is created on the spot holding the
        // current (empty) state.
        printErrors: false
        onLoadFailed: pinsFile.setText(payload())
    }

    function payload() {
        return JSON.stringify({ entries: root.entries })
    }

    // Read once, at construction: text() blocks until the load has
    // resolved. A plain assignment rather than a binding on purpose
    // — a binding re-evaluates when the load settles and emits a
    // change signal even when the value is unchanged, which would
    // rewrite the file on every boot.
    Component.onCompleted: {
        var text = pinsFile.text().trim()
        if (text.length === 0)
            return
        try {
            var data = JSON.parse(text)
            if (Array.isArray(data.entries))
                root.entries = data.entries
        } catch (e) {
            // a corrupt file is overwritten on the next change
            // rather than blocking the shell
        }
    }

    // Every change after that is written straight back. The content
    // check keeps the boot-time assignment from rewriting the file
    // with the value it already holds.
    function persist() {
        if (pinsFile.text().trim() !== payload())
            pinsFile.setText(payload())
    }

    onEntriesChanged: persist()
}
