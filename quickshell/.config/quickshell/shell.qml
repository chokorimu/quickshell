//@ pragma UseQApplication
// shell.qml — quickshell entry point
// scaffolded against quickshell 1.x — verify api details against `qs --version`
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "Theme"
import "Modules/Bar"
import "Modules/Capture"
import "Modules/Launcher"
import "Modules/Notifications"
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
                // reserves the band so windows get pushed down below the pill.
                // The card pops open past that band, so the window is taller
                // than it reserves.
                implicitHeight: bar.windowHeight
                exclusiveZone: bar.barHeight + bar.topMargin
                color: "transparent"

                // The extra height would swallow every click around the pill
                // and the card, so the window carries an input mask tracking
                // both, and everything outside passes through to the windows
                // underneath. Both regions are explicit geometry rather than
                // item-based: the pill's because its canvas is taller than the
                // bar by the roll's depth, and an item-based region would cover
                // that strip and swallow clicks below the bar's edge — so it is
                // pinned to the bar's own 40px band.
                mask: Region {
                    x: bar.pillItem.x
                    y: bar.pillItem.y
                    width: bar.pillItem.width
                    height: bar.barHeight
                    topLeftRadius: bar.pillItem.radius
                    topRightRadius: bar.pillItem.radius
                    bottomLeftRadius: bar.pillItem.radius
                    bottomRightRadius: bar.pillItem.radius

                    // The card's region is explicit for the same class of
                    // reason: the card pops open scaled, and a Region tracks
                    // an item's geometry, never its transform — an item-based
                    // region would sit at full width through the whole pop
                    // and swallow clicks beside the animating card. These
                    // bindings mirror the card's popped geometry exactly, so
                    // the region is the visible card at every frame and
                    // collapses to nothing when the card does.
                    Region {
                        x: bar.pillItem.x + (bar.barWidth - bar.cardWidth * bar.pop) / 2
                        y: bar.cardItem.y
                        width: bar.cardWidth * bar.pop
                        height: (bar.cardHeight + bar.cardRadius) * bar.pop
                        topLeftRadius: bar.cardRadius
                        topRightRadius: bar.cardRadius
                        bottomLeftRadius: bar.cardRadius
                        bottomRightRadius: bar.cardRadius
                    }
                }

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
    Notifications {}
}
