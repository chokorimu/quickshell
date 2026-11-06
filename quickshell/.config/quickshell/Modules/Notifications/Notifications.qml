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
//
// Newest on top: the server's trackedNotifications appends, so index 0
// is the oldest card still up and the last index is the one that just
// arrived. The stack below renders from a newest-first mirror of that
// model — see the note on stackModel for why a mirror exists at all.
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

    // ---- the stack's model ------------------------------------------------
    // Newest-first mirror of the server's trackedNotifications.
    //
    // Why a mirror at all: the ListView has to hold a constant geometry
    // for its remove transition to survive (see the note on the view
    // below), and a constant-geometry view cannot be BottomToTop — that
    // direction bottom-aligns its content, so the view's bottom would
    // have to sit at 56 + contentHeight and move with every card.
    // TopToBottom hangs its content from the top and never moves, but it
    // puts index 0 on top, and the server's model appends — so index 0 is
    // the OLDEST card. This mirror reverses that: arrivals are inserted
    // at index 0, so index 0 is the newest and TopToBottom renders
    // newest-on-top.
    //
    // The diff is idempotent and identity-based. Notification* QObject
    // references keep their identity across a ListModel role round-trip
    // (probe-verified), so a row is only inserted when its notification
    // is genuinely absent and only dropped when it has genuinely left —
    // which is what lets one valuesChanged signal drive the whole stack.
    // JS objects would be copied by the role instead, `===` would never
    // match, and every row would re-insert on every change.
    ListModel {
        id: stackModel
    }

    // Reconciles the mirror against the server's model. Called from the
    // Connections below on every valuesChanged — including the initial
    // population, which the signal carries (probe-verified: the model
    // reads empty at Component.onCompleted and valuesChanged arrives
    // with the first item), so no separate completed-time sync is needed.
    //
    // Removals run first, from the bottom up, so a row's index stays
    // valid while the list shrinks. Arrivals then insert at 0 walking
    // the source FORWARD, which preserves arrival order among several
    // notifications landing in the same turn.
    function syncStack() {
        var live = notificationServer.trackedNotifications.values

        for (var k = stackModel.count - 1; k >= 0; k--) {
            if (live.indexOf(stackModel.get(k).notification) < 0)
                stackModel.remove(k)
        }

        for (var j = 0; j < live.length; j++) {
            var found = false
            for (var m = 0; m < stackModel.count; m++) {
                if (stackModel.get(m).notification === live[j]) {
                    found = true
                    break
                }
            }
            if (!found)
                stackModel.insert(0, { notification: live[j] })
        }
    }

    // The one observer that forces trackedNotifications to populate at
    // all — Quickshell's models read empty until something watches them,
    // so without this the stack would stay silent forever.
    Connections {
        target: notificationServer.trackedNotifications
        function onValuesChanged() { root.syncStack() }
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
            // Constant geometry, and that is load-bearing: a ListView
            // destroys an exiting delegate ~20ms after a model change
            // whenever anything in its own ancestor chain changes size in
            // the same turn, which kills the remove transition outright —
            // the card just vanishes instead of sliding out. Binding the
            // height to contentHeight does it, and so does a
            // constant-height view whose position moves because its
            // parent's height tracks contentHeight (both probe-verified,
            // /tmp/opencode/animprobe). This view is anchored to the
            // wrapper's top with a fixed height, so neither its size nor
            // its position ever changes and dismissals get to run.
            //
            // 584 is the visible band: the window is 640 tall and the
            // stack hangs 56 down. Anything below 640 was already clipped
            // by the window, so a taller view would only have shown cards
            // the compositor was cutting off anyway.
            //
            // Newest on top comes from the mirror's order under the
            // default TopToBottom direction — index 0 (the newest card)
            // at the top of the column, so a fresh notification spawns
            // ABOVE the ones already showing and pushes them down, instead
            // of appearing underneath them. (LO's call — "new
            // notification spawns above instead of under".)
            height: 584
            spacing: 8
            interactive: false
            model: stackModel
            delegate: NotificationCard {}

            // new cards slide in from the right screen edge and dismissals
            // slide back out the same way, both fading. The slide distance
            // is the card's own width (420) plus the stack's 14px right
            // margin, so the card starts with its left edge exactly at the
            // window's right edge — the window is full-width and clips
            // there, so the card is entirely off-surface at `from` and
            // eases in from the side instead of dropping from above.
            //
            // displaced carries no y animation on purpose: the stack is
            // top-anchored and newest-on-top, so a re-flow is either the
            // existing cards dropping to make room for an arrival or
            // closing the gap under a dismissal — both are vertical moves
            // that read as a snap, and animating them made the cards
            // appear to slide up under a removal. (LO's call — "only
            // slide right, no need to slide up".) The x half stays so a
            // card caught mid-exit still tracks horizontally.
            add: Transition {
                NumberAnimation { property: "x"; from: 434; duration: 280; easing.type: Easing.OutCubic }
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 140 }
            }
            remove: Transition {
                NumberAnimation { property: "x"; to: 434; duration: 200; easing.type: Easing.InCubic }
                NumberAnimation { property: "opacity"; to: 0; duration: 200 }
            }
            displaced: Transition {
                NumberAnimation { property: "x"; duration: 200; easing.type: Easing.OutCubic }
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
