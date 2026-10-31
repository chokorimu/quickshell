// shell.qml — quickshell entry point
// scaffolded against quickshell 1.x — verify api details against `qs --version`
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "Theme"
import "Modules/Bar"
import "Modules/Launcher"

ShellRoot {
    // one bar per monitor
    Variants {
        model: Quickshell.screens
        delegate: Component {
            PanelWindow {
                required property var modelData
                screen: modelData

                anchors {
                    top: true
                    left: true
                    right: true
                }
                implicitHeight: 36
                exclusiveZone: implicitHeight
                color: Theme.barColor

                Bar {}
            }
        }
    }

    // single instance, not per-monitor
    Launcher {}
}
