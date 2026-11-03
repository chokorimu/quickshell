// Media.qml — now-playing via the Mpris service.
//
// The Connections on Mpris.players is load-bearing, not decorative: Quickshell
// initialises its services lazily, and without an observer the players model
// stays empty forever. Shows only the players on the allow-list below —
// Spotify, for now — and nothing at all when none of them is running.
import QtQml
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

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

    signal updated()

    // Which players the bar will show. Matched against the MPRIS bus
    // name (org.mpris.MediaPlayer2.<name>) first and the identity
    // second, lowercased; the first running player that matches wins.
    // Spotify only for now — the bar is a now-playing widget, not a
    // mixer, and every browser and stray player used to land here.
    // VLC is detectable the same way: it registers
    // org.mpris.MediaPlayer2.vlc with identity "VLC media player"
    // when built with D-Bus support (standard on Linux packages), so
    // adding it is one word in this list.
    readonly property var allowedPlayers: ["spotify"]

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

    function sync() {
        var p = root.player
        if (!p) {
            root.hasPlayer = false
            root.title = ""
            root.artist = ""
            root.artUrl = ""
            root.playing = false
            root.canGoNext = false
            root.canGoPrevious = false
            root.updated()
            return
        }
        root.hasPlayer = true
        root.title = p.trackTitle || ""
        root.artist = p.trackArtist || ""
        root.artUrl = p.trackArtUrl || ""
        root.playing = p.isPlaying
        root.canGoNext = p.canGoNext
        root.canGoPrevious = p.canGoPrevious
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
