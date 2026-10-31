// Matugen.qml — regenerate the palette from the current wallpaper
// set `wallpaper`, call regenerate(); matugen output feeds Theme/Colors.qml
import QtQuick
import Quickshell
import Quickshell.Io

pragma Singleton

Singleton {
    id: root

    // path to the current wallpaper — wired up by the wallpaper menu
    property string wallpaper: ""

    signal paletteChanged()

    function regenerate() {
        if (root.wallpaper.length === 0)
            return
        proc.command = ["matugen", "image", root.wallpaper]
        proc.running = true
    }

    Process {
        id: proc
        onExited: root.paletteChanged()
    }
}
