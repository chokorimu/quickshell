// Media.qml — now-playing via the Mpris service.
//
// The Connections on Mpris.players is load-bearing, not decorative: Quickshell
// initialises its services lazily, and without an observer the players model
// stays empty forever. Shows only the players on the allow-list below —
// Spotify and VLC — and nothing at all when none of them is running.
// VLC needs its own handling (see the VLC block below): it reports no
// usable title for a plain file and no art for a plain video.
import QtQml
import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Io

pragma Singleton

Singleton {
    id: root

    property var player: null
    property bool hasPlayer: false
    property string title: ""
    property string artist: ""
    property string artUrl: ""
    property bool playing: false
    property bool canGoNext: false
    property bool canGoPrevious: false
    // Playback position and track length, in seconds. Polled, never bound
    // to the player's own property: MprisPlayer advances position on its
    // own internal timer but never emits positionChanged while playing
    // (probed — a bound text froze at 29.202 while direct reads ran to
    // 36.147), so a binding on it sits still forever. The timer at the
    // bottom of this file re-reads it twice a second.
    property real position: 0
    property real length: 0
    // The playback stream behind the current player, out of AppAudio's
    // list — the media page's volume bar drives this app's own level
    // rather than the master sink (the volume card's fourth tab owns
    // that). Matched on the player's identity first: VLC reports
    // "VLC media player", which is exactly what pactl prints as
    // application.name. Then the bus name's suffix
    // ("org.mpris.MediaPlayer2.vlc" -> "vlc"), then the identity's
    // first word. Null when the player has no stream in the list yet —
    // the stream appears a moment after the player does — or none at
    // all, and the bar hides itself in that case.
    property var appStream: null

    signal updated()

    // --- VLC -----------------------------------------------------------------
    // VLC is the one allow-listed player that reports neither a usable title
    // nor any art for a plain file: for a bare video it sends no xesam:title
    // at all, and mpris:artUrl only appears when it finds a cover itself
    // (embedded in an audio file, or a cover image sitting beside the file).
    // So both are derived here rather than in the consumers, and Bar.qml and
    // MediaCard.qml need to know nothing about it: the song name is the
    // file's own name, and the art is the file's first video frame — which
    // is the same stream an audio file's embedded cover rides on.
    //
    // Quickshell's MprisPlayer does not expose xesam:url, so it is read off
    // the bus directly with busctl.
    readonly property string vlcArtPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/quickshell-vlc-art.png"
    property string vlcBusName: ""
    property string vlcFileUrl: ""
    property string vlcArtSource: ""
    property string vlcReportedTitle: ""
    property string vlcReportedArt: ""
    property int vlcArtCounter: 0

    function isVlc(p) {
        var bus = (p.dbusName || "").toLowerCase()
        var id = (p.identity || "").toLowerCase()
        return bus.indexOf("vlc") !== -1 || id.indexOf("vlc") !== -1
    }

    // "file:///music/My%20Song.mp3" -> "/music/My Song.mp3"
    function filePathFromUrl(url) {
        var path = url
        try {
            path = decodeURIComponent(url)
        } catch (e) {
            // a malformed escape — the raw URL is still better than nothing
        }
        if (path.indexOf("file://") === 0)
            path = path.substring("file://".length)
        return path
    }

    // "file:///music/My%20Song.mp3" -> "My Song"
    function fileNameFromUrl(url) {
        var path = root.filePathFromUrl(url)
        var slash = path.lastIndexOf("/")
        var name = slash >= 0 ? path.substring(slash + 1) : path
        // dot > 0, not >= 0: a dotfile has no extension to drop
        var dot = name.lastIndexOf(".")
        if (dot > 0)
            name = name.substring(0, dot)
        return name
    }

    function syncVlc(p) {
        root.vlcBusName = p.dbusName || ""
        root.vlcReportedTitle = p.trackTitle || ""
        root.vlcReportedArt = p.trackArtUrl || ""
        root.artist = p.trackArtist || ""
        // The title is deliberately NOT set here. This runs on every
        // metadata event — pause, play, volume, an art refresh — and the
        // derived title has to survive all of them; vlcUrlResolved owns it.
        // Setting it from what VLC reported is what blanked the title on
        // every pause: VLC reports no xesam:title at all for a plain file,
        // and the same-URL guard below then kept the blank in place.
        if (root.vlcFileUrl === "") {
            // Nothing resolved yet — a fresh player, or the state was
            // cleared. Drop the previous player's title rather than show it
            // under VLC's art for the moment the bus query takes, but keep
            // whatever cover VLC reported for itself.
            root.title = ""
            root.artUrl = root.vlcReportedArt
            root.updated()
        }
        root.queryVlcUrl()
    }

    function queryVlcUrl() {
        // running = true on an already-running Process is a silent no-op, so
        // a track change landing mid-query waits in a one-deep queue drained
        // by the exit — the same pattern AppAudio and Wallpapers use
        if (vlcUrlProc.running) {
            vlcUrlProc.pending = true
            return
        }
        vlcUrlProc.running = true
    }

    function vlcUrlResolved(url) {
        // a query that comes back after the player moved on — VLC quit, or
        // Spotify took the slot — must not clobber the new player's state
        if (!root.player || !root.isVlc(root.player))
            return
        if (url === "") {
            // The query came back with no xesam:url: VLC is not answering,
            // or has nothing loaded. Leave whatever is showing alone rather
            // than blanking a title and cover that are still good.
            return
        }
        // the same file as last time — a pause, a volume change, any
        // non-track metadata event. The art is already extracted for it,
        // but the title is re-asserted below regardless.
        var sameFile = (url === root.vlcFileUrl)
        root.vlcFileUrl = url
        if (url.indexOf("file://") !== 0) {
            // a stream, or anything with no file behind it: nothing to name
            // or thumbnail, so fall back to what VLC reported
            root.title = root.vlcReportedTitle
            root.artUrl = root.vlcReportedArt
            root.updated()
            return
        }
        // Re-asserted on every sync, not just on a file change: a pause
        // re-runs the whole chain and the filename must not be lost to
        // whatever VLC reported in the meantime.
        root.title = root.fileNameFromUrl(url)
        root.updated()
        if (sameFile)
            return
        if (root.vlcReportedArt !== "") {
            // VLC found the real cover itself — no need to pull a frame
            root.artUrl = root.vlcReportedArt
            root.updated()
            return
        }
        root.artUrl = ""
        root.vlcArtSource = root.filePathFromUrl(url)
        if (vlcArtProc.running) {
            vlcArtProc.pending = true
            return
        }
        vlcArtProc.running = true
    }

    // Which players the bar will show. Matched against the MPRIS bus
    // name (org.mpris.MediaPlayer2.<name>) first and the identity
    // second, lowercased; the first running player that matches wins.
    // Spotify and VLC — the bar is a now-playing widget, not a mixer,
    // and every browser and stray player used to land here. VLC
    // registers org.mpris.MediaPlayer2.vlc with identity "VLC media
    // player" while it runs, when built with D-Bus support (standard
    // on Linux packages).
    readonly property var allowedPlayers: ["spotify", "vlc"]

    function matches(p) {
        var bus = (p.dbusName || "").toLowerCase()
        var id = (p.identity || "").toLowerCase()
        for (var j = 0; j < root.allowedPlayers.length; j++) {
            var want = root.allowedPlayers[j]
            if (bus.indexOf(want) !== -1 || id.indexOf(want) !== -1)
                return true
        }
        return false
    }

    function pickPlayer() {
        var ps = Mpris.players.values
        var chosen = null
        for (var i = 0; i < ps.length; i++) {
            if (root.matches(ps[i])) {
                chosen = ps[i]
                break
            }
        }
        root.player = chosen
    }

    // Read straight off the player: a property read, not a fork, so this
    // needs none of the page-gating the process-polling services use.
    // Zeroes both when there is no player, so a player going away empties
    // the progress bar in the same pass that blanks the title.
    function refreshPosition() {
        var p = root.player
        root.position = p ? (p.position || 0) : 0
        root.length = p ? (p.length || 0) : 0
    }

    // See the appStream comment. Re-run whenever the player changes and
    // whenever the stream list does: the player's own stream shows up in
    // pactl a moment after the player itself appears on the bus.
    function refreshAppStream() {
        var p = root.player
        if (!p) {
            root.appStream = null
            return
        }
        var id = (p.identity || "").toLowerCase()
        var bus = (p.dbusName || "").toLowerCase()
        var needles = [id, bus.replace("org.mpris.mediaplayer2.", ""), id.split(/\s+/)[0]]
        var streams = AppAudio.streams
        var found = null
        for (var n = 0; n < needles.length && !found; n++) {
            var needle = needles[n]
            if (!needle)
                continue
            for (var i = 0; i < streams.length; i++) {
                if ((streams[i].app || "").toLowerCase().indexOf(needle) !== -1) {
                    found = streams[i]
                    break
                }
            }
        }
        root.appStream = found
    }

    function sync() {
        // position first: refreshPosition zeroes it when there is no
        // player, which is the one case the early return below skips
        root.refreshPosition()
        root.refreshAppStream()
        var p = root.player
        if (!p) {
            root.hasPlayer = false
            root.title = ""
            root.artist = ""
            root.artUrl = ""
            root.playing = false
            root.canGoNext = false
            root.canGoPrevious = false
            // forget the resolved file so a player that comes back on the
            // same file re-derives its title and art instead of being
            // short-circuited by the same-URL guard
            root.vlcFileUrl = ""
            root.vlcBusName = ""
            root.updated()
            return
        }
        root.hasPlayer = true
        root.playing = p.isPlaying
        root.canGoNext = p.canGoNext
        root.canGoPrevious = p.canGoPrevious
        if (root.isVlc(p)) {
            root.syncVlc(p)
            return
        }
        root.title = p.trackTitle || ""
        root.artist = p.trackArtist || ""
        root.artUrl = p.trackArtUrl || ""
        root.updated()
    }

    // forces the lazy Mpris service to populate
    Connections {
        target: Mpris.players
        function onValuesChanged() {
            root.pickPlayer()
            root.sync()
        }
    }

    // the stream list turns over as apps start and stop audio, and the
    // player's own stream lands in it a moment after the player does
    Connections {
        target: AppAudio
        function onStreamsChanged() { root.refreshAppStream() }
    }

    Connections {
        target: root.player
        // postTrackChanged, NOT trackChanged: MprisPlayer emits trackChanged
        // *before* assigning the new metadata — trackTitle/trackArtist/
        // trackArtUrl are bindings on bMetadata, which is set after the
        // signal, inside a property update group. A trackChanged handler
        // therefore reads the PREVIOUS track; postTrackChanged fires after
        // the group closes, with every derived property fresh. (This is
        // what made the bar sit one track behind on every skip.)
        function onPostTrackChanged() { root.sync() }
        // catch-all for metadata updates that aren't track changes (art
        // URL refreshes and the like) — fires after the value is set
        function onMetadataChanged() { root.sync() }
        function onIsPlayingChanged() { root.sync() }
        function onCanGoNextChanged() { root.sync() }
        function onCanGoPreviousChanged() { root.sync() }
    }

    // The position poll. 500ms is the right trade for a progress bar:
    // the line moves twice a second, which reads as motion, without
    // waking the main thread 60 times a second for a number nobody
    // watches frame by frame. Gated on hasPlayer — a property read, so
    // there is nothing to fork and no reason to gate it on the page
    // being open the way the process-polling services are.
    Timer {
        interval: 500
        repeat: true
        running: root.hasPlayer
        onTriggered: root.refreshPosition()
    }

    // xesam:url off the bus. busctl prints the a{sv} dict as
    // "key" <variant-signature> <value>, so a string arrives as
    // "xesam:url" s "file:///..." — there is no literal v in the output.
    Process {
        id: vlcUrlProc
        property bool pending: false
        command: ["busctl", "--user", "get-property", root.vlcBusName,
                  "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player", "Metadata"]
        stdout: StdioCollector {
            onStreamFinished: {
                var url = ""
                var m = this.text.match(/"xesam:url"\s+s\s+"([^"]*)"/)
                if (m)
                    url = m[1]
                root.vlcUrlResolved(url)
            }
        }
        onExited: {
            if (vlcUrlProc.pending) {
                vlcUrlProc.pending = false
                vlcUrlProc.running = true
            }
        }
    }

    // The file's first video frame: a video's opening frame, or an audio
    // file's embedded cover, which is the same stream. Exits 234 and writes
    // nothing at all when the file carries no video stream.
    Process {
        id: vlcArtProc
        property bool pending: false
        command: ["ffmpeg", "-v", "error", "-y", "-i", root.vlcArtSource,
                  "-map", "0:v:0", "-frames:v", "1", root.vlcArtPath]
        onExited: (exitCode) => {
            if (!root.player || !root.isVlc(root.player))
                return
            if (exitCode === 0) {
                // The one path is rewritten per track, so the URL carries a
                // counter: Qt's image cache keys on the URL and would
                // otherwise keep serving the previous track's frame.
                root.vlcArtCounter++
                root.artUrl = "file://" + root.vlcArtPath + "?" + root.vlcArtCounter
            } else {
                root.artUrl = ""
            }
            root.updated()
            if (vlcArtProc.pending) {
                vlcArtProc.pending = false
                vlcArtProc.running = true
            }
        }
    }

    function next() {
        if (root.player && root.canGoNext)
            root.player.next()
    }

    function previous() {
        if (root.player && root.canGoPrevious)
            root.player.previous()
    }

    function toggle() {
        if (root.player)
            root.player.togglePlaying()
    }

    Component.onCompleted: {
        root.pickPlayer()
        root.sync()
    }
}
