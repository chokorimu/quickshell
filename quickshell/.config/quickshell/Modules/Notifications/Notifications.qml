// Notifications.qml — notification popups, top right under the bar.
//
// A single full-width transparent window at the Overlay layer; the cards
// themselves live in a 420px column anchored to the top right, just below
// the bar's band (bar = 8px margin + 36px pill, plus a 12px gap), its
// right edge lined up with the bar's right row at 14px. The window
// carries an input mask tracking that column: without it the transparent
// surface would swallow every click meant for the windows underneath, and
// the column collapses to zero height when nothing is up.
//
// The model is the server's trackedNotifications — every notification the
// server has seen that has not been closed yet. Each card expires itself
// per its own expireTimeout, so the stack drains on its own.
import QtQml
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland
import "../../Theme"

PanelWindow {
    id: root

    visible: true
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 640
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    // Overlay so popups still show over fullscreen windows, matching how
    // swaync behaved
    WlrLayershell {
        layer: WlrLayershell.Overlay
    }

    // only the stack takes input; everything else passes through
    mask: Region {
        item: stackWrapper
    }

    // The server is NOT a qml singleton in 0.3.2 despite what the docs
    // suggest — the shipped qmltypes carries no isSingleton flag, so bare
    // `NotificationServer.x` access reads undefined and nothing ever
    // registers on dbus. It must be instantiated as an object; that
    // instantiation is what claims org.freedesktop.Notifications.
    // keepOnReload preserves the stack across hot reloads.
    NotificationServer {
        id: notificationServer
        keepOnReload: true

        // advertise what the cards can render so apps send bodies, actions
        // and icons instead of degrading to plain text
        Component.onCompleted: {
            notificationServer.bodySupported = true
            notificationServer.actionsSupported = true
            notificationServer.actionIconsSupported = true
            notificationServer.imageSupported = true
        }
    }

    Item {
        id: stackWrapper
        anchors.right: parent.right
        anchors.rightMargin: 14 // matches the bar's right row
        anchors.top: parent.top
        anchors.topMargin: 56 // bar band (8 + 36) + 12px gap
        width: 420
        height: stack.height

        ListView {
            id: stack
            width: parent.width
            height: contentHeight
            spacing: 8
            interactive: false
            model: notificationServer.trackedNotifications
            delegate: NotificationCard {}

            // new cards drop in from above the stack, dismissals slide back
            // up and fade, and the cards below a new arrival glide down
            add: Transition {
                NumberAnimation { property: "y"; from: -48; duration: 220; easing.type: Easing.OutCubic }
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180 }
            }
            remove: Transition {
                NumberAnimation { property: "y"; to: -48; duration: 160; easing.type: Easing.InCubic }
                NumberAnimation { property: "opacity"; to: 0; duration: 160 }
            }
            displaced: Transition {
                NumberAnimation { properties: "x,y"; duration: 200; easing.type: Easing.OutCubic }
            }
        }
    }
}
