// shell.qml — quickshell entry point
// scaffolded against quickshell 1.x — verify api details against `qs --version`
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "Theme"
import "Modules/Bar"
import "Modules/Launcher"
import "Modules/Corners"

ShellRoot {
    // one bar per monitor
    Variants {
        model: Quickshell.screens
        delegate: Component {
            PanelWindow {
                id: barWindow
                required property var modelData
                screen: modelData

                anchors {
                    top: true
                    left: true
                    right: true
                }
                // floating pill: the window is transparent and full-width, but it
                // reserves the band so windows get pushed down below the pill
                implicitHeight: bar.barHeight + bar.topMargin
                exclusiveZone: bar.barHeight + bar.topMargin
                color: "transparent"

                Bar { id: bar }
            }
        }
    }

    // rounded screen corners — one self-contained overlay per monitor
    Variants {
        model: Quickshell.screens
        delegate: Component {
            Corners {}
        }
    }

    // single instance, not per-monitor
    Launcher {}
}
