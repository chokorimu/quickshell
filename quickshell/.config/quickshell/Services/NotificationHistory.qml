// NotificationHistory.qml — the island's notification log and its
// do-not-disturb flag.
//
// Two things live here because they share one state file: the dnd
// flag the notifications tab toggles, and the capped history the
// same page lists. The history is fed from Notifications.qml's
// onNotification handler — one extra line there — so the server's
// ownership of org.freedesktop.Notifications, its keepOnReload and
// its capability advertisement all stay untouched.
//
// DND needs no daemon on this machine: the server DISCARDS any
// notification a handler does not mark tracked (see the note in
// Notifications.qml), so suppressing popups is simply not marking
// them. The history records everything either way — the append
// happens before the tracked decision, and it copies every field it
// needs out of the notification on the spot, because the server
// deletes the object the moment it goes untracked.
//
// Persistence is a JSON FileView at ~/.local/state/quickshell,
// Theme.qml's theme-mode pattern verbatim: PersistentProperties only
// spans hot reloads in 0.3.2, and state files belong in
// ~/.local/state rather than ~/.config/quickshell, which is this
// repo through stow.
import QtQml
import QtQuick
import Quickshell
import Quickshell.Io

pragma Singleton

Singleton {
    id: root

    // ---- do not disturb ------------------------------------------------
    property bool dnd: false

    // ---- history -------------------------------------------------------
    // Newest first, capped. Plain JS objects — app (display name),
    // icon (icon name), summary, body, urgency (0 low / 1 normal /
    // 2 critical), time (ms since epoch, Date.now() at receipt).
    //
    // Freedesktop notifications carry no timestamp of their own, so
    // receipt time is the only one there is. The notification's own
    // image is deliberately NOT stored: it is the sender's avatar
    // served through a transient image:// provider URL, which would
    // read as a broken image after a restart — the rows show the
    // app icon instead, the same fallback NotificationCard uses.
    property var entries: []

    readonly property int maxEntries: 100

    readonly property string historyPath: Quickshell.env("HOME")
        + "/.local/state/quickshell/notification-history"

    function append(notification) {
        var entry = {
            app: notification.appName || "",
            icon: notification.appIcon || "",
            summary: notification.summary || "",
            body: notification.body || "",
            urgency: notification.urgency || 0,
            time: Date.now()
        }
        var next = [entry].concat(root.entries)
        if (next.length > root.maxEntries)
            next = next.slice(0, root.maxEntries)
        root.entries = next
    }

    function clear() {
        root.entries = []
    }

    // Remove one entry by its index in the list — the per-row delete
    // the history list's trash glyph calls. Clear() empties the whole
    // log; this takes the row's own index, the same number the row's
    // divider uses to find the last one. The copy-then-splice keeps
    // the reassignment a real change, so the ListView re-lays out and
    // the write-back fires.
    function remove(index) {
        if (index < 0 || index >= root.entries.length)
            return
        var next = root.entries.slice()
        next.splice(index, 1)
        root.entries = next
    }

    FileView {
        id: historyFile
        path: root.historyPath
        // A small local file, and the singleton is constructed while
        // the shell loads, so the blocking read costs microseconds
        // and the first frame paints the persisted history.
        blockLoading: true
        // A missing file is the normal first boot. Errors stay quiet
        // so the log is not carrying a load failure on every fresh
        // start, and the file is created on the spot holding the
        // current (empty) state.
        printErrors: false
        onLoadFailed: historyFile.setText(payload())
    }

    function payload() {
        return JSON.stringify({ dnd: root.dnd, entries: root.entries })
    }

    // Read once, at construction: text() blocks until the load has
    // resolved. A plain assignment rather than a binding on purpose
    // — a binding re-evaluates when the load settles and emits a
    // change signal even when the value is unchanged, which would
    // rewrite the file on every boot.
    Component.onCompleted: {
        var text = historyFile.text().trim()
        if (text.length === 0)
            return
        try {
            var data = JSON.parse(text)
            if (typeof data.dnd === "boolean")
                root.dnd = data.dnd
            if (Array.isArray(data.entries))
                root.entries = data.entries.slice(0, root.maxEntries)
        } catch (e) {
            // a corrupt file is overwritten on the next change
            // rather than blocking the shell
        }
    }

    // Every change after that is written straight back. The content
    // check keeps the boot-time assignment from rewriting the file
    // with the value it already holds.
    function persist() {
        if (historyFile.text().trim() !== payload())
            historyFile.setText(payload())
    }

    onDndChanged: persist()
    onEntriesChanged: persist()
}
