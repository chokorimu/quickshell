// Media.qml — now-playing via the Mpris service.
//
// The Connections on Mpris.players is load-bearing, not decorative: Quickshell
// initialises its services lazily, and without an observer the players model
// stays empty forever. Prefers Spotify when it is running, else the first
// player that shows up.
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

    function pickPlayer() {
        var ps = Mpris.players.values
        var chosen = null
        for (var i = 0; i < ps.length; i++) {
            var id = (ps[i].identity || "").toLowerCase()
            if (id.indexOf("spotify") !== -1) {
                chosen = ps[i]
                break
            }
        }
        if (!chosen && ps.length > 0)
            chosen = ps[0]
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
