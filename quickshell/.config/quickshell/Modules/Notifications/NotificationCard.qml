// NotificationCard.qml — one popup card in the centered notification stack.
// Delegate over NotificationServer.trackedNotifications, so modelData is the
// Notification. Click anywhere dismisses; action buttons invoke their action
// then dismiss; a Timer expires the card per its expireTimeout (0 means the
// app asked to keep it up until dismissed — that is how critical
// notifications behave).
import QtQml
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "../../Theme"

Rectangle {
    id: card

    // the injected delegate model — the Notification object
    property var notification: modelData

    width: 420
    implicitHeight: content.implicitHeight + 28
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

    Column {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        spacing: 8

        // header: app icon, app name, summary
        Row {
            width: parent.width
            spacing: 10

            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                height: 22
                sourceSize: Qt.size(22, 22)
                fillMode: Image.PreserveAspectFit
                source: Quickshell.iconPath(card.notification.appIcon, "application-x-executable")
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

        // body — hidden entirely when the app sent none
        Text {
            width: parent.width
            visible: card.notification.body.length > 0
            text: card.notification.body
            color: Theme.barForeground
            font.family: Theme.barFontFamily
            font.pixelSize: 13
            wrapMode: Text.WordWrap
            maximumLineCount: 4
            elide: Text.ElideRight
        }

        // actions — hidden when the app offered none
        Row {
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
    }

    // auto-expire; 0 means never
    Timer {
        running: card.notification.expireTimeout > 0
        interval: card.notification.expireTimeout
        onTriggered: card.notification.expire()
    }
}
