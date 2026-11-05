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
    // 2 critical), time (ms since epoch, Date.now() at receipt),
    // id (session-unique; pairs an in-flight avatar grab with its
    // entry) and imagePath (a saved copy of the sender's avatar,
    // empty until the grab confirms it landed).
    //
    // Freedesktop notifications carry no timestamp of their own, so
    // receipt time is the only one there is. The notification's own
    // image is the sender's avatar served through a transient
    // image:// provider URL that dies with the Notification object,
    // so it is copied out to disk at receipt — see the capture in
    // Notifications.qml — and the rows show that file. A row whose
    // grab never landed (DND deletes the object before the async
    // load completes) or whose app sent no image falls back to the
    // app icon, the same fallback NotificationCard uses.
    property var entries: []

    readonly property int maxEntries: 100

    readonly property string historyPath: Quickshell.env("HOME")
        + "/.local/state/quickshell/notification-history"

    // Saved avatars live beside the history file, in ~/.local/state
    // — never ~/.config/quickshell, which is this repo through stow,
    // so a file written there would land in git as an untracked
    // artifact. Bounded by maxEntries plus whatever is in flight:
    // every delete path below unlinks, and the boot sweep mops up
    // crash orphans.
    readonly property string imageDir: Quickshell.env("HOME")
        + "/.local/state/quickshell/notification-images"

    // Handed to append()'s caller so an in-flight avatar grab can
    // find its entry again (setImage). Not persisted — it only has
    // to be unique within the session that created it, and loaded
    // entries are normalized to 0, which no live id ever is.
    property int nextId: 1

    // Returns the new entry's id, which the caller pairs with the
    // avatar grab it is about to start. The entry starts with an
    // empty imagePath on purpose: a row must never point at a file
    // that does not exist yet, or Qt logs a load failure per render.
    function append(notification) {
        var entry = {
            id: root.nextId++,
            app: notification.appName || "",
            icon: notification.appIcon || "",
            summary: notification.summary || "",
            body: notification.body || "",
            urgency: notification.urgency || 0,
            time: Date.now(),
            imagePath: ""
        }
        var next = [entry].concat(root.entries)
        if (next.length > root.maxEntries) {
            // the cap drops the tail, and their avatars go with them
            var dropped = next.splice(root.maxEntries)
            for (var i = 0; i < dropped.length; i++)
                unlinkImage(dropped[i].imagePath)
        }
        root.entries = next
        return entry.id
    }

    // Confirms an avatar grab: the entry with this id now has a file
    // at imagePath. The reassignment is what fires the write-back,
    // so the path survives a restart — the whole point of the copy.
    function setImage(id, imagePath) {
        var next = root.entries.slice()
        for (var i = 0; i < next.length; i++) {
            if (next[i].id === id) {
                next[i].imagePath = imagePath
                break
            }
        }
        root.entries = next
    }

    function clear() {
        for (var i = 0; i < root.entries.length; i++)
            unlinkImage(root.entries[i].imagePath)
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
        var removed = next.splice(index, 1)
        unlinkImage(removed[0].imagePath)
        root.entries = next
    }

    // ---- avatar files ---------------------------------------------------
    // One rm queue for every delete path (cap drop, row trash, Clear,
    // boot sweep). running = true on an already-running Process is a
    // silent no-op — the AppAudio/Wallpapers queue trap — so paths
    // wait in `pending` and the next run takes them all; rm accepts
    // many operands, so a burst of deletes costs one fork.
    function unlinkImage(imagePath) {
        if (!imagePath || imagePath.length === 0)
            return
        imageUnlink.pending.push(imagePath)
        imageUnlink.kick()
    }

    Process {
        id: imageUnlink
        property var pending: []
        command: ["rm", "-f"]
        function kick() {
            if (imageUnlink.running || imageUnlink.pending.length === 0)
                return
            imageUnlink.command = ["rm", "-f"].concat(imageUnlink.pending)
            imageUnlink.pending = []
            imageUnlink.running = true
        }
        onExited: imageUnlink.kick()
    }

    // Boot sweep for crash orphans. Every delete path above is exact,
    // but a shell killed between saveToFile and the entry write-back
    // leaves a file nothing references. One listing at start, diffed
    // against the entries, batched through the same queue. The mkdir
    // rides along because saveToFile does not create parent
    // directories and a missing dir is the normal first boot.
    Process {
        id: imageSweep
        command: ["sh", "-c", "mkdir -p \"" + root.imageDir
            + "\" && ls -1 \"" + root.imageDir + "\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var live = {}
                var entries = root.entries
                for (var i = 0; i < entries.length; i++)
                    if (entries[i].imagePath.length > 0)
                        live[entries[i].imagePath] = true
                var files = this.text.split("\n")
                for (var j = 0; j < files.length; j++) {
                    var name = files[j].trim()
                    if (name.length === 0)
                        continue
                    var full = root.imageDir + "/" + name
                    if (!live[full])
                        unlinkImage(full)
                }
            }
        }
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

    // Loaded entries come from a state file written before avatars
    // existed, so they have no id and no imagePath — a row would
    // TypeError on both. Normalize on the way in: id 0 (no live id is
    // ever 0), imagePath "" unless the file carried one. The field
    // whitelist also drops anything a future version adds and an old
    // shell then rewrites.
    function normalizeEntry(entry) {
        return {
            id: 0,
            app: entry.app || "",
            icon: entry.icon || "",
            summary: entry.summary || "",
            body: entry.body || "",
            urgency: entry.urgency || 0,
            time: entry.time || 0,
            imagePath: entry.imagePath || ""
        }
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
        if (text.length > 0) {
            try {
                var data = JSON.parse(text)
                if (typeof data.dnd === "boolean")
                    root.dnd = data.dnd
                if (Array.isArray(data.entries))
                    root.entries = data.entries.slice(0, root.maxEntries).map(normalizeEntry)
            } catch (e) {
                // a corrupt file is overwritten on the next change
                // rather than blocking the shell
            }
        }
        // Runs on every boot, empty history or not: the mkdir inside
        // the sweep is what creates the image dir, and saveToFile
        // makes no parent directories of its own.
        imageSweep.running = true
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
