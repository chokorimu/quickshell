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
import "../../Services"

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
    // swaync behaved. Property syntax, NOT an attached-object block:
    // `WlrLayershell { layer: ... }` is accepted silently in 0.3.2 but
    // spawns a stray default-sized Overlay surface (hyprland centers it
    // in the workarea — a 100x100 white square mid-screen) and leaves
    // this window at Top. Corners.qml carries the working form.
    WlrLayershell.layer: WlrLayershell.Overlay

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

        // Every notification arrives through this signal first, and the
        // server DISCARDS it on the spot unless a handler marks it
        // tracked — an untracked notification never reaches the
        // trackedNotifications model, so the stack stays empty no matter
        // what apps send. This one line is the difference between popups
        // and silence; it cost a full source dive into 0.3.2's
        // NotificationServer::Notify to find.
        //
        // History first, then the tracked decision. DND is simply not
        // marking tracked — the discard above does the suppressing, with
        // no daemon involved — while the history still records the
        // notification. The append copies every field it needs out of
        // the object on the spot, because the server deletes it the
        // moment it goes untracked, and hands back the entry's id so
        // the avatar grab below can find its entry again once the
        // file lands.
        onNotification: (notification) => {
            var entryId = NotificationHistory.append(notification)
            var image = notification.image ? notification.image.toString() : ""
            if (image.length > 0)
                captureAvatar(image, entryId)
            notification.tracked = !NotificationHistory.dnd
        }

        // advertise what the cards can render so apps send bodies, actions
        // and icons instead of degrading to plain text
        Component.onCompleted: {
            notificationServer.bodySupported = true
            notificationServer.actionsSupported = true
            notificationServer.actionIconsSupported = true
            notificationServer.imageSupported = true
        }
    }

    // DND coming on also clears what is already on screen: a popup
    // that survives the toggle reads as the toggle not working.
    // dismiss() is the notification's own close — it tells the app
    // and drops the card out of trackedNotifications, which is what
    // retracts the stack. The target reference also constructs the
    // history singleton at load, so its state file is read at shell
    // start rather than at the first notification.
    Connections {
        target: NotificationHistory
        function onDndChanged() {
            if (!NotificationHistory.dnd)
                return
            var live = notificationServer.trackedNotifications.values
            for (var i = 0; i < live.length; i++)
                live[i].dismiss()
        }
    }

    Item {
        id: stackWrapper
        anchors.right: parent.right
        anchors.rightMargin: 14 // matches the bar's right row
        anchors.top: parent.top
        anchors.topMargin: 56 // bar band (8 + 36) + 12px gap
        width: 420
        height: stack.contentHeight

        ListView {
            id: stack
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            // The view needs a height that does NOT depend on its own
            // content: a ListView whose height binds to contentHeight
            // starts at zero, and a zero-height view instantiates no
            // delegates — so the content never grows and the stack stays
            // empty forever. Give it the window's full band below the top
            // margin instead; the wrapper above — and with it the input
            // mask — still tracks contentHeight, so only the cards
            // themselves take input.
            height: root.implicitHeight - 56
            spacing: 8
            interactive: false
            model: notificationServer.trackedNotifications
            delegate: NotificationCard {}

            // new cards slide in from the right screen edge, dismissals
            // slide back out the same way and fade, and the cards below
            // a new arrival glide down. The slide distance is the card's
            // own width (420) plus the stack's 14px right margin, so the
            // card starts with its left edge exactly at the window's
            // right edge — the window is full-width and clips there, so
            // the card is entirely off-surface at `from` and eases in
            // from the side instead of dropping from above.
            add: Transition {
                NumberAnimation { property: "x"; from: 434; duration: 280; easing.type: Easing.OutCubic }
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 140 }
            }
            remove: Transition {
                NumberAnimation { property: "x"; to: 434; duration: 200; easing.type: Easing.InCubic }
                NumberAnimation { property: "opacity"; to: 0; duration: 200 }
            }
            displaced: Transition {
                NumberAnimation { properties: "x,y"; duration: 200; easing.type: Easing.OutCubic }
            }
        }
    }

    // ---- avatar capture --------------------------------------------------
    // The notification's own image is the sender's avatar (Discord sends
    // the profile picture as image-data), served through a transient
    // image:// provider URL that dies with the Notification object — the
    // server deletes that object the moment it goes untracked. So the
    // avatar is copied out to disk at receipt, one grabber per
    // notification, and the history rows show the file.
    //
    // A fresh Image per notification, not a reused one: re-pointing a
    // loading Image at a new source cancels the previous load, and a
    // cancelled grab never lands. The grabber is invisible and sits at
    // x 800 — outside the input mask, which covers only the stack
    // column — so it takes no clicks and paints nothing; grabToImage on
    // a visible:false item outside the mask was probe-verified
    // (/tmp/opencode/grabprobe). It destroys itself the moment the file
    // lands, so nothing accumulates.
    //
    // The entry starts life with an empty imagePath and is confirmed
    // only once saveToFile has run, so a row never points at a file
    // that does not exist. A grab that never lands — DND deletes the
    // object mid-load, or the app sent no usable image — leaves the row
    // on its app icon, the same fallback NotificationCard uses.
    Component {
        id: avatarGrabber
        Image {
            required property string target
            required property int entryId
            asynchronous: true
            cache: false
            visible: false
            x: 800
            y: 50
            width: 44
            height: 44
            sourceSize: Qt.size(44, 44)
            fillMode: Image.PreserveAspectFit
            onStatusChanged: {
                if (status === Image.Ready) {
                    grabToImage(function (result) {
                        result.saveToFile(target)
                        NotificationHistory.setImage(entryId, target)
                        destroy()
                    })
                } else if (status === Image.Error) {
                    destroy()
                }
            }
        }
    }

    // Spawns one grabber for a notification's avatar. The filename is
    // built here — notif-<ms>-<entry id>.png — so it is unique per
    // notification and traceable back to its entry.
    function captureAvatar(imageUrl, entryId) {
        var target = NotificationHistory.imageDir + "/notif-"
            + Date.now() + "-" + entryId + ".png"
        avatarGrabber.createObject(root.contentItem, {
            source: imageUrl,
            target: target,
            entryId: entryId
        })
    }
}
