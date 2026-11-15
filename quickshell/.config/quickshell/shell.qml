//@ pragma UseQApplication
// shell.qml — quickshell entry point
// scaffolded against quickshell 1.x — verify api details against `qs --version`
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "Theme"
import "Modules/Bar"
import "Modules/Capture"
import "Modules/Launcher"
import "Modules/Lock"
import "Modules/Notifications"

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
                //
                // While a tray menu is showing the whole window becomes the mask
                // instead, and the radii go: the click-outside catcher fills
                // the window and has to be able to receive a click anywhere on
                // it, or a menu opened from the tray could only be dismissed
                // by hitting the pill's own 40px band. "Showing" rather than
                // "open" — the menu shrinks away over 200ms after the target is
                // dropped, and a mask that snapped back on the open flag would
                // clip the plate mid-animation. The window is still
                // only as tall as windowHeight, so this reaches the top band
                // of the screen, not the whole desktop.
                mask: Region {
                    x: bar.trayMenuShowing ? 0 : bar.pillItem.x
                    y: bar.trayMenuShowing ? 0 : bar.pillItem.y
                    width: bar.trayMenuShowing ? barWindow.width : bar.pillItem.width
                    height: bar.trayMenuShowing ? barWindow.height : bar.barHeight
                    topLeftRadius: bar.trayMenuShowing ? 0 : bar.pillItem.radius
                    topRightRadius: bar.trayMenuShowing ? 0 : bar.pillItem.radius
                    bottomLeftRadius: bar.trayMenuShowing ? 0 : bar.pillItem.radius
                    bottomRightRadius: bar.trayMenuShowing ? 0 : bar.pillItem.radius

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

                    // The workspace switcher's plate. Explicit geometry
                    // mirroring its pop, because a Region tracks an item's
                    // geometry and never its transform — an item-based region
                    // would sit at full width through the whole pop and swallow
                    // clicks beside the animating plate. Square top corners,
                    // since the plate hangs flush off the bar's bottom edge.
                    // (It is 700 wide, not the card's 600 — the tiles need the
                    // room — so the width comes off the switcher, never the
                    // card.)
                    Region {
                        x: bar.pillItem.x + (bar.barWidth - bar.switcherWidth * bar.switcherPop) / 2
                        y: bar.topMargin + bar.barHeight
                        width: bar.switcherWidth * bar.switcherPop
                        height: bar.switcherHeight * bar.switcherPop
                        bottomLeftRadius: 10
                        bottomRightRadius: 10
                    }
                }

                // Keyboard priority while the wifi page's password panel
                // is open, and None the rest of the time. A layer
                // surface's keyboard interactivity defaults to None and
                // the window-level flag does not override it, so the
                // input would receive nothing no matter what
                // forceActiveFocus() did inside it. Flipping to
                // Exclusive on an already-mapped surface takes the
                // keyboard the moment the panel opens and hands it back
                // when the panel closes — the launcher's own mechanism
                // (see Modules/Launcher/Launcher.qml). Tied to the
                // panel, not the page: a hover-opened island must never
                // be a focus thief, but a field the user just clicked
                // into must take the keys.
                WlrLayershell.keyboardFocus: bar.keyboardActive
                    ? WlrKeyboardFocus.Exclusive
                    : WlrKeyboardFocus.None

                Bar { id: bar }
            }
        }
    }

    // Rounded screen corners — Modules/Corners is kept on disk but is NOT
    // instantiated. The cutouts are an Overlay layer surface, and grim and
    // hyprshot capture the composited framebuffer with no per-layer
    // exclusion, so every full-output screenshot carried the four corners.
    // The alternative — hiding the module for the duration of a capture —
    // blinks the corners off and back on around every shot (and grim runs in
    // hyprshot's backgrounded begin_grab, after the main process exits, so
    // the restore has to be delayed or it races the capture). Dropped from
    // the shell until that trade is worth revisiting; re-enabling is the
    // import at the top plus the block below.
    //
    // Variants {
    //     model: Quickshell.screens
    //     delegate: Component {
    //         Corners {}
    //     }
    // }

    // single instance, not per-monitor
    Launcher {}
    Notifications {}

    // the lockscreen. One state holder; the per-monitor surfaces are
    // its Variants. Locked from the session page's power cell (or
    // `qs ipc call lock lock`), and the only way out is a successful
    // PAM conversation.
    Lock {}
}
