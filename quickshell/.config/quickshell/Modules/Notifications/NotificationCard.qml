// NotificationCard.qml — one popup card in the notification stack.
//
// Every card is exactly 420x140: the body clamps at three lines with an
// ellipsis and the card never resizes, so the stack stays uniform no
// matter how much text an app sends. The actions row claims a fixed
// bottom slot when the app offered actions; when it is absent the body
// takes that space instead.
//
// Delegate over NotificationServer.trackedNotifications, so modelData is
// the Notification. Click anywhere dismisses; action buttons invoke their
// action then dismiss; a Timer expires the card per its expireTimeout
// (0 means the app asked to keep it up until dismissed — that is how
// critical notifications behave).
import QtQml
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "../../Theme"

Rectangle {
    id: card

    // The notification object, captured ONCE at creation rather than bound
    // to modelData: modelData is resolved through the delegate's model
    // context, and that context is invalidated the moment the notification
    // leaves the model — while this card outlives it by its exit animation.
    // Bound directly, every property read on the fading card would hit null
    // and flood the log with TypeErrors. The RetainableLock at the bottom
    // keeps the captured object alive until the card itself is destroyed.
    property var notification: null
    Component.onCompleted: notification = modelData

    // fixed geometry — the stack never jumps as content changes
    width: 420
    height: 140
    radius: 18
    color: Theme.barBackground

    // critical notifications get the urgent border, everything else the
    // subtle surface lift
    border.width: 1
    border.color: notification.urgency === NotificationUrgency.Critical
        ? Theme.barUrgent
        : Theme.barHighlight

    // dismiss on click — declared FIRST so the content above it takes
    // clicks on the action buttons while everything else falls through
    // to here
    MouseArea {
        anchors.fill: parent
        onClicked: card.notification.dismiss()
    }

    // header — app icon, app name, summary; fixed band
    Row {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.topMargin: 14
        height: 36
        spacing: 10

        Image {
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 22
            sourceSize: Qt.size(22, 22)
            fillMode: Image.PreserveAspectFit
            // iconPath("") mangles into a broken "?fallback=..." request,
            // so only ask when the app actually named an icon
            source: card.notification.appIcon.length > 0
                ? Quickshell.iconPath(card.notification.appIcon, "application-x-executable")
                : ""
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 32 // 22px icon + 10px spacing
            spacing: 1

            Text {
                width: parent.width
                text: card.notification.appName
                color: Theme.barDim
                font.family: Theme.barFontFamily
                font.pixelSize: 11
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Text {
                width: parent.width
                text: card.notification.summary
                color: Theme.barForeground
                font.family: Theme.barFontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }
    }

    // body — three lines max, then ellipsis; fills whatever the actions
    // row leaves, top-aligned so multi-line bodies read consistently
    Text {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.bottom: actionRow.visible ? actionRow.top : parent.bottom
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.topMargin: 8
        anchors.bottomMargin: actionRow.visible ? 8 : 14
        visible: card.notification.body.length > 0
        text: card.notification.body
        color: Theme.barForeground
        font.family: Theme.barFontFamily
        font.pixelSize: 13
        wrapMode: Text.WordWrap
        maximumLineCount: 3
        elide: Text.ElideRight
        verticalAlignment: Text.AlignTop
    }

    // actions — fixed bottom slot, hidden when the app offered none
    Row {
        id: actionRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.bottomMargin: 14
        height: 26
        spacing: 8
        visible: card.notification.actions.length > 0

        Repeater {
            model: card.notification.actions
            Rectangle {
                property var action: modelData

                implicitWidth: actionLabel.implicitWidth + 20
                implicitHeight: 26
                radius: 13
                color: Theme.barHighlight

                Text {
                    id: actionLabel
                    anchors.centerIn: parent
                    text: parent.action.text
                    color: Theme.barForeground
                    font.family: Theme.barFontFamily
                    font.pixelSize: 12
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        parent.action.invoke()
                        card.notification.dismiss()
                    }
                }
            }
        }
    }

    // auto-expire; 0 means never
    Timer {
        running: card.notification.expireTimeout > 0
        interval: card.notification.expireTimeout
        onTriggered: card.notification.expire()
    }

    // The notification object is destroyed the moment it leaves the model,
    // but this card outlives that by its exit animation — without a lock
    // every binding on the fading card reads a null notification and floods
    // the log with TypeErrors. The lock is released when the card itself is
    // destroyed, so nothing leaks.
    RetainableLock {
        object: card.notification
        locked: true
    }
}
